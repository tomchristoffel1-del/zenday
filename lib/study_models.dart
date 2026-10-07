import 'models.dart';

/// Wofür die Lernzeit einer Session aufgewendet wurde.
enum StudyActivity { pages, exercises, mockExam, videos }

const studyActivityLabels = {
  StudyActivity.pages: 'Seiten',
  StudyActivity.exercises: 'Aufgaben',
  StudyActivity.mockExam: 'Probeklausur',
  StudyActivity.videos: 'Lernvideos',
};

/// Eine Pflichtaufgabe eines Moduls. Zulassung zur Klausur: pro Modul muss
/// mindestens eine der Aufgaben mit mindestens der halben Punktzahl gelöst sein.
class Assignment {
  final String id;
  final String moduleId;
  String title;
  DateTime? deadline;
  double? maxPoints;
  double? points;

  Assignment({
    required this.id,
    required this.moduleId,
    required this.title,
    this.deadline,
    this.maxPoints,
    this.points,
  });

  bool get hasResult => maxPoints != null && maxPoints! > 0 && points != null;
  bool get passesHalf => hasResult && points! >= maxPoints! / 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'moduleId': moduleId,
        'title': title,
        'deadline': deadline?.toIso8601String(),
        'maxPoints': maxPoints,
        'points': points,
      };

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'] as String,
        moduleId: json['moduleId'] as String,
        title: json['title'] as String? ?? '',
        deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
        maxPoints: (json['maxPoints'] as num?)?.toDouble(),
        points: (json['points'] as num?)?.toDouble(),
      );
}

/// Zwei Pflichtaufgaben pro Standardmodul.
List<Assignment> defaultAssignments() => [
      for (final moduleId in ['wiwi', 'wiinf', 'mathe'])
        for (final n in [1, 2])
          Assignment(id: '$moduleId-$n', moduleId: moduleId, title: 'Pflichtaufgabe $n'),
    ];

/// Ein Modul mit Seitenziel. [pagesOffset] sind Seiten, die schon vor dem
/// Tracking geschafft waren.
class StudyModule {
  final String id;
  String name;
  int totalPages;
  int pagesOffset;
  DateTime? deadline;

  StudyModule({
    required this.id,
    required this.name,
    required this.totalPages,
    this.pagesOffset = 0,
    this.deadline,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalPages': totalPages,
        'pagesOffset': pagesOffset,
        'deadline': deadline?.toIso8601String(),
      };

  factory StudyModule.fromJson(Map<String, dynamic> json) => StudyModule(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        totalPages: json['totalPages'] as int? ?? 0,
        pagesOffset: json['pagesOffset'] as int? ?? 0,
        deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
      );
}

/// Standard-Module. Die Namen entsprechen den Kürzeln in den Lernblock-Titeln
/// ("Lernblock 1: WiWi"), damit das Modul automatisch erraten werden kann.
List<StudyModule> defaultStudyModules() => [
      StudyModule(id: 'wiwi', name: 'WiWi', totalPages: 700),
      StudyModule(id: 'wiinf', name: 'WiInf', totalPages: 700),
      StudyModule(id: 'mathe', name: 'Mathe/Statistik', totalPages: 960),
    ];

/// Eine abgeschlossene Lerneinheit – per Timer gemessen oder manuell eingetragen.
class StudySession {
  final String id;
  DateTime start;
  int seconds;
  String? moduleId;
  StudyActivity activity;
  int pages;
  bool manual;

  StudySession({
    String? id,
    required this.start,
    required this.seconds,
    this.moduleId,
    this.activity = StudyActivity.pages,
    this.pages = 0,
    this.manual = false,
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'seconds': seconds,
        'moduleId': moduleId,
        'activity': activity.name,
        'pages': pages,
        'manual': manual,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        start: DateTime.parse(json['start'] as String),
        seconds: json['seconds'] as int? ?? 0,
        moduleId: json['moduleId'] as String?,
        activity: StudyActivity.values.firstWhere(
          (a) => a.name == json['activity'],
          orElse: () => StudyActivity.pages,
        ),
        pages: json['pages'] as int? ?? 0,
        manual: json['manual'] as bool? ?? false,
      );
}
