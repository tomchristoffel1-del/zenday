import 'package:flutter/material.dart';
import 'block_lists_screen.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';

/// Gemeinsames Formular zum Bearbeiten von Titel, Uhrzeit und verknüpfter
/// Blockliste – für Templates (mit "nur heute"/"für alle Tage"-Wahl) und
/// für Ad-hoc-Aufgaben (direkt, da ohnehin nur ein Tag betroffen ist).
class _EditForm extends StatefulWidget {
  final String initialTitle;
  final String? initialStart;
  final String? initialEnd;
  final String? initialListId;
  final ZenStorage storage;

  const _EditForm({
    super.key,
    required this.initialTitle,
    required this.initialStart,
    required this.initialEnd,
    required this.initialListId,
    required this.storage,
  });

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  late final _titleController = TextEditingController(text: widget.initialTitle);
  TimeOfDay? _start;
  TimeOfDay? _end;
  String? _linkedListId;
  List<BlockList> _blockLists = [];

  @override
  void initState() {
    super.initState();
    _start = _parse(widget.initialStart);
    _end = _parse(widget.initialEnd);
    _linkedListId = widget.initialListId;
    widget.storage.loadBlockLists().then((lists) {
      if (mounted) setState(() => _blockLists = lists);
    });
  }

  TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.textPrimary),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        const SizedBox(height: 18),
        Text('Uhrzeit', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _timeButton('Start', _start, () => _pickTime(true), c)),
            const SizedBox(width: 10),
            Expanded(child: _timeButton('Ende', _end, () => _pickTime(false), c)),
          ],
        ),
        const SizedBox(height: 18),
        Text('Blockliste während dieser Zeit', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _linkedListId,
              hint: Text('Keine', style: TextStyle(fontSize: 13, color: c.textTertiary)),
              dropdownColor: c.surface,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
              items: [
                DropdownMenuItem(value: null, child: Text('Keine', style: TextStyle(color: c.textSecondary))),
                ..._blockLists.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))),
              ],
              onChanged: (v) => setState(() => _linkedListId = v),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockListsScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Blocklisten verwalten →', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ),
        ),
      ],
    );
  }

  Widget _timeButton(String label, TimeOfDay? value, VoidCallback onTap, ZenColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
        child: Text(
          value != null ? _fmt(value) : label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: value != null ? c.textPrimary : c.textTertiary),
        ),
      ),
    );
  }

  ({String title, String? start, String? end, String? listId}) result() => (
        title: _titleController.text.trim(),
        start: _start != null ? _fmt(_start!) : null,
        end: _end != null ? _fmt(_end!) : null,
        listId: _linkedListId,
      );
}

Future<void> showTemplateEditSheet(
  BuildContext context, {
  required TaskTemplate template,
  required DateTime selectedDate,
  required ZenStorage storage,
  required List<TaskTemplate> allTemplates,
  required VoidCallback onTemplatesChanged,
  required VoidCallback onDayChanged,
}) async {
  final c = Theme.of(context).extension<ZenTheme>()!.colors;
  final formKey = GlobalKey<_EditFormState>();

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditForm(
                key: formKey,
                initialTitle: template.title,
                initialStart: template.startTime,
                initialEnd: template.endTime,
                initialListId: template.linkedListId,
                storage: storage,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  width: double.infinity,
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                  child: Text('Speichern',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.background, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (saved != true || !context.mounted) return;
  final r = formKey.currentState!.result();
  if (r.title.isEmpty) return;

  if (!context.mounted) return;
  final scope = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      title: Text('Änderung übernehmen', style: TextStyle(color: c.textPrimary, fontSize: 16)),
      content: Text('Nur für heute ändern, oder für alle Tage?',
          style: TextStyle(color: c.textSecondary, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'today'), child: const Text('Nur heute')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'all'), child: const Text('Für alle Tage')),
      ],
    ),
  );
  if (scope == null) return;

  if (scope == 'all') {
    template.title = r.title;
    template.startTime = r.start;
    template.endTime = r.end;
    template.linkedListId = r.listId;
    await storage.saveTemplates(allTemplates);
    onTemplatesChanged();
  } else {
    template.excludedDates.add(_fmtDate(selectedDate));
    await storage.saveTemplates(allTemplates);
    onTemplatesChanged();

    final adhoc = await storage.loadAdHoc(selectedDate);
    adhoc.add(AdHocTask(
      title: r.title,
      startTime: r.start,
      endTime: r.end,
      linkedListId: r.listId,
    ));
    await storage.saveAdHoc(selectedDate, adhoc);
    onDayChanged();
  }
}

Future<void> showAdHocEditSheet(
  BuildContext context, {
  required AdHocTask task,
  required DateTime selectedDate,
  required ZenStorage storage,
  required List<AdHocTask> allAdHoc,
  required VoidCallback onChanged,
}) async {
  final c = Theme.of(context).extension<ZenTheme>()!.colors;
  final formKey = GlobalKey<_EditFormState>();

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditForm(
                key: formKey,
                initialTitle: task.title,
                initialStart: task.startTime,
                initialEnd: task.endTime,
                initialListId: task.linkedListId,
                storage: storage,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  width: double.infinity,
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                  child: Text('Speichern',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.background, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (saved != true) return;
  final r = formKey.currentState!.result();
  if (r.title.isEmpty) return;

  task.title = r.title;
  task.startTime = r.start;
  task.endTime = r.end;
  task.linkedListId = r.listId;
  await storage.saveAdHoc(selectedDate, allAdHoc);
  onChanged();
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
