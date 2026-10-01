import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Chip-Auswahl für das Wiederholungsmuster einer Aufgabe. Bei "Eigene Tage"
/// erscheinen sieben kleine Tages-Toggles darunter.
class RepeatSelector extends StatelessWidget {
  final Repeat repeat;
  final Set<int> customDays;
  final ZenColors colors;
  final ValueChanged<Repeat> onRepeatChanged;
  final ValueChanged<Set<int>> onCustomDaysChanged;

  const RepeatSelector({
    super.key,
    required this.repeat,
    required this.customDays,
    required this.colors,
    required this.onRepeatChanged,
    required this.onCustomDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(context, 'Jeden Tag', Repeat.daily),
            _chip(context, 'Wochentags', Repeat.weekdays),
            _chip(context, 'Wochenende', Repeat.weekend),
            _chip(context, 'Eigene Tage', Repeat.custom),
          ],
        ),
        if (repeat == Repeat.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = customDays.contains(day);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      final next = Set<int>.from(customDays);
                      if (selected) {
                        next.remove(day);
                      } else {
                        next.add(day);
                      }
                      onCustomDaysChanged(next);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? colors.accent : Colors.transparent,
                        border: Border.all(
                          color: selected ? colors.accent : colors.divider,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _weekdayLabels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? colors.background : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _chip(BuildContext context, String label, Repeat value) {
    final selected = repeat == value;
    return GestureDetector(
      onTap: () => onRepeatChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.accent : Colors.transparent,
          border: Border.all(color: selected ? colors.accent : colors.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? colors.background : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
