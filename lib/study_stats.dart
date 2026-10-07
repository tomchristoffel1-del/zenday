import 'models.dart';
import 'storage.dart';
import 'study_models.dart';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

String fmtHm(int seconds) {
  final totalMinutes = (seconds / 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m min';
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

String fmtClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

int _toMinutes(String? hhmm) {
  if (hhmm == null) return -1;
  final parts = hhmm.split(':');
  if (parts.length != 2) return -1;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return -1;
  return h * 60 + m;
}

/// Dauer in Minuten zwischen Start und Ende; 0, wenn eine der Zeiten fehlt.
int durationMinutes(String? start, String? end) {
  final s = _toMinutes(start);
  final e = _toMinutes(end);
  if (s < 0 || e < 0 || e <= s) return 0;
  return e - s;
}

/// Pro-Modul-Auswertung für Seitenziele.
class ModuleStats {
  final StudyModule module;
  final int pagesDone;
  final int remaining;
  final double? minutesPerPage;
  final double? pagesPerSession;
  final int exerciseSeconds;
  final int mockExamSeconds;
  final int totalSeconds;
  final double? neededPerDay;
  final double? neededPerWeek;
  final int? daysLeft;
  final double? estimatedRemainingHours;
  final int pagesThisWeek;
  final int? weekTarget;
  final int videoSeconds;

  const ModuleStats({
    required this.pagesThisWeek,
    required this.weekTarget,
    required this.videoSeconds,
    required this.module,
    required this.pagesDone,
    required this.remaining,
    required this.minutesPerPage,
    required this.pagesPerSession,
    required this.exerciseSeconds,
    required this.mockExamSeconds,
    required this.totalSeconds,
    required this.neededPerDay,
    required this.neededPerWeek,
    required this.daysLeft,
    required this.estimatedRemainingHours,
  });
}

class StudyStats {
  static int sumSeconds(List<StudySession> sessions, DateTime from, DateTime to) {
    final start = dayOf(from);
    final end = nextDay(to);
    var total = 0;
    for (final s in sessions) {
      if (!s.start.isBefore(start) && s.start.isBefore(end)) total += s.seconds;
    }
    return total;
  }

  /// Geplante Lernzeit (Minuten) aller als Lerneinheit markierten Aufgaben
  /// zwischen [from] und [to] (beide inklusive), inkl. Ausnahmetagen.
  static Future<int> plannedMinutes(
    ZenStorage storage,
    List<TaskTemplate> templates,
    DateTime from,
    DateTime to,
  ) async {
    final studyTemplates = templates.where((t) => t.isStudy).toList();
    var total = 0;
    final last = dayOf(to);
    for (var d = dayOf(from); !d.isAfter(last); d = nextDay(d)) {
      for (final t in studyTemplates) {
        if (t.appliesOn(d)) total += durationMinutes(t.startTime, t.endTime);
      }
      final adhoc = await storage.loadAdHoc(d);
      for (final a in adhoc) {
        if (a.isStudy) total += durationMinutes(a.startTime, a.endTime);
      }
    }
    return total;
  }

  static int distinctStudyDays(List<StudySession> sessions) {
    return sessions.map((s) => dayOf(s.start)).toSet().length;
  }

  /// Anzahl Wochen vom ersten Tracking bis heute (mindestens 1).
  static int weeksSpanned(List<StudySession> sessions, DateTime now) {
    if (sessions.isEmpty) return 1;
    final first = sessions.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final days = weekStartOf(now).difference(weekStartOf(first)).inDays;
    return (days ~/ 7) + 1;
  }

  static int monthsSpanned(List<StudySession> sessions, DateTime now) {
    if (sessions.isEmpty) return 1;
    final first = sessions.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    return (now.year - first.year) * 12 + (now.month - first.month) + 1;
  }

  static Map<StudyActivity, int> secondsByActivity(List<StudySession> sessions) {
    final result = {for (final a in StudyActivity.values) a: 0};
    for (final s in sessions) {
      result[s.activity] = (result[s.activity] ?? 0) + s.seconds;
    }
    return result;
  }

  static ModuleStats forModule(StudyModule module, List<StudySession> all, DateTime now) {
    final mine = all.where((s) => s.moduleId == module.id).toList();
    final pageSessions = mine.where((s) => s.activity == StudyActivity.pages && s.pages > 0).toList();

    final pagesTracked = mine.fold<int>(0, (sum, s) => sum + s.pages);
    final pagesDone = module.pagesOffset + pagesTracked;
    final remaining = (module.totalPages - pagesDone).clamp(0, module.totalPages);

    final pageSeconds = pageSessions.fold<int>(0, (sum, s) => sum + s.seconds);
    final pagesInPageSessions = pageSessions.fold<int>(0, (sum, s) => sum + s.pages);

    double? minutesPerPage;
    double? pagesPerSession;
    if (pagesInPageSessions > 0) {
      minutesPerPage = (pageSeconds / 60) / pagesInPageSessions;
      pagesPerSession = pagesInPageSessions / pageSessions.length;
    }

    int secondsOf(StudyActivity a) =>
        mine.where((s) => s.activity == a).fold<int>(0, (sum, s) => sum + s.seconds);

    int? daysLeft;
    double? neededPerDay;
    double? neededPerWeek;
    if (module.deadline != null) {
      daysLeft = dayOf(module.deadline!).difference(dayOf(now)).inDays;
      if (daysLeft > 0 && remaining > 0) {
        neededPerDay = remaining / daysLeft;
        neededPerWeek = remaining / (daysLeft / 7);
      }
    }

    final estimatedRemainingHours =
        (minutesPerPage != null && remaining > 0) ? remaining * minutesPerPage / 60 : null;

    // Wochenziel: die zu Wochenbeginn offenen Seiten gleichmäßig auf die bis
    // zur Frist verbleibenden Wochen verteilen. Bleibt innerhalb der Woche
    // stabil, auch wenn man währenddessen Seiten schafft.
    final weekStart = weekStartOf(now);
    final pagesThisWeek = mine
        .where((s) => !s.start.isBefore(weekStart))
        .fold<int>(0, (sum, s) => sum + s.pages);
    final pagesBeforeWeek = module.pagesOffset +
        mine.where((s) => s.start.isBefore(weekStart)).fold<int>(0, (sum, s) => sum + s.pages);
    final remainingAtWeekStart = (module.totalPages - pagesBeforeWeek).clamp(0, module.totalPages);
    int? weekTarget;
    if (module.deadline != null) {
      final weeksLeft = dayOf(module.deadline!).difference(weekStart).inDays / 7;
      weekTarget = weeksLeft <= 1 ? remainingAtWeekStart : (remainingAtWeekStart / weeksLeft).ceil();
    }

    return ModuleStats(
      pagesThisWeek: pagesThisWeek,
      weekTarget: weekTarget,
      videoSeconds: secondsOf(StudyActivity.videos),
      module: module,
      pagesDone: pagesDone,
      remaining: remaining,
      minutesPerPage: minutesPerPage,
      pagesPerSession: pagesPerSession,
      exerciseSeconds: secondsOf(StudyActivity.exercises),
      mockExamSeconds: secondsOf(StudyActivity.mockExam),
      totalSeconds: mine.fold<int>(0, (sum, s) => sum + s.seconds),
      neededPerDay: neededPerDay,
      neededPerWeek: neededPerWeek,
      daysLeft: daysLeft,
      estimatedRemainingHours: estimatedRemainingHours,
    );
  }

  /// Rät das Modul der gerade laufenden Lerneinheit: erst eine heute aktive
  /// (oder die zeitlich nächste) als Lerneinheit markierte Aufgabe suchen und
  /// deren Titel mit den Modulnamen abgleichen.
  static Future<String?> guessModuleId(
    ZenStorage storage,
    List<TaskTemplate> templates,
    List<StudyModule> modules,
    DateTime at,
  ) async {
    final day = dayOf(at);
    final items = <({String title, String? start, String? end})>[
      for (final t in templates)
        if (t.isStudy && t.appliesOn(day)) (title: t.title, start: t.startTime, end: t.endTime),
      for (final a in await storage.loadAdHoc(day))
        if (a.isStudy) (title: a.title, start: a.startTime, end: a.endTime),
    ];
    if (items.isEmpty) return null;

    final nowMin = at.hour * 60 + at.minute;
    ({String title, String? start, String? end})? best;
    var bestDistance = 1 << 30;
    for (final item in items) {
      final s = _toMinutes(item.start);
      final e = _toMinutes(item.end);
      if (s < 0) continue;
      final distance = (e >= 0 && nowMin >= s && nowMin < e) ? 0 : (nowMin - s).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = item;
      }
    }
    best ??= items.first;

    final title = best.title.toLowerCase();
    for (final m in modules) {
      if (title.contains(m.name.toLowerCase())) return m.id;
    }
    return null;
  }
}
