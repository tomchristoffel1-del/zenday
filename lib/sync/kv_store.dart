import 'package:shared_preferences/shared_preferences.dart';

/// Minimale Schlüssel-Wert-Schnittstelle, auf der die Sync-Logik arbeitet.
/// Werte sind String, List<String>, int, bool oder double.
abstract class KvStore {
  Iterable<String> keys();
  Object? get(String key);
  Future<void> put(String key, Object value);
  Future<void> delete(String key);
}

class SharedPrefsKvStore implements KvStore {
  final SharedPreferences _p;
  SharedPrefsKvStore(this._p);

  @override
  Iterable<String> keys() => _p.getKeys();

  @override
  Object? get(String key) {
    final v = _p.get(key);
    return v is List ? v.cast<String>().toList() : v;
  }

  @override
  Future<void> put(String key, Object value) async {
    if (value is String) {
      await _p.setString(key, value);
    } else if (value is List<String>) {
      await _p.setStringList(key, value);
    } else if (value is int) {
      await _p.setInt(key, value);
    } else if (value is bool) {
      await _p.setBool(key, value);
    } else if (value is double) {
      await _p.setDouble(key, value);
    } else {
      throw ArgumentError('Nicht unterstützter Werttyp: ${value.runtimeType}');
    }
  }

  @override
  Future<void> delete(String key) async {
    await _p.remove(key);
  }
}

/// Speicher im Arbeitsspeicher – für Tests.
class MemoryKvStore implements KvStore {
  final Map<String, Object> data = {};

  @override
  Iterable<String> keys() => data.keys.toList();

  @override
  Object? get(String key) {
    final v = data[key];
    return v is List ? v.cast<String>().toList() : v;
  }

  @override
  Future<void> put(String key, Object value) async {
    data[key] = value is List ? value.cast<String>().toList() : value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}
