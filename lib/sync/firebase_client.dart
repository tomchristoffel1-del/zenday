import 'dart:convert';
import 'package:http/http.dart' as http;
import 'kv_store.dart';
import 'sync_engine.dart';

class SyncException implements Exception {
  final String message;
  final bool authFailed;
  const SyncException(this.message, {this.authFailed = false});

  @override
  String toString() => message;
}

String _authMessage(String code) {
  if (code.startsWith('WEAK_PASSWORD')) return 'Das Passwort ist zu schwach (mindestens 6 Zeichen).';
  switch (code) {
    case 'EMAIL_EXISTS':
      return 'Für diese E-Mail gibt es schon ein Konto – bitte anmelden statt neu anlegen.';
    case 'INVALID_LOGIN_CREDENTIALS':
    case 'INVALID_PASSWORD':
    case 'EMAIL_NOT_FOUND':
      return 'E-Mail oder Passwort stimmt nicht.';
    case 'INVALID_EMAIL':
      return 'Das ist keine gültige E-Mail-Adresse.';
    case 'OPERATION_NOT_ALLOWED':
      return 'Das geht nicht: E-Mail/Passwort ist im Firebase-Projekt nicht aktiviert oder neue Konten sind gesperrt.';
    case 'TOO_MANY_ATTEMPTS_TRY_LATER':
      return 'Zu viele Versuche – bitte später erneut probieren.';
    case 'USER_DISABLED':
      return 'Dieses Konto wurde deaktiviert.';
  }
  return 'Anmeldung fehlgeschlagen ($code).';
}

/// Anmeldung per E-Mail/Passwort über die Firebase-Auth-REST-Schnittstelle.
/// Das Passwort wird nie gespeichert, nur das Aktualisierungs-Token.
class FirebaseAuthClient {
  static const _storeKey = 'zenday_sync_auth';

  final String apiKey;
  final KvStore store;
  final http.Client _http;

  String? email;
  String? uid;
  String? _refreshToken;
  String? _idToken;
  DateTime _expiry = DateTime.fromMillisecondsSinceEpoch(0);

  FirebaseAuthClient({required this.apiKey, required this.store, required http.Client client}) : _http = client;

  bool get signedIn => _refreshToken != null;

  void load() {
    final raw = store.get(_storeKey);
    if (raw is! String) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      email = m['email'] as String?;
      uid = m['uid'] as String?;
      _refreshToken = m['refreshToken'] as String?;
    } catch (_) {}
  }

  Future<void> _save() => store.put(
        _storeKey,
        jsonEncode({'email': email, 'uid': uid, 'refreshToken': _refreshToken}),
      );

  Future<void> signIn(String email, String password) => _credentials('signInWithPassword', email, password);

  Future<void> signUp(String email, String password) => _credentials('signUp', email, password);

  Future<void> _credentials(String op, String email, String password) async {
    final res = await _http
        .post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:$op?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password, 'returnSecureToken': true}),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final code = ((body['error'] as Map<String, dynamic>?)?['message'] as String?) ?? 'UNKNOWN';
      throw SyncException(_authMessage(code));
    }
    this.email = body['email'] as String? ?? email.trim();
    uid = body['localId'] as String;
    _refreshToken = body['refreshToken'] as String;
    _idToken = body['idToken'] as String;
    _expiry = DateTime.now().add(Duration(seconds: int.parse(body['expiresIn'] as String) - 60));
    await _save();
  }

  Future<String> idToken({bool forceRefresh = false}) async {
    if (!signedIn) throw const SyncException('Nicht angemeldet.', authFailed: true);
    if (!forceRefresh && _idToken != null && DateTime.now().isBefore(_expiry)) return _idToken!;

    final res = await _http
        .post(
          Uri.parse('https://securetoken.googleapis.com/v1/token?key=$apiKey'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(_refreshToken!)}',
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final code = ((body['error'] as Map<String, dynamic>?)?['message'] as String?) ?? 'UNKNOWN';
      final fatal = code == 'TOKEN_EXPIRED' || code == 'USER_DISABLED' || code == 'USER_NOT_FOUND' || code == 'INVALID_REFRESH_TOKEN';
      throw SyncException('Anmeldung abgelaufen – bitte erneut anmelden.', authFailed: fatal);
    }
    _idToken = body['id_token'] as String;
    _refreshToken = body['refresh_token'] as String? ?? _refreshToken;
    _expiry = DateTime.now().add(Duration(seconds: int.parse(body['expires_in'] as String) - 60));
    await _save();
    return _idToken!;
  }

  Future<void> signOut() async {
    email = null;
    uid = null;
    _refreshToken = null;
    _idToken = null;
    await store.delete(_storeKey);
  }
}

