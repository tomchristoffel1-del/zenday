import 'package:flutter_test/flutter_test.dart';
import 'package:zenday/day_insights.dart';
import 'package:zenday/day_notes.dart';
import 'package:zenday/models.dart';

void main() {
  group('Kategorien erkennen', () {
    test('typische Notizen', () {
      expect(detectCategories('Krank, Fieber und Kopfschmerzen'), {'sick'});
      expect(detectCategories('schlecht gegessen, schlechte Laune und unkonzentriert'),
          {'badFood', 'badMood', 'unfocused'});
      expect(detectCategories('Gut geschlafen, sehr fokussiert, danach Gym'), {'rested', 'focused', 'sport'});
    });

    test('Wortanfang: "unkonzentriert" ist nicht "konzentriert"', () {
      expect(detectCategories('total unkonzentriert'), {'unfocused'});
    });

    test('Verneinung wird beachtet', () {
      expect(detectCategories('nicht müde, kein Sport'), isEmpty);
      expect(detectCategories('nicht gut geschlafen'), {'tired'});
      expect(detectCategories('keine Konzentration'), {'unfocused'});
    });

    test('keine Fehltreffer in Lernnotizen', () {
      expect(detectCategories('Daten modelliert, Datenbank-Kapitel'), isEmpty);
      expect(detectCategories('Klausurvorbereitung ist gut gelaufen'), isEmpty);
    });
  });

  group('Manuelle Korrektur', () {
    test('Abwahl und Ergänzung bleiben beim Weiterschreiben erhalten', () {
      final note = DayNote(text: 'müde');
      expect(note.tags, {'tired'});
      note.toggle('tired');
      note.toggle('stress');
      expect(note.tags, {'stress'});
      note.text = 'müde und krank';
      expect(note.tags, {'stress', 'sick'});

      final restored = DayNote.fromJson(note.toJson());
      expect(restored.tags, {'stress', 'sick'});
    });

    test('leere Notiz', () {
      expect(DayNote().isEmpty, isTrue);
      expect(DayNote(text: '  ').isEmpty, isTrue);
      expect(DayNote(added: {'sick'}).isEmpty, isFalse);
    });
  });

  group('Auswertung', () {
    DayRecord day(int i, int study, {int planned = 240, String? note}) => DayRecord(
          date: DateTime(2026, 10, 1 + i),
          studyMinutes: study,
          plannedStudyMinutes: planned,
          tasksTotal: 4,
          tasksDone: study >= 120 ? 4 : 1,
          mood: Mood.mid,
          note: note == null ? null : DayNote(text: note),
        );

    test('verfehlte Lernziele mit Gründen', () {
      final ins = DayInsights.compute([
        day(0, 240, note: 'konzentriert'),
        day(1, 30, note: 'krank'),
        day(2, 0, note: 'krank, Fieber'),
        day(3, 60),
        day(4, 50, note: 'war beim Arzt'),
        day(5, 200),
      ]);
      expect(ins.plannedStudyDays, 6);
      expect(ins.missedDays.length, 4);
      expect(ins.daysWith('sick'), 2);
      expect(ins.missedReasons.first.category.id, 'sick');
      expect(ins.missedReasons.first.days, 2);
      expect(ins.missedWithoutNote, 1);
      expect(ins.missedWithoutNegativeTag, 1); // Arzttermin ist neutral
    });

    test('Kategorie-Wirkung auf die Lernzeit', () {
      final ins = DayInsights.compute([
        day(0, 60, note: 'müde'),
        day(1, 60, note: 'müde'),
        day(2, 240),
        day(3, 240),
      ]);
      final tired = ins.categories.firstWhere((c) => c.category.id == 'tired');
      expect(tired.days.length, 2);
      expect(tired.avgStudyWith, 60);
      expect(tired.avgStudyWithout, 240);
      expect(tired.studyDelta, closeTo(-0.75, 0.001));
    });

    test('bester und schwächster Tag ab genug Daten', () {
      final records = [
        for (var i = 0; i < 4; i++) day(i, 240, note: 'gut geschlafen'),
        for (var i = 4; i < 8; i++) day(i, 100),
        for (var i = 8; i < 12; i++) day(i, 20, note: 'schlechte Laune'),
      ];
      final ins = DayInsights.compute(records);
      expect(ins.bestDayCount, 3);
      expect(ins.bestDayTraits.first.category.id, 'rested');
      expect(ins.worstDayTraits.first.category.id, 'badMood');
    });

    test('zu wenige Tage: kein Vergleich', () {
      final ins = DayInsights.compute([day(0, 240), day(1, 0)]);
      expect(ins.bestDayTraits, isEmpty);
      expect(ins.worstDayTraits, isEmpty);
    });
  });
}
