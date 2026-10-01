import 'package:flutter/material.dart';
import '../theme.dart';

/// Eine Aufgaben-Zeile mit befriedigendem Abhak-Gefühl: der Kreis füllt
/// sich grün, ein Haken zeichnet sich ein, der Text bekommt einen sanften
/// Strikethrough-Fade. Für Ad-hoc-Aufgaben ist der Titel direkt editierbar.
class TaskRow extends StatelessWidget {
  final String title;
  final String? startTime;
  final bool done;
  final ZenColors colors;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final TextEditingController? editController;
  final ValueChanged<String>? onTitleChanged;

  const TaskRow({
    super.key,
    required this.title,
    required this.done,
    required this.colors,
    required this.onToggle,
    this.startTime,
    this.onDelete,
    this.onEdit,
    this.editController,
    this.onTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final editable = editController != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? colors.success : Colors.transparent,
                border: Border.all(
                  color: done ? colors.success : colors.textTertiary,
                  width: 1.6,
                ),
              ),
              child: AnimatedScale(
                scale: done ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          if (startTime != null) ...[
            SizedBox(
              width: 44,
              child: Text(
                startTime!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
          Expanded(
            child: editable
                ? TextField(
                    controller: editController,
                    onChanged: onTitleChanged,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: done ? colors.textTertiary : colors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: colors.textTertiary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Neue Aufgabe',
                    ),
                  )
                : GestureDetector(
                    onTap: onEdit,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: done ? colors.textTertiary : colors.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: colors.textTertiary,
                      ),
                      child: Text(title),
                    ),
                  ),
          ),
          if (onEdit != null && editable)
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.tune, size: 15, color: colors.textTertiary),
              ),
            ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 16, color: colors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}
