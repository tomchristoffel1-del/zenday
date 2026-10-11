import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'day_insights.dart';
import 'day_notes.dart';
import 'models.dart';
import 'storage.dart';
import 'study_stats.dart';
import 'theme.dart';

final _negativeIds = noteCategories.where((c) => c.polarity == Polarity.negative).map((c) => c.id).toSet();

enum _Range { days30, year, all }

const _rangeLabels = {_Range.days30: '30 Tage', _Range.year: 'Dieses Jahr', _Range.all: 'Gesamt'};

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Baut für jeden Tag im Zeitraum einen [DayRecord] aus Lerneinheiten, Plan,
/// erledigten Aufgaben, Stimmung und Notiz.
Future<List<DayRecord>> loadDayRecords(ZenStorage storage, DateTime from, DateTime to) async {
  final templates = await storage.loadTemplates();
  final sessions = await storage.loadStudySessions();
  final notes = await storage.loadAllNotes();
  final today = dayOf(DateTime.now());

  final studySecondsByDay = <DateTime, int>{};
  for (final s in sessions) {
    final d = dayOf(s.start);
    studySecondsByDay[d] = (studySecondsByDay[d] ?? 0) + s.seconds;
  }

  final records = <DayRecord>[];
  for (var d = dayOf(from); !d.isAfter(dayOf(to)); d = nextDay(d)) {
    final adhoc = await storage.loadAdHoc(d);
    final done = await storage.loadTemplateDoneIds(d);
    final tracking = await storage.loadTracking(d);
    final applying = templates.where((t) => t.appliesOn(d)).toList();

    var planned = 0;
    for (final t in applying.where((t) => t.isStudy)) {
      planned += durationMinutes(t.startTime, t.endTime);
    }
    for (final a in adhoc.where((a) => a.isStudy)) {
      planned += durationMinutes(a.startTime, a.endTime);
    }

    final note = notes[_dayKey(d)];
    records.add(DayRecord(
      date: d,
      studyMinutes: ((studySecondsByDay[d] ?? 0) / 60).round(),
      // Der laufende Tag ist noch nicht vorbei und zählt nicht als "Ziel verfehlt".
      plannedStudyMinutes: d == today ? 0 : planned,
      tasksTotal: d == today ? 0 : applying.length + adhoc.length,
      tasksDone: d == today ? 0 : applying.where((t) => done.contains(t.id)).length + adhoc.where((a) => a.done).length,
      mood: tracking.mood,
      note: note,
    ));
  }
  return records;
}

/// Wertet die Tagesnotizen aus: welche Kategorien wie oft vorkamen, wie sich
/// Lernzeit und Aufgaben an solchen Tagen verändern, was die besten Lerntage
/// auszeichnet und woran verfehlte Lernziele lagen.
class DayInsightsScreen extends StatefulWidget {
  const DayInsightsScreen({super.key});

  @override
  State<DayInsightsScreen> createState() => _DayInsightsScreenState();
}

class _DayInsightsScreenState extends State<DayInsightsScreen> {
  final _storage = ZenStorage();
  _Range _range = _Range.days30;
  DayInsights? _insights;
  bool _showAllNotes = false;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<DateTime> _rangeStart(DateTime today) async {
    switch (_range) {
      case _Range.days30:
        return today.subtract(const Duration(days: 29));
      case _Range.year:
        return DateTime(today.year, 1, 1);
      case _Range.all:
        final dates = <DateTime>[
          ...(await _storage.loadAllNotes()).keys.map(DateTime.parse),
          ...(await _storage.loadStudySessions()).map((s) => dayOf(s.start)),
        ];
        if (dates.isEmpty) return today.subtract(const Duration(days: 29));
        return dates.reduce((a, b) => a.isBefore(b) ? a : b);
    }
  }

  Future<void> _compute() async {
    final today = dayOf(DateTime.now());
    final from = await _rangeStart(today);
    final records = await loadDayRecords(_storage, from, today);
    if (!mounted) return;
    setState(() => _insights = DayInsights.compute(records));
  }

