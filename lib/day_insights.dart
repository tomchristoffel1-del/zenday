import 'day_notes.dart';
import 'models.dart';

/// Alles, was über einen einzelnen Tag bekannt ist – Grundlage der Tagesanalyse.
class DayRecord {
  final DateTime date;
  final int studyMinutes;
  final int plannedStudyMinutes;
  final int tasksTotal;
  final int tasksDone;
  final Mood? mood;
  final DayNote? note;

  DayRecord({
    required this.date,
    this.studyMinutes = 0,
    this.plannedStudyMinutes = 0,
    this.tasksTotal = 0,
    this.tasksDone = 0,
    this.mood,
    this.note,
  });

  Set<String> get tags => note?.tags ?? const {};
  bool get hasNote => note != null && !note!.isEmpty;

  /// Ein Tag zählt für die Lernauswertung, wenn Lernen geplant war oder gelernt wurde.
  bool get isStudyDay => plannedStudyMinutes > 0 || studyMinutes > 0;

  double? get taskRate => tasksTotal == 0 ? null : tasksDone / tasksTotal;

  /// Erreichter Anteil der geplanten Lernzeit (ohne Plan: null).
  double? get goalRatio => plannedStudyMinutes == 0 ? null : studyMinutes / plannedStudyMinutes;

  /// Weniger als die Hälfte der geplanten Lernzeit geschafft.
  bool get missedGoal => plannedStudyMinutes > 0 && studyMinutes < plannedStudyMinutes * 0.5;
}

double? _avg(Iterable<num> values) {
  if (values.isEmpty) return null;
  return values.fold<double>(0, (s, v) => s + v) / values.length;
}

double? _moodScore(Mood? m) => m == null ? null : (m.index + 1).toDouble(); // 1..3

class CategoryImpact {
  final NoteCategory category;
  final List<DayRecord> days;

  /// Ø Lernminuten an Lerntagen mit bzw. ohne diese Kategorie.
  final double? avgStudyWith;
  final double? avgStudyWithout;
  final double? taskRateWith;
  final double? taskRateWithout;
  final double? moodWith;

  CategoryImpact({
    required this.category,
    required this.days,
    this.avgStudyWith,
    this.avgStudyWithout,
    this.taskRateWith,
    this.taskRateWithout,
    this.moodWith,
  });

  /// Relative Abweichung der Lernzeit gegenüber Tagen ohne die Kategorie (−0.35 = 35 % weniger).
  double? get studyDelta {
    if (avgStudyWith == null || avgStudyWithout == null || avgStudyWithout == 0) return null;
    return avgStudyWith! / avgStudyWithout! - 1;
  }
}

/// Eine Kategorie, die in einer Gruppe von Tagen (z. B. den besten) häufiger vorkommt als sonst.
class TagShift {
  final NoteCategory category;
  final double shareInGroup;
  final double shareElsewhere;

  TagShift(this.category, this.shareInGroup, this.shareElsewhere);

  double get difference => shareInGroup - shareElsewhere;
}

class MissedGoalReason {
  final NoteCategory category;
  final int days;

  MissedGoalReason(this.category, this.days);
}

class DayInsights {
  final List<DayRecord> records;
  final List<DayRecord> noteDays;
  final List<CategoryImpact> categories;
  final double? avgStudyPerStudyDay;
  final double? avgTaskRate;

  /// Tage mit geplantem Lernen, an denen weniger als die Hälfte geschafft wurde.
  final List<DayRecord> missedDays;
  final int plannedStudyDays;
  final List<MissedGoalReason> missedReasons;
  final int missedWithoutNote;
  final int missedWithoutNegativeTag;

  /// Was die besten bzw. schwächsten Lerntage auszeichnet (leer, wenn zu wenig Daten).
  final List<TagShift> bestDayTraits;
  final List<TagShift> worstDayTraits;
  final int bestDayCount;

  DayInsights._({
    required this.records,
    required this.noteDays,
    required this.categories,
    required this.avgStudyPerStudyDay,
    required this.avgTaskRate,
    required this.missedDays,
    required this.plannedStudyDays,
    required this.missedReasons,
    required this.missedWithoutNote,
    required this.missedWithoutNegativeTag,
    required this.bestDayTraits,
    required this.worstDayTraits,
    required this.bestDayCount,
  });

  int daysWith(String categoryId) => records.where((r) => r.tags.contains(categoryId)).length;

