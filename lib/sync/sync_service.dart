import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_client.dart';
import 'kv_store.dart';
import 'sync_config.dart';
import 'sync_engine.dart';

enum SyncState { notConfigured, signedOut, idle, syncing, offline, error }

/// Verbindet Sync-Logik, Anmeldung und App: gleicht beim Start, nach lokalen
/// Änderungen, beim Zurückkehren in die App und alle paar Sekunden ab.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  static final SyncService instance = SyncService._();
  SyncService._();

  static const _pollInterval = Duration(seconds: 10);
  static const _debounce = Duration(seconds: 2);

  /// Zählt hoch, sobald Daten aus der Cloud lokal übernommen wurden.
  final ValueNotifier<int> revision = ValueNotifier(0);
  Set<String> lastChangedKeys = {};

  SyncState state = SyncState.signedOut;
  DateTime? lastSync;
  String? lastError;

  SyncEngine? _engine;
  FirebaseAuthClient? _auth;
  FirebaseRemote? _remote;
  final http.Client _http = http.Client();
  Timer? _debounceTimer;
  bool _syncing = false;
  bool _again = false;

  bool get configured => kFirebaseProjectId.isNotEmpty && kFirebaseApiKey.isNotEmpty;
  bool get signedIn => _auth?.signedIn ?? false;
  String? get email => _auth?.email;
  int get pending => _engine?.pendingCount ?? 0;
  bool get hasBackups => (_engine?.backups ?? const {}).isNotEmpty;

  Future<void> init() async {
    try {
      final store = SharedPrefsKvStore(await SharedPreferences.getInstance());
      final engine = SyncEngine(store);
      await engine.init();
      _engine = engine;

      if (configured) {
        final auth = FirebaseAuthClient(apiKey: kFirebaseApiKey, store: store, client: _http)..load();
        _auth = auth;
        _remote = FirebaseRemote(auth: auth, projectId: kFirebaseProjectId, client: _http);
      }
      _setState(!configured ? SyncState.notConfigured : (signedIn ? SyncState.idle : SyncState.signedOut));

      WidgetsBinding.instance.addObserver(this);
      Timer.periodic(_pollInterval, (_) => syncNow());
      if (signedIn) unawaited(syncNow());
    } catch (e) {
      lastError = '$e';
      _setState(SyncState.error);
    }
  }

  /// Wird vom Speicher bei jeder lokalen Änderung aufgerufen.
  Future<void> onLocalWrite(String key, {bool deleted = false}) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.onLocalWrite(key, deleted: deleted);
    if (signedIn) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, syncNow);
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password, {bool createAccount = false}) async {
    final auth = _auth;
    if (auth == null) throw const SyncException('Sync ist in dieser App-Version nicht eingerichtet.');
    if (createAccount) {
      await auth.signUp(email, password);
    } else {
      await auth.signIn(email, password);
    }
    _setState(SyncState.idle);
    await syncNow();
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    await _engine?.resetSyncState();
    lastSync = null;
    lastError = null;
    _setState(SyncState.signedOut);
  }

  Future<void> syncNow() async {
    final engine = _engine;
    final remote = _remote;
    if (engine == null || remote == null || !signedIn) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    _setState(SyncState.syncing);
    try {
      final result = await engine.sync(remote);
      lastSync = DateTime.now();
      lastError = null;
      if (result.changedKeys.isNotEmpty) {
        lastChangedKeys = result.changedKeys;
        revision.value++;
      }
      _setState(SyncState.idle);
    } on SyncException catch (e) {
      if (e.authFailed) {
        await _auth?.signOut();
        lastError = e.message;
        _setState(SyncState.signedOut);
      } else {
        lastError = e.message;
        _setState(SyncState.error);
      }
    } catch (_) {
      // Kein Netz o. Ä.: nichts verloren, die Änderungen bleiben vorgemerkt.
      _setState(SyncState.offline);
    } finally {
      _syncing = false;
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  void _setState(SyncState s) {
    state = s;
    notifyListeners();
  }
}
