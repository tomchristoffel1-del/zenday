import 'package:flutter/material.dart';
import 'app_picker.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Von Aufgaben unabhängige App-Regeln: dauerhaft sperren oder ein
/// tägliches Zeitbudget setzen (wie Bildschirmzeit). Gilt immer, egal
/// welche Aufgabe gerade läuft.
class AppLimitsScreen extends StatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  State<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends State<AppLimitsScreen> {
  final _storage = ZenStorage();
  List<AppLimit> _limits = [];
  Map<String, int> _usageToday = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final limits = await _storage.loadAppLimits();
    final usage = await _storage.loadUsageToday(_atMidnight(DateTime.now()));
    setState(() {
      _limits = limits;
      _usageToday = usage;
      _loaded = true;
    });
  }

  Future<void> _persist() => _storage.saveAppLimits(_limits);

  Future<void> _addLimitFrom(String source) async {
    final selected = source == 'running'
        ? await AppPicker.pickRunningProcess(context)
        : await AppPicker.pickInstalledApp(context);
    if (selected == null) return;
    if (_limits.any((l) => l.process == selected)) return;
    setState(() => _limits.add(AppLimit(process: selected, alwaysBlocked: true)));
    _persist();
  }

  void _removeLimit(AppLimit limit) {
    setState(() => _limits.remove(limit));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text('App-Zeitlimits', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        'Gilt immer, unabhängig von Aufgaben und Zeitfenstern – '
                        'entweder eine App komplett sperren oder ihr ein '
                        'tägliches Zeitbudget geben.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _addLimitFrom('running'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                    border: Border.all(color: colors.divider), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.apps, size: 15, color: colors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text('Laufend', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _addLimitFrom('installed'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                    border: Border.all(color: colors.divider), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.list_alt, size: 15, color: colors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text('Installiert', style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_limits.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('Noch keine App-Regel.',
                              style: TextStyle(fontSize: 14, color: colors.textTertiary)),
                        ),
                      ..._limits.map((limit) => _LimitCard(
                            limit: limit,
                            colors: colors,
                            usedSeconds: _usageToday[limit.process] ?? 0,
                            onChanged: _persist,
                            onDelete: () => _removeLimit(limit),
                          )),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _LimitCard extends StatefulWidget {
  final AppLimit limit;
  final ZenColors colors;
  final int usedSeconds;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _LimitCard({
    required this.limit,
    required this.colors,
    required this.usedSeconds,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_LimitCard> createState() => _LimitCardState();
}

class _LimitCardState extends State<_LimitCard> {
  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final limit = widget.limit;
    final usedMinutes = widget.usedSeconds ~/ 60;
    final limitMinutes = limit.dailyMinutes;
    final progress = (!limit.alwaysBlocked && limitMinutes != null && limitMinutes > 0)
        ? (widget.usedSeconds / (limitMinutes * 60)).clamp(0.0, 1.0)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(limit.process,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
              GestureDetector(onTap: widget.onDelete, child: Icon(Icons.delete_outline, size: 18, color: c.textTertiary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _modeChip('Komplett sperren', limit.alwaysBlocked, () {
                setState(() => limit.alwaysBlocked = true);
                widget.onChanged();
              }, c),
              const SizedBox(width: 8),
              _modeChip('Tageslimit', !limit.alwaysBlocked, () {
                setState(() {
                  limit.alwaysBlocked = false;
                  limit.dailyMinutes ??= 30;
                });
                widget.onChanged();
              }, c),
            ],
          ),
          if (!limit.alwaysBlocked) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Minuten pro Tag:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    initialValue: (limit.dailyMinutes ?? 30).toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) {
                      limit.dailyMinutes = int.tryParse(v) ?? limit.dailyMinutes;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: c.divider,
                  valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.redAccent : c.success),
                ),
              ),
              const SizedBox(height: 4),
              Text('$usedMinutes von ${limit.dailyMinutes} Min. heute genutzt',
                  style: TextStyle(fontSize: 11, color: c.textTertiary)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool selected, VoidCallback onTap, ZenColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          border: Border.all(color: selected ? c.accent : c.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? c.background : c.textSecondary)),
      ),
    );
  }
}