  void _setRange(_Range r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _insights = null;
    });
    _compute();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;
    final ins = _insights;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        title: Text('Tagesanalyse', style: TextStyle(color: c.textPrimary, fontSize: 17)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _rangeSelector(c),
                const SizedBox(height: 16),
                if (ins == null)
                  const SizedBox.shrink()
                else ...[
                  _summary(ins, c),
                  const SizedBox(height: 20),
                  if (ins.noteDays.isEmpty)
                    _hint('Noch keine Notizen in diesem Zeitraum. Schreib im Tagesplan unter den Fragen '
                        'eine kurze Notiz zum Tag – daraus entsteht hier die Auswertung.', c)
                  else ...[
                    _missedGoalSection(ins, c),
                    _optimalDaySection(ins, c),
                    _categoriesSection(ins, c),
                    _notesSection(ins, c),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rangeSelector(ZenColors c) {
    return Wrap(
      spacing: 8,
      children: _Range.values.map((r) {
        final active = r == _range;
        return GestureDetector(
          onTap: () => _setRange(r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? c.textPrimary : Colors.transparent,
              border: Border.all(color: active ? c.textPrimary : c.divider),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_rangeLabels[r]!,
                style: TextStyle(fontSize: 13, color: active ? c.background : c.textSecondary)),
          ),
        );
      }).toList(),
    );
  }

  Widget _summary(DayInsights ins, ZenColors c) {
    Widget tile(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                FittedBox(
                  child: Text(value,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
                const SizedBox(height: 2),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: c.textTertiary)),
              ],
            ),
          ),
        );

    final avg = ins.avgStudyPerStudyDay;
    return Row(
      children: [
        tile('${ins.noteDays.length}', 'Tage mit Notiz'),
        const SizedBox(width: 8),
        tile('${ins.daysWith('sick')}', 'Krankheitstage'),
        const SizedBox(width: 8),
        tile(avg == null ? '–' : fmtHm((avg * 60).round()), 'Ø Lernzeit\npro Lerntag'),
      ],
    );
  }

  Widget _card(String title, String? subtitle, List<Widget> children, ZenColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textTertiary)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _hint(String text, ZenColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary)),
      );

  Widget _bar(String label, int count, int total, Color color, ZenColors c, {VoidCallback? onTap}) {
    final ratio = total == 0 ? 0.0 : count / total;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
                ),
                Text('$count ${count == 1 ? 'Tag' : 'Tage'}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: c.divider,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Lernziel verfehlt ----------

  Widget _missedGoalSection(DayInsights ins, ZenColors c) {
    if (ins.plannedStudyDays == 0) {
      return _card('Lernziel verfehlt – woran lag es?', null, [
        _hint('Keine Tage mit geplanter Lernzeit im Zeitraum. Markiere Lernblöcke im Plan als "Lerneinheit".', c),
      ], c);
    }
    final missed = ins.missedDays.length;
    if (missed == 0) {
      return _card('Lernziel verfehlt – woran lag es?', null, [
        _hint('An allen ${ins.plannedStudyDays} geplanten Lerntagen mindestens die Hälfte geschafft. Stark!', c),
      ], c);
    }

    final sick = ins.missedReasons.where((r) => r.category.id == 'sick').fold(0, (s, r) => s + r.days);
    final unexplained = ins.missedWithoutNote + ins.missedWithoutNegativeTag;
    final String verdict;
    if (sick / missed >= 0.4) {
      verdict = 'Vor allem Krankheit: $sick von $missed schwachen Tagen warst du krank.';
    } else if (unexplained / missed >= 0.5) {
      verdict = 'Die meisten schwachen Tage haben keinen erkennbaren Grund in den Notizen – '
          'eher eine Frage von Planung und Effizienz als von äußeren Umständen.';
    } else {
      final top = ins.missedReasons.first;
      verdict = 'Häufigster Grund: ${top.category.emoji} ${top.category.label} (${top.days} von $missed Tagen).';
    }

    return _card(
      'Lernziel verfehlt – woran lag es?',
      '$missed von ${ins.plannedStudyDays} geplanten Lerntagen unter 50 % der geplanten Lernzeit',
      [
        _hint(verdict, c),
        const SizedBox(height: 4),
        ...ins.missedReasons.map((r) => _bar('${r.category.emoji} ${r.category.label}', r.days, missed,
            Colors.redAccent.withValues(alpha: 0.8), c,
            onTap: () => _showDays(
                '${r.category.emoji} ${r.category.label} · Ziel verfehlt',
                ins.missedDays.where((d) => d.tags.contains(r.category.id)).toList(),
                c))),
        if (ins.missedWithoutNegativeTag > 0)
          _bar('Notiz ohne negativen Grund', ins.missedWithoutNegativeTag, missed, c.textTertiary, c,
              onTap: () => _showDays('Ziel verfehlt · Notiz ohne Grund',
                  ins.missedDays.where((d) => d.hasNote && !d.tags.any(_negativeIds.contains)).toList(), c)),
        if (ins.missedWithoutNote > 0)
          _bar('Ohne Notiz', ins.missedWithoutNote, missed, c.divider, c,
              onTap: () => _showDays('Ziel verfehlt · ohne Notiz',
                  ins.missedDays.where((d) => !d.hasNote).toList(), c)),
      ],
      c,
    );
  }

  // ---------- Optimaler Tag ----------

  Widget _optimalDaySection(DayInsights ins, ZenColors c) {
    final studyDays = ins.records.where((r) => r.isStudyDay).length;
    if (studyDays < DayInsights.minDaysForComparison) {
      return _card('Dein optimaler Tag', null, [
        _hint('Ab ${DayInsights.minDaysForComparison} Lerntagen mit Daten siehst du hier, was deine besten '
            'und schwächsten Lerntage voneinander unterscheidet (bisher $studyDays).', c),
      ], c);
    }

    String pct(double v) => '${(v * 100).round()} %';
    Widget shiftRow(TagShift s, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(s.category.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.category.label, style: TextStyle(fontSize: 13, color: c.textPrimary)),
              ),
              Text('${pct(s.shareInGroup)} statt ${pct(s.shareElsewhere)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        );

    return _card(
      'Dein optimaler Tag',
      'Verglichen werden deine ${ins.bestDayCount} besten und ${ins.bestDayCount} schwächsten Lerntage '
          '(nach erreichter Lernzeit) mit den übrigen.',
      [
        Text('An den besten Tagen häufiger',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.success)),
        const SizedBox(height: 4),
        if (ins.bestDayTraits.isEmpty)
          _hint('Noch kein klares Muster.', c)
        else
          ...ins.bestDayTraits.map((s) => shiftRow(s, c.success)),
        const SizedBox(height: 12),
        const Text('An den schwächsten Tagen häufiger',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent)),
        const SizedBox(height: 4),
        if (ins.worstDayTraits.isEmpty)
          _hint('Noch kein klares Muster.', c)
        else
          ...ins.worstDayTraits.map((s) => shiftRow(s, Colors.redAccent)),
      ],
      c,
    );
  }

  // ---------- Kategorien ----------

  Widget _categoriesSection(DayInsights ins, ZenColors c) {
    return _card(
      'Kategorien',
      'Wie oft kam was vor – und wie viel du an solchen Tagen gelernt hast. Tippen für die Tage.',
      ins.categories.map((imp) => _categoryRow(imp, c)).toList(),
      c,
    );
  }

  Widget _categoryRow(CategoryImpact imp, ZenColors c) {
    final cat = imp.category;
    final details = <String>[];
    if (imp.avgStudyWith != null) {
      final delta = imp.studyDelta;
      final deltaText = delta == null || delta.abs() < 0.05
          ? ''
          : ' (${delta > 0 ? '+' : '−'}${(delta.abs() * 100).round()} %)';
      details.add('Ø ${fmtHm((imp.avgStudyWith! * 60).round())} Lernen$deltaText');
    }
    if (imp.taskRateWith != null) details.add('${(imp.taskRateWith! * 100).round()} % Aufgaben');
    final delta = imp.studyDelta;
    final deltaColor = delta == null || delta.abs() < 0.05
        ? c.textTertiary
        : (delta > 0 ? c.success : Colors.redAccent);

    return GestureDetector(
      onTap: () => _showDays('${cat.emoji} ${cat.label}', imp.days, c),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.label, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                  if (details.isNotEmpty)
                    Text(details.join(' · '), style: TextStyle(fontSize: 11, color: deltaColor)),
                ],
              ),
            ),
            Text('${imp.days.length}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }

  // ---------- Notizen ----------

  Widget _notesSection(DayInsights ins, ZenColors c) {
    final notes = [...ins.noteDays]..sort((a, b) => b.date.compareTo(a.date));
    final visible = _showAllNotes ? notes : notes.take(7).toList();
    return _card('Notizen', null, [
      ...visible.map((r) => _noteTile(r, c)),
      if (notes.length > visible.length)
        TextButton(
          onPressed: () => setState(() => _showAllNotes = true),
          child: Text('Alle ${notes.length} Notizen anzeigen'),
        ),
    ], c);
  }

  Widget _noteTile(DayRecord r, ZenColors c) {
    final tags = r.tags.map((id) => noteCategoryById[id]).whereType<NoteCategory>().map((t) => t.emoji).join(' ');
    final meta = <String>[
      DateFormat('EE, d. MMM', 'de_DE').format(r.date),
      if (r.studyMinutes > 0) fmtHm(r.studyMinutes * 60),
      if (r.mood != null) const {Mood.low: '😞', Mood.mid: '😐', Mood.high: '😊'}[r.mood]!,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(meta.join(' · '), style: TextStyle(fontSize: 11, color: c.textTertiary)),
              ),
              Text(tags, style: const TextStyle(fontSize: 12)),
            ],
          ),
          if (r.note!.text.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(r.note!.text.trim(), style: TextStyle(fontSize: 13, color: c.textPrimary)),
          ],
        ],
      ),
    );
  }

  void _showDays(String title, List<DayRecord> days, ZenColors c) {
    final sorted = [...days]..sort((a, b) => b.date.compareTo(a.date));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text('$title · ${sorted.length} ${sorted.length == 1 ? 'Tag' : 'Tage'}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
            const SizedBox(height: 10),
            ...sorted.map((r) => r.hasNote
                ? _noteTile(r, c)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${DateFormat('EE, d. MMM', 'de_DE').format(r.date)} · '
                      '${fmtHm(r.studyMinutes * 60)} von ${fmtHm(r.plannedStudyMinutes * 60)} gelernt',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
