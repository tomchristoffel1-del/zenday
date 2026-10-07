/// Datenmodelle für ZenDay: wiederkehrende Vorlagen (Templates), die den
/// Grundplan der Woche bilden, plus Ad-hoc-Aufgaben für einzelne Tage.
library;

enum Repeat { daily, weekdays, weekend, custom }

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${(DateTime.now().microsecondsSinceEpoch % 97)}';

/// Eine wiederkehrende Aufgabe ("jeden Tag", "nur wochentags", "nur am
/// Wochenende" oder an frei gewählten Wochentagen). Bildet den Grundplan.
class TaskTemplate {
  final String id;
  String title;
  Repeat repeat;
  Set<int> customDays; // ISO-Wochentag 1=Mo .. 7=So, nur bei Repeat.custom
  String? startTime; // "HH:mm" oder null (zeitlos = Checkliste)
  String? endTime;
  String? linkedListId; // verknüpfte Blockliste (FocusGuard sperrt während startTime–endTime)
  Set<String> excludedDates; // "yyyy-MM-dd" – einzelne Ausnahmetage (z.B. Reisetag)
  bool isStudy; // zählt (über Start–Ende) zur geplanten Lernzeit

  TaskTemplate({
    String? id,
    required this.title,
    required this.repeat,
    Set<int>? customDays,
    this.startTime,
    this.endTime,
    this.linkedListId,
    Set<String>? excludedDates,
    this.isStudy = false,
  })  : id = id ?? newId(),
        customDays = customDays ?? {},
        excludedDates = excludedDates ?? {};

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool appliesOn(DateTime date) {
    if (excludedDates.contains(_fmtDate(date))) return false;
    switch (repeat) {
      case Repeat.daily:
        return true;
      case Repeat.weekdays:
        return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
      case Repeat.weekend:
        return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      case Repeat.custom:
        return customDays.contains(date.weekday);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'repeat': repeat.name,
        'customDays': customDays.toList(),
        'startTime': startTime,
        'endTime': endTime,
        'linkedListId': linkedListId,
        'excludedDates': excludedDates.toList(),
        'isStudy': isStudy,
      };

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        repeat: Repeat.values.firstWhere(
          (r) => r.name == json['repeat'],
          orElse: () => Repeat.daily,
        ),
        customDays: (json['customDays'] as List<dynamic>? ?? [])
            .map((e) => e as int)
            .toSet(),
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        linkedListId: json['linkedListId'] as String?,
        excludedDates: (json['excludedDates'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toSet(),
        isStudy: json['isStudy'] as bool? ?? false,
      );
}

/// Eine einmalige Aufgabe für ein konkretes Datum – die "Lücken", die der
/// Nutzer nach dem Grundplan selbst füllt.
class AdHocTask {
  final String id;
  String title;
  String? startTime;
  String? endTime;
  bool done;
  String? linkedListId;
  bool isStudy;

  AdHocTask({
    String? id,
    required this.title,
    this.startTime,
    this.endTime,
    this.done = false,
    this.linkedListId,
    this.isStudy = false,
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startTime': startTime,
        'endTime': endTime,
        'done': done,
        'linkedListId': linkedListId,
        'isStudy': isStudy,
      };

  factory AdHocTask.fromJson(Map<String, dynamic> json) => AdHocTask(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        done: json['done'] as bool? ?? false,
        linkedListId: json['linkedListId'] as String?,
        isStudy: json['isStudy'] as bool? ?? false,
      );
}

/// Einheitliche Ansicht auf eine Zeile im Tagesplan, egal ob sie aus einem
/// Template oder einer Ad-hoc-Aufgabe stammt.
class PlanItem {
  final String id;
  final String title;
  final String? startTime;
  final String? endTime;
  final bool isTemplate;
  final bool editable;
  final bool done;

  const PlanItem({
    required this.id,
    required this.title,
    required this.isTemplate,
    required this.editable,
    required this.done,
    this.startTime,
    this.endTime,
  });
}

class FocusConfig {
  List<String> blockedProcesses;
  List<String> blockedWebsites;
  String? startTime;
  String? endTime;
  bool enabled;

  FocusConfig({
    List<String>? blockedProcesses,
    List<String>? blockedWebsites,
    this.startTime,
    this.endTime,
    this.enabled = false,
  })  : blockedProcesses = blockedProcesses ?? [],
        blockedWebsites = blockedWebsites ?? [];

  Map<String, dynamic> toJson() => {
        'blockedProcesses': blockedProcesses,
        'blockedWebsites': blockedWebsites,
        'startTime': startTime,
        'endTime': endTime,
        'enabled': enabled,
      };

  factory FocusConfig.fromJson(Map<String, dynamic> json) => FocusConfig(
        blockedProcesses: (json['blockedProcesses'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        blockedWebsites: (json['blockedWebsites'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        enabled: json['enabled'] as bool? ?? false,
      );
}

/// Wie schwer man eine aktive Blockliste vorzeitig umgehen kann.
enum BypassMode { easy, medium, hard }

/// Eine benannte, wiederverwendbare Blockliste ("Nicht stören", "Arbeit", …),
/// die an eine oder mehrere Aufgaben angehängt werden kann. Während die
/// verknüpfte Aufgabe läuft, blockiert FocusGuard automatisch alles hier
/// Eingetragene.
class BlockList {
  final String id;
  String name;
  List<String> processes;
  List<String> websites;
  BypassMode bypassMode;
  int bypassWaitSeconds;
  int? unlockDurationMinutes; // null = bis Ende des Zeitfensters
  DateTime? unlockedUntil; // Laufzeit-/persistenter Bypass-Zustand

  BlockList({
    String? id,
    required this.name,
    List<String>? processes,
    List<String>? websites,
    this.bypassMode = BypassMode.easy,
    this.bypassWaitSeconds = 60,
    this.unlockDurationMinutes = 15,
    this.unlockedUntil,
  })  : id = id ?? newId(),
        processes = processes ?? [],
        websites = websites ?? [];

  bool get isBypassedNow => unlockedUntil != null && DateTime.now().isBefore(unlockedUntil!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'processes': processes,
        'websites': websites,
        'bypassMode': bypassMode.name,
        'bypassWaitSeconds': bypassWaitSeconds,
        'unlockDurationMinutes': unlockDurationMinutes,
        'unlockedUntil': unlockedUntil?.toIso8601String(),
      };

  factory BlockList.fromJson(Map<String, dynamic> json) => BlockList(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        processes: (json['processes'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        websites: (json['websites'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        bypassMode: BypassMode.values.firstWhere(
          (m) => m.name == json['bypassMode'],
          orElse: () => BypassMode.easy,
        ),
        bypassWaitSeconds: json['bypassWaitSeconds'] as int? ?? 60,
        unlockDurationMinutes: json.containsKey('unlockDurationMinutes')
            ? json['unlockDurationMinutes'] as int?
            : 15,
        unlockedUntil: json['unlockedUntil'] != null
            ? DateTime.tryParse(json['unlockedUntil'] as String)
            : null,
      );
}

/// Eine von Aufgaben unabhängige App-Regel: entweder dauerhaft gesperrt,
/// oder mit einem täglichen Zeitbudget (wie Bildschirmzeit-Limits).
class AppLimit {
  final String id;
  String process;
  bool alwaysBlocked;
  int? dailyMinutes; // null, wenn alwaysBlocked

  AppLimit({
    String? id,
    required this.process,
    this.alwaysBlocked = false,
    this.dailyMinutes,
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'process': process,
        'alwaysBlocked': alwaysBlocked,
        'dailyMinutes': dailyMinutes,
      };

  factory AppLimit.fromJson(Map<String, dynamic> json) => AppLimit(
        id: json['id'] as String,
        process: json['process'] as String? ?? '',
        alwaysBlocked: json['alwaysBlocked'] as bool? ?? false,
        dailyMinutes: json['dailyMinutes'] as int?,
      );
}

/// 0 = nicht so glücklich, 1 = mittel, 2 = glücklich.
enum Mood { low, mid, high }

/// Die drei täglichen Gewohnheits-Tracker, die unabhängig vom Aufgabenplan
/// jeden Tag abgehakt werden: Gemüse, Stimmung, kein Zucker. Sport wird
/// nicht hier, sondern automatisch aus dem "Sport & Training"-Task abgeleitet.
class DailyTracking {
  bool vegetables;
  Mood? mood;
  bool sugarFree;

  DailyTracking({this.vegetables = false, this.mood, this.sugarFree = false});

  Map<String, dynamic> toJson() => {
        'vegetables': vegetables,
        'mood': mood?.name,
        'sugarFree': sugarFree,
      };

  factory DailyTracking.fromJson(Map<String, dynamic> json) => DailyTracking(
        vegetables: json['vegetables'] as bool? ?? false,
        mood: json['mood'] != null
            ? Mood.values.firstWhere((m) => m.name == json['mood'], orElse: () => Mood.mid)
            : null,
        sugarFree: json['sugarFree'] as bool? ?? false,
      );
}
