import 'package:flutter/material.dart';
import 'study_models.dart';
import 'study_stats.dart';
import 'theme.dart';

/// Formular für eine Lerneinheit. Mit [fixedSeconds] (Timer-Ende) wird die
/// Dauer nur angezeigt; ohne [fixedSeconds] (manueller Eintrag) werden Datum
/// und Minuten abgefragt. Liefert die fertige Session oder null bei "Verwerfen".
Future<StudySession?> showStudySessionSheet(
  BuildContext context, {
  required List<StudyModule> modules,
  required String? guessedModuleId,
  DateTime? start,
  int? fixedSeconds,
}) {
  final c = Theme.of(context).extension<ZenTheme>()!.colors;
  return showModalBottomSheet<StudySession?>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: _SessionForm(
          modules: modules,
          guessedModuleId: guessedModuleId,
          start: start ?? DateTime.now(),
          fixedSeconds: fixedSeconds,
        ),
      ),
    ),
  );
}

class _SessionForm extends StatefulWidget {
  final List<StudyModule> modules;
  final String? guessedModuleId;
  final DateTime start;
  final int? fixedSeconds;

  const _SessionForm({
    required this.modules,
    required this.guessedModuleId,
    required this.start,
    required this.fixedSeconds,
  });

  @override
  State<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<_SessionForm> {
  late String? _moduleId = widget.guessedModuleId;
  StudyActivity _activity = StudyActivity.pages;
  late DateTime _date = widget.start;
  final _pagesController = TextEditingController();
  final _minutesController = TextEditingController(text: '120');

  bool get _manual => widget.fixedSeconds == null;

  @override
  void dispose() {
    _pagesController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final pages = _activity == StudyActivity.pages ? (int.tryParse(_pagesController.text.trim()) ?? 0) : 0;
    final seconds = _manual ? (int.tryParse(_minutesController.text.trim()) ?? 0) * 60 : widget.fixedSeconds!;
    if (seconds <= 0) return;
    final start = _manual ? DateTime(_date.year, _date.month, _date.day, 12) : widget.start;
    Navigator.pop(
      context,
      StudySession(
        start: start,
        seconds: seconds,
        moduleId: _moduleId,
        activity: _activity,
        pages: pages,
        manual: _manual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _manual ? 'Lerneinheit eintragen' : 'Lerneinheit beendet · ${fmtHm(widget.fixedSeconds!)}',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.textPrimary),
        ),
        const SizedBox(height: 18),
        if (_manual) ...[
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: c.textPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixText: 'Min.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Text(
          _moduleId != null && widget.guessedModuleId == _moduleId ? 'Modul (erkannt – bitte bestätigen)' : 'Modul',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.modules
              .map((m) => _chip(m.name, _moduleId == m.id, () => setState(() => _moduleId = m.id), c))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('Woran gearbeitet?', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: StudyActivity.values
              .map((a) => _chip(studyActivityLabels[a]!, _activity == a, () => setState(() => _activity = a), c))
              .toList(),
        ),
        if (_activity == StudyActivity.pages) ...[
          const SizedBox(height: 18),
          Text('Wie viele Seiten geschafft?', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _pagesController,
              keyboardType: TextInputType.number,
              autofocus: !_manual,
              style: TextStyle(fontSize: 14, color: c.textPrimary),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '0'),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, null),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(10)),
                  child: Text(_manual ? 'Abbrechen' : 'Verwerfen',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: c.textSecondary)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                  child: Text('Speichern',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.background, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, ZenColors c) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          border: Border.all(color: selected ? c.accent : c.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? c.background : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
