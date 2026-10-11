import 'package:flutter/material.dart';
import '../day_notes.dart';
import '../theme.dart';

/// Kompakte Zeile im Tagesplan: zeigt die Notiz des Tages (oder lädt zum Schreiben ein).
class DayNoteRow extends StatelessWidget {
  final DayNote note;
  final ZenColors colors;
  final VoidCallback onTap;

  const DayNoteRow({super.key, required this.note, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final empty = note.isEmpty;
    final tags = note.tags.map((id) => noteCategoryById[id]).whereType<NoteCategory>().toList();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: c.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note, size: 20, color: empty ? c.textTertiary : c.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                empty ? 'Notiz zum Tag…' : (note.text.trim().isEmpty ? 'Kategorien gesetzt' : note.text.trim()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: empty ? c.textTertiary : c.textPrimary),
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(tags.take(4).map((t) => t.emoji).join(' '), style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Öffnet das Notizfenster. Gespeichert wird beim Schließen – auch beim Wegwischen.
Future<DayNote?> showDayNoteSheet(BuildContext context, DayNote note, String dayLabel, ZenColors c) async {
  final working = DayNote(text: note.text, added: {...note.added}, removed: {...note.removed});
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _DayNoteSheet(note: working, dayLabel: dayLabel, colors: c),
  );
  return working;
}

class _DayNoteSheet extends StatefulWidget {
  final DayNote note;
  final String dayLabel;
  final ZenColors colors;

  const _DayNoteSheet({required this.note, required this.dayLabel, required this.colors});

  @override
  State<_DayNoteSheet> createState() => _DayNoteSheetState();
}

class _DayNoteSheetState extends State<_DayNoteSheet> {
  late final _controller = TextEditingController(text: widget.note.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final note = widget.note;
    final tags = note.tags;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Notiz · ${widget.dayLabel}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
              ],
            ),
            const SizedBox(height: 4),
            Text('Wie war der Tag? Z. B. "müde, schlecht geschlafen, trotzdem konzentriert gelernt"',
                style: TextStyle(fontSize: 12, color: c.textTertiary)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: note.isEmpty,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: c.textPrimary),
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => note.text = v),
            ),
            const SizedBox(height: 16),
            Text('Kategorien – automatisch erkannt, per Tipp korrigieren',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: noteCategories.map((cat) {
                final active = tags.contains(cat.id);
                final tint = switch (cat.polarity) {
                  Polarity.positive => c.success,
                  Polarity.negative => Colors.redAccent,
                  Polarity.neutral => c.accent,
                };
                return GestureDetector(
                  onTap: () => setState(() => note.toggle(cat.id)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? tint.withValues(alpha: 0.15) : Colors.transparent,
                      border: Border.all(color: active ? tint : c.divider),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${cat.emoji} ${cat.label}',
                        style: TextStyle(fontSize: 12, color: active ? c.textPrimary : c.textTertiary)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
