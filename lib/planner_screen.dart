import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_settings.dart';
import 'focus_engine.dart';
import 'focus_guard.dart';
import 'focus_screen.dart';
import 'income_screen.dart';
import 'manage_templates_screen.dart';
import 'models.dart';
import 'notifications.dart';
import 'platform_info.dart';
import 'rewards.dart';
import 'rewards_screen.dart';
import 'storage.dart';
import 'study_screen.dart';
import 'sync/sync_service.dart';
import 'sync_screen.dart';
import 'task_edit_sheet.dart';
import 'theme.dart';
import 'tracking_stats_screen.dart';
import 'usage_guard.dart';
import 'widgets/task_row.dart';
import 'widgets/tracking_row.dart';

const _weekdayShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Der Wochenplaner: Wochentags-Leiste oben, darunter der Plan für den
/// gewählten Tag (Grundplan-Aufgaben + eigene Einträge), unten eine
/// schlichte Eingabe für neue Aufgaben.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _storage = ZenStorage();
  final _focusGuard = FocusGuard();
  late final _usageGuard = UsageGuard(_storage);
  final _newTaskController = TextEditingController();
  final Map<String, TextEditingController> _adhocControllers = {};

  DateTime _selectedDate = _atMidnight(DateTime.now());
  List<TaskTemplate> _templates = [];
  List<AdHocTask> _adhoc = [];
  Set<String> _templateDone = {};
  List<String> _order = [];
  bool _loaded = false;
  int _points = 0;
  DailyTracking _tracking = DailyTracking();

  Timer? _reminderTimer;
  final Set<String> _notifiedToday = {};
  bool _studyRunning = false;

  @override
  void initState() {
    super.initState();
    _loadDay();
    _loadTemplates();
    _loadPoints();
    _loadStudyRunning();
    _focusGuard.start(() => FocusEngine.computeEffective(_storage).then((a) => a.merged));
    _usageGuard.start();
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());
    SyncService.instance.revision.addListener(_onCloudChange);
  }

  @override
  void dispose() {
    SyncService.instance.revision.removeListener(_onCloudChange);
    _focusGuard.stop();
    _usageGuard.stop();
    _reminderTimer?.cancel();
    _newTaskController.dispose();
    for (final c in _adhocControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final t = await _storage.loadTemplates();
    if (!mounted) return;
    setState(() => _templates = t);
  }

  Future<void> _loadPoints() async {
    final p = await _storage.loadPoints();
    if (!mounted) return;
    setState(() => _points = p);
  }

  Future<void> _loadStudyRunning() async {
    final running = await _storage.loadStudyRunningStart() != null;
    if (!mounted) return;
    setState(() => _studyRunning = running);
  }

  /// Daten kamen aus der Cloud (anderes Gerät): betroffene Teile neu laden.
  void _onCloudChange() {
    final keys = SyncService.instance.lastChangedKeys;
    final day = _selectedDate;
    final dayKeys = {
      'zenday_adhoc_${_dayString(day)}',
      'zenday_tpldone_${_dayString(day)}',
      'zenday_order_${_dayString(day)}',
      'zenday_tracking_${_dayString(day)}',
    };
    if (keys.any(dayKeys.contains)) _loadDay();
    if (keys.contains('zenday_templates')) _loadTemplates();
    if (keys.contains('zenday_focus_points')) _loadPoints();
    if (keys.contains('zenday_study_running_start')) _loadStudyRunning();
  }

  static String _dayString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _moreMenu(ZenColors colors) {
    final darkUnlocked = _points >= AppSettings.darkModeUnlockPoints;
    final isDark = AppSettings.themeMode.value == ThemeMode.dark;

    PopupMenuItem<String> item(String value, IconData icon, String label, {bool dim = false}) {
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: dim ? colors.textTertiary : colors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: dim ? colors.textTertiary : colors.textPrimary)),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Mehr',
      color: colors.surface,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: 22, color: colors.textSecondary),
      onSelected: (value) {
        switch (value) {
          case 'plan':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ManageTemplatesScreen(onChanged: _loadTemplates)),
            );
          case 'focus':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
          case 'sync':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()));
          case 'theme':
            _toggleTheme();
        }
      },
      itemBuilder: (_) => [
        item('plan', Icons.tune, 'Grundplan bearbeiten'),
        if (isWindowsDesktop) item('focus', Icons.shield_outlined, 'Fokus-Modus'),
        item('sync', Icons.cloud_sync_outlined, 'Synchronisierung'),
        item(
          'theme',
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          isDark ? 'Helles Design' : (darkUnlocked ? 'Dunkles Design' : 'Dunkles Design (ab ${AppSettings.darkModeUnlockPoints} Punkten)'),
          dim: !darkUnlocked && !isDark,
        ),
      ],
    );
  }

  void _changePoints(int delta) {
    final before = _points;
    final after = (before + delta).clamp(0, 1 << 30);
    setState(() => _points = after);
    _storage.savePoints(after);
    if (delta > 0) {
      final milestone = milestoneJustCrossed(before, after);
      if (milestone != null) {
        NotificationService.show(milestone.title, milestone.message);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${milestone.title} · ${milestone.message}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadDay() async {
    final adhoc = await _storage.loadAdHoc(_selectedDate);
    final done = await _storage.loadTemplateDoneIds(_selectedDate);
    final order = await _storage.loadOrder(_selectedDate);
    final tracking = await _storage.loadTracking(_selectedDate);
    for (final c in _adhocControllers.values) {
      c.dispose();
    }
    _adhocControllers.clear();
    for (final task in adhoc) {
      _adhocControllers[task.id] = TextEditingController(text: task.title);
    }
    setState(() {
      _adhoc = adhoc;
      _templateDone = done;
      _order = order;
      _tracking = tracking;
      _loaded = true;
    });
  }

  void _toggleVegetables() {
    setState(() => _tracking.vegetables = !_tracking.vegetables);
    _storage.saveTracking(_selectedDate, _tracking);
  }

  void _toggleSugarFree() {
    setState(() => _tracking.sugarFree = !_tracking.sugarFree);
    _storage.saveTracking(_selectedDate, _tracking);
  }

  void _setMood(Mood? mood) {
    setState(() => _tracking.mood = mood);
    _storage.saveTracking(_selectedDate, _tracking);
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _atMidnight(date);
      _loaded = false;
    });
    _loadDay();
  }

  List<PlanItem> _buildItems() {
    final items = <PlanItem>[
      for (final t in _templates.where((t) => t.appliesOn(_selectedDate)))
        PlanItem(
          id: t.id,
          title: t.title,
          startTime: t.startTime,
          endTime: t.endTime,
          isTemplate: true,
          editable: false,
          done: _templateDone.contains(t.id),
        ),
      for (final a in _adhoc)
        PlanItem(
          id: a.id,
          title: a.title,
          startTime: a.startTime,
          endTime: a.endTime,
          isTemplate: false,
          editable: true,
          done: a.done,
        ),
    ];
    if (_order.isNotEmpty) {
      final orderIndex = {for (var i = 0; i < _order.length; i++) _order[i]: i};
      items.sort((a, b) {
        final ai = orderIndex[a.id];
        final bi = orderIndex[b.id];
        if (ai != null && bi != null) return ai.compareTo(bi);
        if (ai != null) return -1;
        if (bi != null) return 1;
        return _byTime(a, b);
      });
    } else {
      items.sort(_byTime);
    }
    return items;
  }

  int _byTime(PlanItem a, PlanItem b) {
    if (a.startTime == null && b.startTime == null) return 0;
    if (a.startTime == null) return 1;
    if (b.startTime == null) return -1;
    return a.startTime!.compareTo(b.startTime!);
  }

  void _onReorder(int oldIndex, int newIndex) {
    final items = _buildItems();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    final newOrder = items.map((i) => i.id).toList();
    setState(() => _order = newOrder);
    _storage.saveOrder(_selectedDate, newOrder);
  }

  void _toggleTemplate(String id) {
    final wasDone = _templateDone.contains(id);
    setState(() {
      if (wasDone) {
        _templateDone.remove(id);
      } else {
        _templateDone.add(id);
      }
    });
    _storage.saveTemplateDoneIds(_selectedDate, _templateDone);
    _changePoints(wasDone ? -1 : 1);
  }

  void _toggleAdhoc(String id) {
    final task = _adhoc.firstWhere((a) => a.id == id);
    final wasDone = task.done;
    setState(() => task.done = !wasDone);
    _storage.saveAdHoc(_selectedDate, _adhoc);
    _changePoints(wasDone ? -1 : 1);
  }

  void _addTask() {
    final title = _newTaskController.text.trim();
    if (title.isEmpty) return;
    final task = AdHocTask(title: title);
    _adhocControllers[task.id] = TextEditingController(text: task.title);
    setState(() {
      _adhoc.add(task);
      _newTaskController.clear();
    });
    _storage.saveAdHoc(_selectedDate, _adhoc);
  }

  void _updateAdhocTitle(String id, String title) {
    final task = _adhoc.firstWhere((a) => a.id == id);
    task.title = title;
    _storage.saveAdHoc(_selectedDate, _adhoc);
  }

  void _deleteAdhoc(String id) {
    setState(() => _adhoc.removeWhere((a) => a.id == id));
    _adhocControllers.remove(id)?.dispose();
    _storage.saveAdHoc(_selectedDate, _adhoc);
  }

  Future<void> _editTemplate(String id) async {
    final template = _templates.firstWhere((t) => t.id == id);
    await showTemplateEditSheet(
      context,
      template: template,
      selectedDate: _selectedDate,
      storage: _storage,
      allTemplates: _templates,
      onTemplatesChanged: () => setState(() {}),
      onDayChanged: _loadDay,
    );
  }

  Future<void> _editAdhoc(String id) async {
    final task = _adhoc.firstWhere((a) => a.id == id);
    await showAdHocEditSheet(
      context,
      task: task,
      selectedDate: _selectedDate,
      storage: _storage,
      allAdHoc: _adhoc,
      onChanged: () {
        _adhocControllers[task.id]?.text = task.title;
        setState(() {});
      },
    );
  }

  void _toggleTheme() {
    if (_points < AppSettings.darkModeUnlockPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Noch ${AppSettings.darkModeUnlockPoints - _points} Punkt(e) bis Dark Mode',
          ),
        ),
      );
      return;
    }
    AppSettings.toggle(_storage);
  }

  void _checkReminders() {
    if (_atMidnight(DateTime.now()) != _selectedDate) return;
    final now = DateTime.now();
    final hhmm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    for (final item in _buildItems()) {
      if (item.startTime == hhmm && !item.done && !_notifiedToday.contains(item.id)) {
        _notifiedToday.add(item.id);
        NotificationService.show('ZenDay', item.title);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;
    final dateLabel = DateFormat('EEEE, d. MMMM', 'de_DE').format(_selectedDate);
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          dateLabel[0].toUpperCase() + dateLabel.substring(1),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RewardsScreen(points: _points)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt, size: 15, color: colors.success),
                                const SizedBox(width: 3),
                                Text(
                                  '$_points',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StudyScreen()),
                              );
                              _loadStudyRunning();
                            },
                            child: Icon(
                              Icons.school_outlined,
                              size: 19,
                              color: _studyRunning ? colors.success : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const IncomeScreen()),
                            ),
                            child: Icon(Icons.payments_outlined, size: 19, color: colors.textSecondary),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TrackingStatsScreen()),
                            ),
                            child: Icon(Icons.bar_chart, size: 19, color: colors.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          _moreMenu(colors),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: List.generate(7, (i) {
                      final day = monday.add(Duration(days: i));
                      final isSelected = _atMidnight(day) == _selectedDate;
                      final isToday = _atMidnight(day) == _atMidnight(DateTime.now());
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(day),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? colors.textPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isToday && !isSelected
                                    ? Border.all(color: colors.textTertiary)
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _weekdayShort[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? colors.background : colors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? colors.background : colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: TrackingRow(
                    tracking: _tracking,
                    colors: colors,
                    onToggleVegetables: _toggleVegetables,
                    onToggleSugarFree: _toggleSugarFree,
                    onMoodChanged: _setMood,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: colors.divider, height: 28),
                ),
                Expanded(
                  child: Builder(builder: (context) {
                    if (!_loaded) return const SizedBox.shrink();
                    final items = _buildItems();
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'Noch nichts geplant für heute.',
                          style: TextStyle(fontSize: 14, color: colors.textTertiary),
                        ),
                      );
                    }
                    return ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      buildDefaultDragHandles: false,
                      itemCount: items.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ReorderableDragStartListener(
                          key: ValueKey(item.id),
                          index: index,
                          child: TaskRow(
                            title: item.title,
                            startTime: item.startTime,
                            done: item.done,
                            colors: colors,
                            onToggle: () => item.isTemplate
                                ? _toggleTemplate(item.id)
                                : _toggleAdhoc(item.id),
                            editController: item.editable ? _adhocControllers[item.id] : null,
                            onTitleChanged:
                                item.editable ? (v) => _updateAdhocTitle(item.id, v) : null,
                            onDelete: item.editable ? () => _deleteAdhoc(item.id) : null,
                            onEdit: () => item.isTemplate
                                ? _editTemplate(item.id)
                                : _editAdhoc(item.id),
                          ),
                        );
                      },
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                          child: Icon(Icons.add, size: 16, color: colors.background),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _newTaskController,
                            onSubmitted: (_) => _addTask(),
                            style: TextStyle(fontSize: 15, color: colors.textPrimary),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: 'Neue Aufgabe hinzufügen',
                              hintStyle: TextStyle(color: colors.textTertiary),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _addTask,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            child: Text(
                              'Hinzufügen',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
