import 'dart:convert';
import 'kv_store.dart';
import 'sync_keys.dart';

/// Ein Eintrag im Cloud-Speicher. [value] ist der kodierte Wert, bei
/// gelöschten Schlüsseln null.
class SyncDoc {
  final String key;
  final String? value;
  final int ts;
  final bool deleted;
  const SyncDoc({required this.key, required this.value, required this.ts, required this.deleted});
}

class RemotePage {
  final List<SyncDoc> docs;
  final String? cursor;
  final bool hasMore;
  const RemotePage(this.docs, this.cursor, this.hasMore);
}

abstract class RemoteStore {
  Future<void> push(List<SyncDoc> docs);

  /// Liefert Einträge, die nach [cursor] auf dem Server geändert wurden
  /// (null = alle).
  Future<RemotePage> pull(String? cursor);
}

class SyncResult {
  final Set<String> changedKeys;
  final int pushed;
  const SyncResult(this.changedKeys, this.pushed);
}

String encodeSyncValue(Object v) {
  if (v is String) return jsonEncode({'t': 's', 'v': v});
  if (v is List) return jsonEncode({'t': 'l', 'v': v.cast<String>()});
  if (v is int) return jsonEncode({'t': 'i', 'v': v});
  if (v is bool) return jsonEncode({'t': 'b', 'v': v});
  if (v is double) return jsonEncode({'t': 'd', 'v': v});
  throw ArgumentError('Nicht unterstützter Werttyp: ${v.runtimeType}');
}

Object decodeSyncValue(String s) {
  final m = jsonDecode(s) as Map<String, dynamic>;
  final v = m['v'];
  switch (m['t']) {
    case 's':
      return v as String;
    case 'l':
      return (v as List<dynamic>).cast<String>().toList();
    case 'i':
      return v as int;
    case 'b':
      return v as bool;
    case 'd':
      return (v as num).toDouble();
  }
  throw FormatException('Unbekannter Werttyp: ${m['t']}');
}

class _Meta {
  int ts;
  bool deleted;
  int pushedTs;
  _Meta(this.ts, this.deleted, this.pushedTs);

  List<Object> toJson() => [ts, deleted ? 1 : 0, pushedTs];
  factory _Meta.fromJson(List<dynamic> j) => _Meta(j[0] as int, j[1] == 1, j[2] as int);
}

/// Lokal-zuerst-Synchronisation auf Schlüsselebene. Jede lokale Änderung
/// bekommt einen Zeitstempel; beim Abgleich gewinnt pro Schlüssel die jüngere
/// Änderung. Ungesendete Änderungen bleiben "dirty", bis ein Abgleich gelingt –
/// so funktioniert die App offline und holt später alles nach.
class SyncEngine {
  static const metaKey = 'zenday_sync_meta';
  static const cursorKey = 'zenday_sync_cursor';
  static const backupKey = 'zenday_sync_backup';
  static const _epoch = '1970-01-01T00:00:00Z';
  static const _pushChunk = 200;

  final KvStore store;
  final int Function() _now;
  final Map<String, _Meta> _meta = {};
  final Map<String, String> _backup = {};
  String? _cursor;

