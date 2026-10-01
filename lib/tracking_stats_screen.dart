import 'package:flutter/material.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

class _YearStats {
  int vegetableDays = 0;
  int sugarFreeDays = 0;
  int sportDays = 0;
  int totalDays = 0;
  final Map<Mood, int> moodCounts = {for (final m in Mood.values) m: 0};
}

/// Jahresübersicht der täglichen Gewohnheits-Tracker: wie viele Tage Gemüse
/// gegessen, kein Zucker, Sport gemacht, und die Stimmungsverteilung.
class TrackingStatsScreen extends StatefulWidget {
  const TrackingStatsScreen({super.key});

  @override
  State<TrackingStatsScreen> createState() => _TrackingStatsScreenState();
}

class _TrackingStatsScreenState extends State<TrackingStatsScreen> {
  final _storage = ZenStorage();
  _YearStats? _stats;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final templates = await _storage.loadTemplates();
    final sportIds = templates.where((t) => t.title.trim() == 'Sport & Training').map((t) => t.id).toSet();

    final now = _atMidnight(DateTime.now());
    final yearStart = DateTime(now.year, 1, 1);
    final stats = _YearStats();

    for (var day = yearStart; !day.isAfter(now); day = day.add(const Duration(days: 1))) {
      stats.totalDays++;
      final tracking = await _storage.loadTracking(day);
      if (tracking.vegetables) stats.vegetableDays++;
      if (tracking.sugarFree) stats.sugarFreeDays++;
      if (tracking.mood != null) {
        stats.moodCounts[tracking.mood!] = (stats.moodCounts[tracking.mood!] ?? 0) + 1;
      }
      if (sportIds.isNotEmpty) {
        final done = await _storage.loadTemplateDoneIds(day);
        if (sportIds.any(done.contains)) stats.sportDays++;
      }
    }

    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;
    final year = DateTime.now().year;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text('Jahresübersicht $year', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
      ),
      body: _stats == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _statTile('🥦 Gemüse gegessen', _stats!.vegetableDays, _stats!.totalDays, colors),
                      _statTile('🍬 Kein Zucker', _stats!.sugarFreeDays, _stats!.totalDays, colors),
                      _statTile('🏃 Sport gemacht', _stats!.sportDays, _stats!.totalDays, colors),
                      const SizedBox(height: 24),
                      Text('Stimmung', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 10),
                      _moodBar('😞', _stats!.moodCounts[Mood.low]!, _stats!.totalDays, colors),
                      _moodBar('😐', _stats!.moodCounts[Mood.mid]!, _stats!.totalDays, colors),
                      _moodBar('😊', _stats!.moodCounts[Mood.high]!, _stats!.totalDays, colors),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statTile(String label, int count, int total, ZenColors c) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Text(label, style: TextStyle(fontSize: 14, color: c.textPrimary)),
              Text('$count / $total Tage',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: c.divider,
              valueColor: AlwaysStoppedAnimation(c.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodBar(String emoji, int count, int total, ZenColors c) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: c.divider,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 28, child: Text('$count', style: TextStyle(fontSize: 12, color: c.textSecondary))),
        ],
      ),
    );
  }
}
