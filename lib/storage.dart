import 'dart:convert';
import 'sync/synced_prefs.dart';
import 'models.dart';
import 'study_models.dart';

/// Lokale, blitzschnelle Persistenz ohne Server, ohne Ladezeiten.
class ZenStorage {
  static const _studySessionsKey = 'zenday_study_sessions'; // nur noch für die Migration
  static const _sessionPrefix = 'zenday_ssess_';
  static const _studyModulesKey = 'zenday_study_modules';
  static const _studyRunningKey = 'zenday_study_running_start';
  static const _assignmentsKey = 'zenday_assignments';

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
    final prefs = await SyncedPrefs.instance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded() async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<List<TaskTemplate>> loadTemplates() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_templatesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTemplates(List<TaskTemplate> templates) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(
      _templatesKey,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  Future<List<AdHocTask>> loadAdHoc(DateTime date) async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_adhocKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AdHocTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAdHoc(DateTime date, List<AdHocTask> tasks) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(
      _adhocKey(date),
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  Future<Set<String>> loadTemplateDoneIds(DateTime date) async {
    final prefs = await SyncedPrefs.instance();
    return (prefs.getStringList(_tplDoneKey(date)) ?? []).toSet();
  }

  Future<void> saveTemplateDoneIds(DateTime date, Set<String> ids) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setStringList(_tplDoneKey(date), ids.toList());
  }

  Future<String> loadDayFocus(DateTime date) async {
    final prefs = await SyncedPrefs.instance();
    return prefs.getString(_dayFocusKey(date)) ?? '';
  }

  Future<void> saveDayFocus(DateTime date, String focus) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_dayFocusKey(date), focus);
  }

  Future<FocusConfig> loadFocusConfig() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_focusConfigKey);
    if (raw == null) return FocusConfig();
    return FocusConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveFocusConfig(FocusConfig config) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_focusConfigKey, jsonEncode(config.toJson()));
  }

  Future<int> loadPoints() async {
    final prefs = await SyncedPrefs.instance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  Future<void> savePoints(int points) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setInt(_pointsKey, points);
  }

  Future<List<String>> loadOrder(DateTime date) async {
    final prefs = await SyncedPrefs.instance();
    return prefs.getStringList(_orderKey(date)) ?? [];
  }

  Future<void> saveOrder(DateTime date, List<String> order) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setStringList(_orderKey(date), order);
  }

  Future<String> loadThemeModePref() async {
    final prefs = await SyncedPrefs.instance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> saveThemeModePref(String mode) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_themeModeKey, mode);
  }

  Future<int> loadAccentIndex() async {
    final prefs = await SyncedPrefs.instance();
    return prefs.getInt(_accentIndexKey) ?? 0;
  }

  Future<void> saveAccentIndex(int index) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setInt(_accentIndexKey, index);
  }

  Future<List<BlockList>> loadBlockLists() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_blockListsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => BlockList.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBlockLists(List<BlockList> lists) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_blockListsKey, jsonEncode(lists.map((l) => l.toJson()).toList()));
  }

  Future<bool> loadAutostart() async {
    final prefs = await SyncedPrefs.instance();
    return prefs.getBool(_autostartKey) ?? false;
  }

  Future<void> saveAutostart(bool value) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setBool(_autostartKey, value);
  }

  Future<List<AppLimit>> loadAppLimits() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_appLimitsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AppLimit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAppLimits(List<AppLimit> limits) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_appLimitsKey, jsonEncode(limits.map((l) => l.toJson()).toList()));
  }

  Future<Map<String, int>> loadUsageToday(DateTime date) async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_usageKey(date));
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveUsageToday(DateTime date, Map<String, int> usage) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_usageKey(date), jsonEncode(usage));
  }

  Future<DailyTracking> loadTracking(DateTime date) async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_trackingKey(date));
    if (raw == null) return DailyTracking();
    return DailyTracking.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTracking(DateTime date, DailyTracking tracking) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_trackingKey(date), jsonEncode(tracking.toJson()));
  }

  /// Jede Lerneinheit liegt unter einem eigenen Schlüssel, damit zwei Geräte,
  /// die gleichzeitig Einheiten erfassen, sich beim Abgleich nicht überschreiben.
  Future<List<StudySession>> loadStudySessions() async {
    final prefs = await SyncedPrefs.instance();

    final legacy = prefs.getString(_studySessionsKey);
    if (legacy != null) {
      for (final e in jsonDecode(legacy) as List<dynamic>) {
        final s = StudySession.fromJson(e as Map<String, dynamic>);
        await prefs.setString('$_sessionPrefix${s.id}', jsonEncode(s.toJson()));
      }
      await prefs.remove(_studySessionsKey);
    }

    final result = <StudySession>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_sessionPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        result.add(StudySession.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Beschädigter Eintrag: überspringen statt die ganze Liste zu verlieren.
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  Future<void> saveStudySessions(List<StudySession> sessions) async {
    final prefs = await SyncedPrefs.instance();
    final wanted = {for (final s in sessions) '$_sessionPrefix${s.id}': jsonEncode(s.toJson())};
    for (final e in wanted.entries) {
      await prefs.setString(e.key, e.value);
    }
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_sessionPrefix) && !wanted.containsKey(key)) await prefs.remove(key);
    }
  }

  static String _incomeKey(int year, int month) => 'zenday_income_$year-${month.toString().padLeft(2, '0')}';

  /// Monatseinkommen eines Jahres (Monat 1–12 → Betrag); nicht erfasste Monate fehlen.
  Future<Map<int, double>> loadIncomeYear(int year) async {
    final prefs = await SyncedPrefs.instance();
    final result = <int, double>{};
    for (var month = 1; month <= 12; month++) {
      final value = double.tryParse(prefs.getString(_incomeKey(year, month)) ?? '');
      if (value != null) result[month] = value;
    }
    return result;
  }

  Future<void> saveIncome(int year, int month, double? amount) async {
    final prefs = await SyncedPrefs.instance();
    if (amount == null) {
      await prefs.remove(_incomeKey(year, month));
    } else {
      await prefs.setString(_incomeKey(year, month), amount.toString());
    }
  }

  Future<List<StudyModule>> loadStudyModules() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_studyModulesKey);
    if (raw == null) return defaultStudyModules();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => StudyModule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveStudyModules(List<StudyModule> modules) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_studyModulesKey, jsonEncode(modules.map((m) => m.toJson()).toList()));
  }

  Future<List<Assignment>> loadAssignments() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_assignmentsKey);
    if (raw == null) return defaultAssignments();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAssignments(List<Assignment> assignments) async {
    final prefs = await SyncedPrefs.instance();
    await prefs.setString(_assignmentsKey, jsonEncode(assignments.map((a) => a.toJson()).toList()));
  }

  Future<DateTime?> loadStudyRunningStart() async {
    final prefs = await SyncedPrefs.instance();
    final raw = prefs.getString(_studyRunningKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveStudyRunningStart(DateTime? start) async {
    final prefs = await SyncedPrefs.instance();
    if (start == null) {
      await prefs.remove(_studyRunningKey);
    } else {
      await prefs.setString(_studyRunningKey, start.toIso8601String());
    }
  }
}