  /// Mindestanzahl Lerntage, ab der "bester/schwächster Tag" aussagekräftig ist.
  static const minDaysForComparison = 8;

  factory DayInsights.compute(List<DayRecord> records) {
    final studyDays = records.where((r) => r.isStudyDay).toList();
    final noteDays = records.where((r) => r.hasNote).toList();

    final categories = <CategoryImpact>[];
    for (final c in noteCategories) {
      final withTag = records.where((r) => r.tags.contains(c.id)).toList();
      if (withTag.isEmpty) continue;
      final studyWith = studyDays.where((r) => r.tags.contains(c.id));
      final studyWithout = studyDays.where((r) => !r.tags.contains(c.id));
      categories.add(CategoryImpact(
        category: c,
        days: withTag,
        avgStudyWith: _avg(studyWith.map((r) => r.studyMinutes)),
        avgStudyWithout: _avg(studyWithout.map((r) => r.studyMinutes)),
        taskRateWith: _avg(withTag.map((r) => r.taskRate).whereType<double>()),
        taskRateWithout: _avg(records.where((r) => !r.tags.contains(c.id)).map((r) => r.taskRate).whereType<double>()),
        moodWith: _avg(withTag.map((r) => _moodScore(r.mood)).whereType<double>()),
      ));
    }
    categories.sort((a, b) => b.days.length.compareTo(a.days.length));

    final planned = records.where((r) => r.plannedStudyMinutes > 0).toList();
    final missed = planned.where((r) => r.missedGoal).toList();
    final reasons = <MissedGoalReason>[];
    for (final c in noteCategories.where((c) => c.polarity != Polarity.positive)) {
      final n = missed.where((r) => r.tags.contains(c.id)).length;
      if (n > 0) reasons.add(MissedGoalReason(c, n));
    }
    reasons.sort((a, b) => b.days.compareTo(a.days));
    final negativeIds = noteCategories.where((c) => c.polarity == Polarity.negative).map((c) => c.id).toSet();

    // Beste/schwächste Lerntage: oberes und unteres Viertel nach Zielerreichung
    // (ohne Plan zählen die absoluten Minuten).
    var bestTraits = <TagShift>[];
    var worstTraits = <TagShift>[];
    var bestCount = 0;
    if (studyDays.length >= minDaysForComparison) {
      final sorted = [...studyDays]..sort((a, b) => _dayScore(b).compareTo(_dayScore(a)));
      bestCount = (sorted.length / 4).ceil();
      final best = sorted.take(bestCount).toList();
      final worst = sorted.reversed.take(bestCount).toList();
      bestTraits = _shifts(best, studyDays);
      worstTraits = _shifts(worst, studyDays);
    }

    return DayInsights._(
      records: records,
      noteDays: noteDays,
      categories: categories,
      avgStudyPerStudyDay: _avg(studyDays.map((r) => r.studyMinutes)),
      avgTaskRate: _avg(records.map((r) => r.taskRate).whereType<double>()),
      missedDays: missed,
      plannedStudyDays: planned.length,
      missedReasons: reasons,
      missedWithoutNote: missed.where((r) => !r.hasNote).length,
      missedWithoutNegativeTag: missed.where((r) => r.hasNote && !r.tags.any(negativeIds.contains)).length,
      bestDayTraits: bestTraits,
      worstDayTraits: worstTraits,
      bestDayCount: bestCount,
    );
  }

  static double _dayScore(DayRecord r) => r.goalRatio ?? r.studyMinutes / 240.0;

  /// Kategorien, die in [group] deutlich häufiger sind als in den übrigen Tagen von [all].
  static List<TagShift> _shifts(List<DayRecord> group, List<DayRecord> all) {
    final groupSet = group.toSet();
    final rest = all.where((r) => !groupSet.contains(r)).toList();
    if (group.isEmpty || rest.isEmpty) return [];
    final result = <TagShift>[];
    for (final c in noteCategories) {
      final inGroup = group.where((r) => r.tags.contains(c.id)).length / group.length;
      final elsewhere = rest.where((r) => r.tags.contains(c.id)).length / rest.length;
      if (inGroup - elsewhere >= 0.15 && inGroup > 0) result.add(TagShift(c, inGroup, elsewhere));
    }
    result.sort((a, b) => b.difference.compareTo(a.difference));
    return result.take(4).toList();
  }
}
