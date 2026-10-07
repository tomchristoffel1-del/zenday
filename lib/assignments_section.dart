import 'package:flutter/material.dart';
import 'storage.dart';
import 'study_models.dart';
import 'theme.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _fmtPoints(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Die Pflichtaufgaben pro Modul mit Frist, Punkten und Zulassungsstatus.
/// Zulassung: mindestens eine Aufgabe des Moduls mit mindestens halber Punktzahl.
class AssignmentsSection extends StatefulWidget {
  final ZenStorage storage;
  final List<StudyModule> modules;
  final ZenColors colors;

  const AssignmentsSection({super.key, required this.storage, required this.modules, required this.colors});

  @override
  State<AssignmentsSection> createState() => _AssignmentsSectionState();
}

class _AssignmentsSectionState extends State<AssignmentsSection> {
  List<Assignment> _assignments = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.storage.loadAssignments().then((list) {
      if (!mounted) return;
      setState(() {
        _assignments = list;
        _loaded = true;
      });
    });
  }

  Future<void> _edit(Assignment a) async {
    final c = widget.colors;
    final titleC = TextEditingController(text: a.title);
    final maxC = TextEditingController(text: a.maxPoints == null ? '' : _fmtPoints(a.maxPoints!));
    final pointsC = TextEditingController(text: a.points == null ? '' : _fmtPoints(a.points!));
    DateTime? deadline = a.deadline;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: c.surface,
          title: Text('Pflichtaufgabe', style: TextStyle(color: c.textPrimary, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleC,
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Titel', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                            labelText: 'Max. Punkte', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pointsC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                            labelText: 'Erreicht', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: deadline ?? DateTime.now().add(const Duration(days: 14)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setDialog(() => deadline = picked);
                        },
                        child: Text(deadline == null ? 'Abgabefrist (optional)' : 'Frist: ${_fmtDate(deadline!)}'),
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
      double? parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
      a.title = titleC.text.trim().isEmpty ? a.title : titleC.text.trim();
      a.maxPoints = parse(maxC.text);
      a.points = parse(pointsC.text);
      a.deadline = deadline;
      await widget.storage.saveAssignments(_assignments);
      setState(() {});
    }
    titleC.dispose();
    maxC.dispose();
    pointsC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final c = widget.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.modules.map((m) {
        final mine = _assignments.where((a) => a.moduleId == m.id).toList();
        final admitted = mine.any((a) => a.passesHalf);
        final allGraded = mine.isNotEmpty && mine.every((a) => a.hasResult);

        final statusText = admitted ? 'Zugelassen' : (allGraded ? 'Nicht bestanden' : 'Offen');
        final statusColor = admitted ? c.success : (allGraded ? Colors.redAccent : c.textTertiary);

        return Container(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusText,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Mindestens eine Aufgabe mit der Hälfte der Punkte nötig',
                  style: TextStyle(fontSize: 11, color: c.textTertiary)),
              const SizedBox(height: 8),
              ...mine.map((a) => _row(a, c)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _row(Assignment a, ZenColors c) {
    final detail = <String>[
      if (a.deadline != null) 'Frist ${_fmtDate(a.deadline!)}',
      if (a.hasResult) '${_fmtPoints(a.points!)} / ${_fmtPoints(a.maxPoints!)} Punkte',
      if (!a.hasResult && a.maxPoints != null) 'max. ${_fmtPoints(a.maxPoints!)} Punkte',
    ];
    final overdue = a.deadline != null && !a.hasResult && a.deadline!.isBefore(DateTime.now());

    return GestureDetector(
      onTap: () => _edit(a),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(
              a.passesHalf ? Icons.check_circle : (a.hasResult ? Icons.cancel_outlined : Icons.radio_button_unchecked),
              size: 20,
              color: a.passesHalf ? c.success : (a.hasResult ? Colors.redAccent : c.textTertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                  Text(
                    detail.isEmpty ? 'Tippen, um Frist und Punkte einzutragen' : detail.join(' · '),
                    style: TextStyle(fontSize: 11, color: overdue ? Colors.orangeAccent : c.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
