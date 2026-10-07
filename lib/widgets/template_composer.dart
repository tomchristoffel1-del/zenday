import 'package:flutter/material.dart';
import '../app_categories.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';
import 'repeat_selector.dart';

/// Formular zum Anlegen einer wiederkehrenden Aufgabe: Titel, Wiederholung,
/// optionale Uhrzeit. Wird in Onboarding und Plan-Verwaltung wiederverwendet.
class TemplateComposer extends StatefulWidget {
  final ZenColors colors;
  final ValueChanged<TaskTemplate> onAdd;

  const TemplateComposer({super.key, required this.colors, required this.onAdd});

  @override
  State<TemplateComposer> createState() => _TemplateComposerState();
}

class _TemplateComposerState extends State<TemplateComposer> {
  final _titleController = TextEditingController();
  Repeat _repeat = Repeat.daily;
  Set<int> _customDays = {};
  bool _useTime = false;
  TimeOfDay? _start;
  TimeOfDay? _end;
  final _storage = ZenStorage();
  List<BlockList> _blockLists = [];
  String? _linkedListId;
  bool _isStudy = false;
  Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _storage.loadBlockLists().then((lists) {
      if (mounted) setState(() => _blockLists = lists);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (_repeat == Repeat.custom && _customDays.isEmpty) return;

    var linkedListId = _linkedListId;
    if (_useTime && _selectedCategories.isNotEmpty) {
      final processes = <String>{};
      final websites = <String>{};
      for (final cat in appCategories) {
        if (_selectedCategories.contains(cat.name)) {
          processes.addAll(cat.processes);
          websites.addAll(cat.websites);
        }
      }
      final newList = BlockList(
        name: '$title · ${_selectedCategories.join(', ')}',
        processes: processes.toList(),
        websites: websites.toList(),
      );
      final lists = await _storage.loadBlockLists();
      lists.add(newList);
      await _storage.saveBlockLists(lists);
      linkedListId = newList.id;
    }

    widget.onAdd(TaskTemplate(
      title: title,
      repeat: _repeat,
      customDays: _customDays,
      startTime: _useTime && _start != null ? _fmt(_start!) : null,
      endTime: _useTime && _end != null ? _fmt(_end!) : null,
      linkedListId: _useTime ? linkedListId : null,
      isStudy: _isStudy,
    ));
    if (!mounted) return;
    final refreshedLists = await _storage.loadBlockLists();
    setState(() {
      _titleController.clear();
      _repeat = Repeat.daily;
      _customDays = {};
      _useTime = false;
      _start = null;
      _end = null;
      _linkedListId = null;
      _isStudy = false;
      _selectedCategories = {};
      _blockLists = refreshedLists;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(fontSize: 16, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'z. B. Sport, Arbeit, Lesen…',
            hintStyle: TextStyle(color: c.textTertiary),
            border: InputBorder.none,
            isCollapsed: true,
          ),
        ),
        const SizedBox(height: 14),
        RepeatSelector(
          repeat: _repeat,
          customDays: _customDays,
          colors: c,
          onRepeatChanged: (r) => setState(() => _repeat = r),
          onCustomDaysChanged: (d) => setState(() => _customDays = d),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _useTime = !_useTime),
          child: Row(
            children: [
              Icon(
                _useTime ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: 8),
              Text('Uhrzeit festlegen', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _isStudy = !_isStudy),
          child: Row(
            children: [
              Icon(_isStudy ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: c.textSecondary),
              const SizedBox(width: 8),
              Text('Lerneinheit', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ],
          ),
        ),
        if (_useTime) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _timeButton('Start', _start, () => _pickTime(true), c),
              const SizedBox(width: 10),
              _timeButton('Ende', _end, () => _pickTime(false), c),
            ],
          ),
          const SizedBox(height: 14),
          Text('Während dieser Zeit blockieren', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: appCategories.map((cat) {
              final selected = _selectedCategories.contains(cat.name);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedCategories.remove(cat.name);
                  } else {
                    _selectedCategories.add(cat.name);
                    _linkedListId = null;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? c.accent : Colors.transparent,
                    border: Border.all(color: selected ? c.accent : c.divider),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? c.background : c.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_blockLists.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: c.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _linkedListId,
                  hint: Text('…oder eigene Liste wählen', style: TextStyle(fontSize: 13, color: c.textTertiary)),
                  dropdownColor: c.surface,
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Keine', style: TextStyle(color: c.textSecondary))),
                    ..._blockLists.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))),
                  ],
                  onChanged: (v) => setState(() {
                    _linkedListId = v;
                    if (v != null) _selectedCategories = {};
                  }),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _submit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Hinzufügen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.background,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeButton(String label, TimeOfDay? value, VoidCallback onTap, ZenColors c) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: c.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value != null ? _fmt(value) : label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: value != null ? c.textPrimary : c.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
