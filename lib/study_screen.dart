import 'dart:async';
import 'package:flutter/material.dart';
import 'assignments_section.dart';
import 'models.dart';
import 'storage.dart';
import 'study_models.dart';
import 'study_session_sheet.dart';
import 'study_stats.dart';
import 'sync/sync_service.dart';
import 'theme.dart';

/// Lerntracker: Timer mit Start/Stopp, Wochen-/Monatsziele aus den als
/// "Lerneinheit" markierten Aufgaben, Durchschnitte, Verteilung nach Art der
/// Arbeit und Seitenziele pro Modul.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final _storage = ZenStorage();
  Timer? _ticker;

  List<StudySession> _sessions = [];
  List<StudyModule> _modules = [];
  List<TaskTemplate> _templates = [];
  DateTime? _runningStart;
  int _weekPlanned = 0;
  int _weekPlannedToDate = 0;
  int _monthPlanned = 0;
  int _monthPlannedToDate = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_runningStart != null && mounted) setState(() {});
    });
    SyncService.instance.revision.addListener(_onCloudChange);
  }

  @override
  void dispose() {
    SyncService.instance.revision.removeListener(_onCloudChange);
    _ticker?.cancel();
    super.dispose();
  }

  /// Ein anderes Gerät hat Lerndaten geändert (Timer gestartet/gestoppt, Einheit
  /// erfasst) – neu laden, damit der Timer hier mitläuft.
  void _onCloudChange() {
    final keys = SyncService.instance.lastChangedKeys;
    final relevant = keys.any((k) => k.startsWith('zenday_ssess_') || k.startsWith('zenday_study_') || k == 'zenday_assignments' || k == 'zenday_templates');
    if (relevant) _load();
  }

  Future<void> _load() async {
    final sessions = await _storage.loadStudySessions();
    final modules = await _storage.loadStudyModules();
    final templates = await _storage.loadTemplates();
    final running = await _storage.loadStudyRunningStart();

    final now = DateTime.now();
    final today = dayOf(now);
    final weekStart = weekStartOf(today);
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0);

    final weekPlanned = await StudyStats.plannedMinutes(_storage, templates, weekStart, weekEnd);
    final weekToDate = await StudyStats.plannedMinutes(_storage, templates, weekStart, today);
    final monthPlanned = await StudyStats.plannedMinutes(_storage, templates, monthStart, monthEnd);
    final monthToDate = await StudyStats.plannedMinutes(_storage, templates, monthStart, today);

    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _modules = modules;
      _templates = templates;
      _runningStart = running;
      _weekPlanned = weekPlanned;
      _weekPlannedToDate = weekToDate;
      _monthPlanned = monthPlanned;
      _monthPlannedToDate = monthToDate;
      _loaded = true;
    });
  }

  Future<void> _start() async {
    final now = DateTime.now();
    await _storage.saveStudyRunningStart(now);
    setState(() => _runningStart = now);
  }

  Future<void> _stop() async {
    final start = _runningStart;
    if (start == null) return;
    final seconds = DateTime.now().difference(start).inSeconds;
    final guess = await StudyStats.guessModuleId(_storage, _templates, _modules, start);
    if (!mounted) return;

    final session = await showStudySessionSheet(
      context,
      modules: _modules,
      guessedModuleId: guess,
      start: start,
      fixedSeconds: seconds < 1 ? 1 : seconds,
    );

    await _storage.saveStudyRunningStart(null);
    setState(() => _runningStart = null);
    if (session != null) {
      _sessions.add(session);
      await _storage.saveStudySessions(_sessions);
    }
    await _load();
  }

  Future<void> _addManual() async {
    final guess = await StudyStats.guessModuleId(_storage, _templates, _modules, DateTime.now());
    if (!mounted) return;
    final session = await showStudySessionSheet(context, modules: _modules, guessedModuleId: guess);
    if (session != null) {
      _sessions.add(session);
      await _storage.saveStudySessions(_sessions);
      await _load();
    }
  }

  Future<void> _deleteSession(StudySession s) async {
    setState(() => _sessions.remove(s));
    await _storage.saveStudySessions(_sessions);
    await _load();
  }

  Future<void> _editModule(StudyModule module) async {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;
    final nameC = TextEditingController(text: module.name);
    final totalC = TextEditingController(text: module.totalPages.toString());
    final offsetC = TextEditingController(text: module.pagesOffset.toString());
    DateTime? deadline = module.deadline;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: c.surface,
          title: Text('Modul bearbeiten', style: TextStyle(color: c.textPrimary, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField('Name', nameC, c, number: false),
                const SizedBox(height: 12),
                _dialogField('Seiten gesamt', totalC, c),
                const SizedBox(height: 12),
                _dialogField('Bereits geschafft (vor dem Tracking)', offsetC, c),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: deadline ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setDialog(() => deadline = picked);
                        },
                        child: Text(
                          deadline == null
                              ? 'Frist setzen (optional)'
                              : 'Frist: ${deadline!.day.toString().padLeft(2, '0')}.${deadline!.month.toString().padLeft(2, '0')}.${deadline!.year}',
                        ),
                      ),
                    ),
                    if (deadline != null)
                      IconButton(onPressed: () => setDialog(() => deadline = null), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
          ],
        ),
      ),
    );

    if (saved == true) {
      module.name = nameC.text.trim().isEmpty ? module.name : nameC.text.trim();
      module.totalPages = int.tryParse(totalC.text.trim()) ?? module.totalPages;
      module.pagesOffset = int.tryParse(offsetC.text.trim()) ?? module.pagesOffset;
      module.deadline = deadline;
      await _storage.saveStudyModules(_modules);
      setState(() {});
    }
    nameC.dispose();
    totalC.dispose();
    offsetC.dispose();
  }

  Widget _dialogField(String label, TextEditingController controller, ZenColors c, {bool number = true}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        title: Text('Lerntracker', style: TextStyle(color: c.textPrimary, fontSize: 17)),
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: _buildContent(c),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildContent(ZenColors c) {
    final now = DateTime.now();
    final today = dayOf(now);
    final weekStart = weekStartOf(today);
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0);

    final runningSeconds = _runningStart == null ? 0 : now.difference(_runningStart!).inSeconds;
    final todaySeconds = StudyStats.sumSeconds(_sessions, today, today) + runningSeconds;
    final weekSeconds = StudyStats.sumSeconds(_sessions, weekStart, weekEnd) + runningSeconds;
    final monthSeconds = StudyStats.sumSeconds(_sessions, monthStart, monthEnd) + runningSeconds;

    final totalSeconds = _sessions.fold<int>(0, (sum, s) => sum + s.seconds);
    final studyDays = StudyStats.distinctStudyDays(_sessions);
    final weeks = StudyStats.weeksSpanned(_sessions, now);
    final months = StudyStats.monthsSpanned(_sessions, now);
    final byActivity = StudyStats.secondsByActivity(_sessions);

    return [
      _timerCard(c, runningSeconds, todaySeconds),
      const SizedBox(height: 16),
      _goalCard(c, 'Diese Woche', weekSeconds, _weekPlanned, _weekPlannedToDate),
      const SizedBox(height: 12),
      _goalCard(c, 'Dieser Monat', monthSeconds, _monthPlanned, _monthPlannedToDate),
      const SizedBox(height: 20),
      _sectionTitle('Durchschnitt', c),
      Row(
        children: [
          Expanded(child: _avgTile('pro Lerntag', studyDays == 0 ? null : totalSeconds ~/ studyDays, c)),
          const SizedBox(width: 8),
          Expanded(child: _avgTile('pro Woche', _sessions.isEmpty ? null : totalSeconds ~/ weeks, c)),
          const SizedBox(width: 8),
          Expanded(child: _avgTile('pro Monat', _sessions.isEmpty ? null : totalSeconds ~/ months, c)),
        ],
      ),
      const SizedBox(height: 22),
      _sectionTitle('Wofür die Zeit draufging', c),
      ...StudyActivity.values.map((a) => _activityRow(c, studyActivityLabels[a]!, byActivity[a] ?? 0, totalSeconds)),
      const SizedBox(height: 22),
      _sectionTitle('Seitenziele', c),
      ..._modules.map((m) => _moduleCard(c, StudyStats.forModule(m, _sessions, now))),
      const SizedBox(height: 14),
      _sectionTitle('Pflichtaufgaben', c),
      AssignmentsSection(storage: _storage, modules: _modules, colors: c),
      const SizedBox(height: 14),
      _sectionTitle('Letzte Einheiten', c),
      ..._recentSessions(c),
    ];
  }

  Widget _timerCard(ZenColors c, int runningSeconds, int todaySeconds) {
    final running = _runningStart != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: running ? c.success : c.divider, width: running ? 1.5 : 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            fmtClock(runningSeconds),
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
              color: running ? c.textPrimary : c.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            running
                ? 'Läuft seit ${_runningStart!.hour.toString().padLeft(2, '0')}:${_runningStart!.minute.toString().padLeft(2, '0')}'
                : 'Heute gelernt: ${fmtHm(todaySeconds)}',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: running ? _stop : _start,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: running ? c.textPrimary : c.success,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                running ? 'Stopp' : 'Lernen starten',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: running ? c.background : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _addManual,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Manuell eintragen', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(ZenColors c, String title, int doneSeconds, int plannedMinutes, int plannedToDateMinutes) {
    final plannedSeconds = plannedMinutes * 60;
    final toDateSeconds = plannedToDateMinutes * 60;
    final progress = plannedSeconds == 0 ? 0.0 : (doneSeconds / plannedSeconds).clamp(0.0, 1.0);
    final missing = (plannedSeconds - doneSeconds).clamp(0, 1 << 30);
    final delta = doneSeconds - toDateSeconds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  plannedSeconds == 0 ? fmtHm(doneSeconds) : '${fmtHm(doneSeconds)} / ${fmtHm(plannedSeconds)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (plannedSeconds == 0)
            Text(
              'Noch keine geplante Lernzeit. Markiere Aufgaben (mit Start- und Endzeit) als "Lerneinheit", '
              'dann entsteht hier das Ziel.',
              style: TextStyle(fontSize: 12, height: 1.4, color: c.textTertiary),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: c.divider,
                valueColor: AlwaysStoppedAnimation(c.success),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Es fehlen noch ${fmtHm(missing)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    delta >= 0 ? '${fmtHm(delta)} über Plan' : '${fmtHm(-delta)} unter Plan',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: delta >= 0 ? c.success : Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ZenColors c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(fontSize: 13, color: c.textSecondary)),
      );

  Widget _avgTile(String label, int? seconds, ZenColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            seconds == null ? '–' : fmtHm(seconds),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: c.textTertiary)),
        ],
      ),
    );
  }

  Widget _activityRow(ZenColors c, String label, int seconds, int total) {
    final ratio = total == 0 ? 0.0 : seconds / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: c.textPrimary))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: c.divider,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(fmtHm(seconds),
                textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard(ZenColors c, ModuleStats s) {
    final m = s.module;
    final progress = m.totalPages == 0 ? 0.0 : (s.pagesDone / m.totalPages).clamp(0.0, 1.0);

    final lines = <String>[
      if (s.minutesPerPage != null) 'Ø ${s.minutesPerPage!.toStringAsFixed(1)} min pro Seite',
      if (s.pagesPerSession != null) 'Ø ${s.pagesPerSession!.toStringAsFixed(1)} Seiten pro Lerneinheit',
      if (s.exerciseSeconds > 0) 'Aufgaben: ${fmtHm(s.exerciseSeconds)}',
      if (s.mockExamSeconds > 0) 'Probeklausuren: ${fmtHm(s.mockExamSeconds)}',
      if (s.videoSeconds > 0) 'Lernvideos: ${fmtHm(s.videoSeconds)}',
    ];

    String? goalLine;
    if (m.deadline != null) {
      if (s.remaining == 0) {
        goalLine = 'Alle Seiten geschafft';
      } else if (s.daysLeft != null && s.daysLeft! <= 0) {
        goalLine = 'Frist erreicht – ${s.remaining} Seiten offen';
      } else if (s.neededPerDay != null) {
        goalLine =
            'Bis zur Frist (${s.daysLeft} Tage): ${s.neededPerDay!.toStringAsFixed(1)} Seiten/Tag · ${s.neededPerWeek!.toStringAsFixed(0)} Seiten/Woche';
      }
    }

    return GestureDetector(
      onTap: () => _editModule(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(m.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('${s.pagesDone} / ${m.totalPages} Seiten',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: c.divider,
                valueColor: AlwaysStoppedAnimation(c.success),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.remaining} Seiten offen · Lernzeit gesamt: ${fmtHm(s.totalSeconds)}',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            if (s.weekTarget != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text('Diese Woche',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${s.pagesThisWeek} von ${s.weekTarget} Seiten',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: s.pagesThisWeek >= s.weekTarget! ? c.success : c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.weekTarget == 0 ? 1.0 : (s.pagesThisWeek / s.weekTarget!).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: c.divider,
                  valueColor: AlwaysStoppedAnimation(c.success),
                ),
              ),
            ],
            if (s.estimatedRemainingHours != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Geschätzt noch ${s.estimatedRemainingHours!.toStringAsFixed(1)} h im bisherigen Tempo',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(line, style: TextStyle(fontSize: 12, color: c.textTertiary)),
              ),
            if (goalLine != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(goalLine,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
            if (m.deadline == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Tippen, um Frist und Seitenzahl anzupassen',
                    style: TextStyle(fontSize: 11, color: c.textTertiary)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _recentSessions(ZenColors c) {
    if (_sessions.isEmpty) {
      return [
        Text('Noch keine Lerneinheit aufgezeichnet.', style: TextStyle(fontSize: 13, color: c.textTertiary)),
      ];
    }
    final sorted = [..._sessions]..sort((a, b) => b.start.compareTo(a.start));
    return sorted.take(10).map((s) {
      final module = _modules.where((m) => m.id == s.moduleId).map((m) => m.name).firstOrNull ?? 'ohne Modul';
      final detail = s.activity == StudyActivity.pages && s.pages > 0
          ? '${s.pages} Seiten'
          : studyActivityLabels[s.activity]!;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$module · ${fmtHm(s.seconds)}', style: TextStyle(fontSize: 13, color: c.textPrimary)),
                  Text(
                    '${s.start.day.toString().padLeft(2, '0')}.${s.start.month.toString().padLeft(2, '0')}. · $detail${s.manual ? ' · manuell' : ''}',
                    style: TextStyle(fontSize: 11, color: c.textTertiary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _deleteSession(s),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 16, color: c.textTertiary),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
