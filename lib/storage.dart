import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Lokale, blitzschnelle Persistenz ohne Server, ohne Ladezeiten.
class ZenStorage {
  static const _onboardedKey = 'zenday_onboarded';
  static const _templatesKey = 'zenday_templates';
  static const _focusConfigKey = 'zenday_focus_config';
  static const _pointsKey = 'zenday_focus_points';
  static const _themeModeKey = 'zenday_theme_mode';
  static const _accentIndexKey = 'zenday_accent_index';
  static const _blockListsKey = 'zenday_block_lists';
  static const _autostartKey = 'zenday_autostart';
  static const _appLimitsKey = 'zenday_app_limits';

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _adhocKey(DateTime d) => 'zenday_adhoc_${_fmt(d)}';
  static String _tplDoneKey(DateTime d) => 'zenday_tpldone_${_fmt(d)}';
  static String _dayFocusKey(DateTime d) => 'zenday_dayfocus_${_fmt(d)}';
  static String _orderKey(DateTime d) => 'zenday_order_${_fmt(d)}';
  static String _usageKey(DateTime d) => 'zenday_usage_${_fmt(d)}';
  static String _trackingKey(DateTime d) => 'zenday_tracking_${_fmt(d)}';

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<List<TaskTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templatesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTemplates(List<TaskTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _templatesKey,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  Future<List<AdHocTask>> loadAdHoc(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adhocKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AdHocTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAdHoc(DateTime date, List<AdHocTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _adhocKey(date),
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  Future<Set<String>> loadTemplateDoneIds(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_tplDoneKey(date)) ?? []).toSet();
  }

  Future<void> saveTemplateDoneIds(DateTime date, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tplDoneKey(date), ids.toList());
  }

  Future<String> loadDayFocus(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dayFocusKey(date)) ?? '';
  }

  Future<void> saveDayFocus(DateTime date, String focus) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dayFocusKey(date), focus);
  }

  Future<FocusConfig> loadFocusConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_focusConfigKey);
    if (raw == null) return FocusConfig();
    return FocusConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveFocusConfig(FocusConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_focusConfigKey, jsonEncode(config.toJson()));
  }

  Future<int> loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  Future<void> savePoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, points);
  }

  Future<List<String>> loadOrder(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_orderKey(date)) ?? [];
  }

  Future<void> saveOrder(DateTime date, List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_orderKey(date), order);
  }

  Future<String> loadThemeModePref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> saveThemeModePref(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  Future<int> loadAccentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentIndexKey) ?? 0;
  }

  Future<void> saveAccentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentIndexKey, index);
  }

  Future<List<BlockList>> loadBlockLists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_blockListsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => BlockList.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBlockLists(List<BlockList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blockListsKey, jsonEncode(lists.map((l) => l.toJson()).toList()));
  }

  Future<bool> loadAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autostartKey) ?? false;
  }

  Future<void> saveAutostart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autostartKey, value);
  }

  Future<List<AppLimit>> loadAppLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appLimitsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AppLimit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAppLimits(List<AppLimit> limits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLimitsKey, jsonEncode(limits.map((l) => l.toJson()).toList()));
  }

  Future<Map<String, int>> loadUsageToday(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usageKey(date));
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveUsageToday(DateTime date, Map<String, int> usage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usageKey(date), jsonEncode(usage));
  }

  Future<DailyTracking> loadTracking(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trackingKey(date));
    if (raw == null) return DailyTracking();
    return DailyTracking.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTracking(DateTime date, DailyTracking tracking) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trackingKey(date), jsonEncode(tracking.toJson()));
  }
}
