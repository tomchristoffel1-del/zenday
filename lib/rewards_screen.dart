import 'package:flutter/material.dart';
import 'accent_options.dart';
import 'app_settings.dart';
import 'rewards.dart';
import 'storage.dart';
import 'theme.dart';

/// Zeigt gesammelte Fokuspunkte und die daraus freischaltbaren Belohnungen:
/// Akzentfarben zum Auswählen sowie eine Liste erreichter/offener Meilensteine.
class RewardsScreen extends StatefulWidget {
  final int points;
  const RewardsScreen({super.key, required this.points});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _storage = ZenStorage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text('Belohnungen', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, size: 22, color: colors.success),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.points} Punkte',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Akzentfarben', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                const SizedBox(height: 10),
                ValueListenableBuilder<int>(
                  valueListenable: AppSettings.accentIndex,
                  builder: (context, selected, _) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(accentOptions.length, (i) {
                        final option = accentOptions[i];
                        final unlocked = widget.points >= option.unlockPoints;
                        final isSelected = selected == i;
                        return GestureDetector(
                          onTap: unlocked
                              ? () => AppSettings.setAccent(_storage, i)
                              : () => ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${option.name}: ab ${option.unlockPoints} Punkten (noch ${option.unlockPoints - widget.points})',
                                      ),
                                    ),
                                  ),
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: unlocked ? option.light : colors.divider,
                                  border: isSelected
                                      ? Border.all(color: colors.textPrimary, width: 2.5)
                                      : null,
                                ),
                                child: !unlocked
                                    ? Icon(Icons.lock_outline, size: 18, color: colors.textTertiary)
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                option.name,
                                style: TextStyle(fontSize: 11, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text('Meilensteine', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                const SizedBox(height: 10),
                ...rewardMilestones.map((m) {
                  final reached = widget.points >= m.points;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          reached ? Icons.emoji_events : Icons.emoji_events_outlined,
                          size: 20,
                          color: reached ? colors.success : colors.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.title} · ${m.points} Punkte',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: reached ? colors.textPrimary : colors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.message,
                                style: TextStyle(fontSize: 12, color: colors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
