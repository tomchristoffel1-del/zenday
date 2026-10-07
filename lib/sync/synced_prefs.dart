import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';

/// Dünne Hülle um SharedPreferences: gleiche Methoden, aber jede echte
/// Änderung wird dem Sync gemeldet. Schreiben ohne Wertänderung wird ignoriert,
/// damit nichts unnötig hochgeladen wird.
class SyncedPrefs {
  SyncedPrefs._(this._p);
  static SyncedPrefs? _instance;

  static Future<SyncedPrefs> instance() async => _instance ??= SyncedPrefs._(await SharedPreferences.getInstance());

  final SharedPreferences _p;

  Set<String> getKeys() => _p.getKeys();
  String? getString(String key) => _p.getString(key);
  List<String>? getStringList(String key) => _p.getStringList(key);
  int? getInt(String key) => _p.getInt(key);
  bool? getBool(String key) => _p.getBool(key);

  Future<bool> setString(String key, String value) async {
    if (_p.getString(key) == value) return true;
    final ok = await _p.setString(key, value);
    await SyncService.instance.onLocalWrite(key);
    return ok;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    final old = _p.getStringList(key);
    if (old != null && old.length == value.length && _sameItems(old, value)) return true;
    final ok = await _p.setStringList(key, value);
    await SyncService.instance.onLocalWrite(key);
    return ok;
  }

  Future<bool> setInt(String key, int value) async {
    if (_p.getInt(key) == value) return true;
    final ok = await _p.setInt(key, value);
    await SyncService.instance.onLocalWrite(key);
    return ok;
  }

  Future<bool> setBool(String key, bool value) async {
    if (_p.getBool(key) == value) return true;
    final ok = await _p.setBool(key, value);
    await SyncService.instance.onLocalWrite(key);
    return ok;
  }

  Future<bool> remove(String key) async {
    if (!_p.containsKey(key)) return true;
    final ok = await _p.remove(key);
    await SyncService.instance.onLocalWrite(key, deleted: true);
    return ok;
  }

  static bool _sameItems(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
