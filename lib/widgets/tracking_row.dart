import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

const _moodEmoji = {Mood.low: '😞', Mood.mid: '😐', Mood.high: '😊'};

/// Die täglichen Gewohnheits-Tracker als kurze Fragen mit Antwort-Chips:
/// Stimmung, gesund gegessen, kein Zucker. Sport wird automatisch aus dem
/// "Sport & Training"-Task abgeleitet und taucht hier nicht separat auf.
class TrackingRow extends StatelessWidget {
  final DailyTracking tracking;
  final ZenColors colors;
  final VoidCallback onToggleVegetables;
  final VoidCallback onToggleSugarFree;
  final ValueChanged<Mood?> onMoodChanged;

  const TrackingRow({
    super.key,
    required this.tracking,
    required this.colors,
    required this.onToggleVegetables,
    required this.onToggleSugarFree,
    required this.onMoodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _question(
          'Wie fühlst du dich heute?',
          Row(
            children: Mood.values.map((m) {
              final selected = tracking.mood == m;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => onMoodChanged(selected ? null : m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? colors.accent.withValues(alpha: 0.15) : Colors.transparent,
                      border: Border.all(color: selected ? colors.accent : colors.divider),
                      shape: BoxShape.circle,
                    ),
                    child: Text(_moodEmoji[m]!, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        _question(
          'Gesund gegessen?',
          _yesNoToggle(active: tracking.vegetables, onTap: onToggleVegetables),
        ),
        const SizedBox(height: 10),
        _question(
          'Kein Zucker?',
          _yesNoToggle(active: tracking.sugarFree, onTap: onToggleSugarFree),
        ),
      ],
    );
  }

  Widget _question(String text, Widget control) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        ),
        control,
      ],
    );
  }

  Widget _yesNoToggle({required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.success : Colors.transparent,
          border: Border.all(color: active ? colors.success : colors.divider, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: active ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}