  SyncEngine(this.store, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Anzahl lokaler Änderungen, die noch nicht in der Cloud sind.
  int get pendingCount => _meta.values.where((m) => m.ts != m.pushedTs).length;

  /// Gesicherte lokale Werte, die beim ersten Abgleich durch Cloud-Daten
  /// ersetzt wurden (Schlüssel → kodierter Wert).
  Map<String, String> get backups => Map.unmodifiable(_backup);

  bool get hasSyncedBefore => _cursor != null;

  Future<void> init() async {
    final rawMeta = store.get(metaKey);
    if (rawMeta is String) {
      try {
        final map = jsonDecode(rawMeta) as Map<String, dynamic>;
        map.forEach((k, v) => _meta[k] = _Meta.fromJson(v as List<dynamic>));
      } catch (_) {
        _meta.clear();
      }
    }
    final rawCursor = store.get(cursorKey);
    _cursor = rawCursor is String ? rawCursor : null;

    final rawBackup = store.get(backupKey);
    if (rawBackup is String) {
      try {
        (jsonDecode(rawBackup) as Map<String, dynamic>).forEach((k, v) => _backup[k] = v as String);
      } catch (_) {}
    }

    // Bereits vorhandene Daten ohne Zeitstempel (aus der Zeit vor dem Sync)
    // als "älteste mögliche Änderung" erfassen, damit sie hochgeladen werden.
    var changed = false;
    for (final k in store.keys()) {
      if (isSyncableKey(k) && !_meta.containsKey(k)) {
        _meta[k] = _Meta(1, false, 0);
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  Future<void> onLocalWrite(String key, {bool deleted = false}) async {
    if (!isSyncableKey(key)) return;
    final prev = _meta[key];
    final t = _now();
    final ts = (prev != null && prev.ts >= t) ? prev.ts + 1 : t;
    _meta[key] = _Meta(ts, deleted, prev?.pushedTs ?? 0);
    await _persist();
  }

  /// Vergisst den Abgleichsstand (z. B. nach dem Abmelden). Beim nächsten
  /// Anmelden gilt wieder "Cloud zuerst" und alles wird neu hochgeladen.
  Future<void> resetSyncState() async {
    _cursor = null;
    for (final m in _meta.values) {
      m.pushedTs = 0;
    }
    await store.delete(cursorKey);
    await _persist();
  }

  Future<SyncResult> sync(RemoteStore remote) async {
    final changed = <String>{};
    final first = _cursor == null;
    var cursor = _cursor ?? _epoch;

    while (true) {
      final page = await remote.pull(cursor);
      for (final d in page.docs) {
        if (await _applyRemote(d, first)) changed.add(d.key);
      }
      if (page.cursor != null) cursor = page.cursor!;
      if (!page.hasMore) break;
    }

    var pushed = 0;
    final dirty = _meta.entries.where((e) => e.value.ts != e.value.pushedTs).map((e) => e.key).toList();
    for (var i = 0; i < dirty.length; i += _pushChunk) {
      final chunk = dirty.sublist(i, i + _pushChunk > dirty.length ? dirty.length : i + _pushChunk);
      final docs = <SyncDoc>[];
      final sentTs = <String, int>{};
      for (final k in chunk) {
        final m = _meta[k]!;
        sentTs[k] = m.ts;
        final value = store.get(k);
        if (m.deleted || value == null) {
          docs.add(SyncDoc(key: k, value: null, ts: m.ts, deleted: true));
        } else {
          docs.add(SyncDoc(key: k, value: encodeSyncValue(value), ts: m.ts, deleted: false));
        }
      }
      await remote.push(docs);
      for (final e in sentTs.entries) {
        final m = _meta[e.key];
        if (m != null && m.ts == e.value) m.pushedTs = e.value;
      }
      pushed += docs.length;
    }

    _cursor = cursor;
    await _persist();
    return SyncResult(changed, pushed);
  }

  Future<bool> _applyRemote(SyncDoc d, bool first) async {
    if (!isSyncableKey(d.key)) return false;

    final m = _meta[d.key];
    final localTs = m?.ts ?? 0;
    final localValue = store.get(d.key);
    final localEncoded = (localValue == null || (m?.deleted ?? false)) ? null : encodeSyncValue(localValue);
    final remoteEncoded = d.deleted ? null : d.value;

    bool remoteWins;
    if (first) {
      // Erster Abgleich auf diesem Gerät: Die Cloud gilt als Wahrheit, damit ein
      // frisch eingerichtetes Gerät keine echten Daten überschreibt.
      remoteWins = true;
    } else if (d.ts != localTs) {
      remoteWins = d.ts > localTs;
    } else {
      // Gleicher Zeitstempel, anderer Inhalt: auf beiden Geräten dieselbe
      // Entscheidung treffen, damit sie konvergieren.
      remoteWins = (remoteEncoded ?? '').compareTo(localEncoded ?? '') > 0;
    }

    if (!remoteWins) {
      if (m != null && d.ts == localTs) {
        m.pushedTs = remoteEncoded == localEncoded ? localTs : -1;
      }
      return false;
    }

    if (first && localEncoded != null && localEncoded != remoteEncoded) {
      _backup[d.key] = localEncoded;
    }
    if (remoteEncoded == null) {
      await store.delete(d.key);
    } else {
      await store.put(d.key, decodeSyncValue(remoteEncoded));
    }
    _meta[d.key] = _Meta(d.ts, d.deleted, d.ts);
    return localEncoded != remoteEncoded;
  }

  Future<void> _persist() async {
    await store.put(metaKey, jsonEncode(_meta.map((k, v) => MapEntry(k, v.toJson()))));
    if (_cursor != null) await store.put(cursorKey, _cursor!);
    if (_backup.isNotEmpty) await store.put(backupKey, jsonEncode(_backup));
  }
}