/// Firestore-Zugriff über REST. Jeder lokale Schlüssel ist ein Dokument unter
/// `users/{uid}/kv/{schlüssel}` mit Wert (`v`), Änderungszeit des Geräts (`ts`),
/// Löschmarke (`d`) und Serverzeit (`st`). Abgeholt wird nach Serverzeit, damit
/// auch Geräte mit falsch gehender Uhr keine Änderungen verpassen.
class FirebaseRemote implements RemoteStore {
  static const _pageSize = 300;

  final FirebaseAuthClient auth;
  final String projectId;
  final http.Client _http;

  FirebaseRemote({required this.auth, required this.projectId, required http.Client client}) : _http = client;

  String get _docsRoot => 'projects/$projectId/databases/(default)/documents';

  Future<dynamic> _post(String url, Object body) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await auth.idToken(forceRefresh: attempt > 0);
      final res = await _http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 401 && attempt == 0) continue;
      final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode == 200) return decoded;

      final err = decoded is List
          ? (decoded.isNotEmpty ? (decoded.first as Map<String, dynamic>)['error'] : null)
          : (decoded as Map<String, dynamic>?)?['error'];
      final status = (err as Map<String, dynamic>?)?['status'] as String?;
      final message = (err)?['message'] as String? ?? 'HTTP ${res.statusCode}';
      if (res.statusCode == 401 || status == 'UNAUTHENTICATED') {
        throw const SyncException('Anmeldung abgelaufen – bitte erneut anmelden.', authFailed: true);
      }
      if (status == 'PERMISSION_DENIED') {
        throw const SyncException('Zugriff verweigert – sind die Firestore-Regeln veröffentlicht?');
      }
      throw SyncException('Server-Fehler: $message');
    }
    throw const SyncException('Anmeldung abgelaufen – bitte erneut anmelden.', authFailed: true);
  }

  @override
  Future<void> push(List<SyncDoc> docs) async {
    if (docs.isEmpty) return;
    final uid = auth.uid!;
    final writes = docs
        .map((d) => {
              'update': {
                'name': '$_docsRoot/users/$uid/kv/${Uri.encodeComponent(d.key)}',
                'fields': {
                  'v': d.deleted || d.value == null ? {'nullValue': null} : {'stringValue': d.value},
                  'ts': {'integerValue': '${d.ts}'},
                  'd': {'booleanValue': d.deleted},
                },
              },
              'updateTransforms': [
                {'fieldPath': 'st', 'setToServerValue': 'REQUEST_TIME'},
              ],
            })
        .toList();
    await _post('https://firestore.googleapis.com/v1/$_docsRoot:commit', {'writes': writes});
  }

  @override
  Future<RemotePage> pull(String? cursor) async {
    final uid = auth.uid!;
    final result = await _post('https://firestore.googleapis.com/v1/$_docsRoot/users/$uid:runQuery', {
      'structuredQuery': {
        'from': [
          {'collectionId': 'kv'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'st'},
            'op': 'GREATER_THAN',
            'value': {'timestampValue': cursor ?? '1970-01-01T00:00:00Z'},
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'st'},
            'direction': 'ASCENDING',
          },
        ],
        'limit': _pageSize,
      },
    });

    final docs = <SyncDoc>[];
    String? newCursor;
    for (final item in (result as List<dynamic>)) {
      final doc = (item as Map<String, dynamic>)['document'] as Map<String, dynamic>?;
      if (doc == null) continue;
      final fields = doc['fields'] as Map<String, dynamic>? ?? {};
      final name = doc['name'] as String;
      final deleted = (fields['d'] as Map<String, dynamic>?)?['booleanValue'] == true;
      docs.add(SyncDoc(
        key: Uri.decodeComponent(name.substring(name.lastIndexOf('/') + 1)),
        value: deleted ? null : (fields['v'] as Map<String, dynamic>?)?['stringValue'] as String?,
        ts: int.parse((fields['ts'] as Map<String, dynamic>)['integerValue'] as String),
        deleted: deleted,
      ));
      newCursor = (fields['st'] as Map<String, dynamic>?)?['timestampValue'] as String? ?? newCursor;
    }
    return RemotePage(docs, newCursor, docs.length >= _pageSize);
  }
}
