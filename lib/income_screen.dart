import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'storage.dart';
import 'sync/sync_service.dart';
import 'theme.dart';

const _monthNames = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

final _euro = NumberFormat.currency(locale: 'de_DE', symbol: '€');

/// Liest "1234,50", "1.234,50", "1234.50" und "1.234" (Tausenderpunkt) korrekt ein.
double? parseAmount(String raw) {
  var s = raw.replaceAll(RegExp(r'[\s€]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (s.contains('.')) {
    final parts = s.split('.');
    final isDecimal = parts.length == 2 && parts.last.length <= 2;
    if (!isDecimal) s = s.replaceAll('.', '');
  }
  final value = double.tryParse(s);
  return (value == null || value < 0 || value.isNaN || value.isInfinite) ? null : value;
}

/// Arbeitstracker: pro Monat eintragen, wie viel man verdient hat – mit
/// Jahressumme, Durchschnitt, bestem Monat und einem Balkendiagramm.
class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final _storage = ZenStorage();
  int _year = DateTime.now().year;
  Map<int, double> _amounts = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    SyncService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    SyncService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final amounts = await _storage.loadIncomeYear(_year);
    if (!mounted) return;
    setState(() {
      _amounts = amounts;
      _loaded = true;
    });
  }

  void _changeYear(int delta) {
    setState(() {
      _year += delta;
      _loaded = false;
    });
    _load();
  }

  Future<void> _edit(int month) async {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;
    final current = _amounts[month];
    final controller = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(2).replaceAll('.', ',').replaceAll(RegExp(r',00$'), ''),
    );

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('${_monthNames[month - 1]} $_year', style: TextStyle(color: c.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: c.textPrimary, fontSize: 18),
          decoration: const InputDecoration(labelText: 'Verdient', suffixText: '€', border: OutlineInputBorder()),
          onSubmitted: (_) => Navigator.pop(ctx, 'save'),
        ),
        actions: [
          if (current != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Löschen')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Speichern')),
        ],
      ),
    );

    final text = controller.text;
    controller.dispose();
    if (action == 'delete') {
      await _storage.saveIncome(_year, month, null);
    } else if (action == 'save') {
      final value = parseAmount(text);
      if (value == null) return;
      await _storage.saveIncome(_year, month, value);
    } else {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZenTheme>()!.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        title: Text('Arbeitstracker', style: TextStyle(color: c.textPrimary, fontSize: 17)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: !_loaded
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: _content(c),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(ZenColors c) {
    final now = DateTime.now();
    final total = _amounts.values.fold<double>(0, (a, b) => a + b);
    final average = _amounts.isEmpty ? null : total / _amounts.length;
    final best = _amounts.isEmpty ? null : _amounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final maxValue = _amounts.isEmpty ? 0.0 : _amounts.values.reduce((a, b) => a > b ? a : b);

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _changeYear(-1),
            icon: Icon(Icons.chevron_left, color: c.textSecondary),
          ),
          SizedBox(
            width: 90,
            child: Text('$_year',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
          IconButton(
            onPressed: _year >= now.year + 1 ? null : () => _changeYear(1),
            icon: Icon(Icons.chevron_right, color: _year >= now.year + 1 ? c.textTertiary : c.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('Verdient in $_year', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 6),
            Text(_euro.format(total),
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, color: c.textPrimary)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _tile('Ø pro Monat', average == null ? '–' : _euro.format(average), c)),
          const SizedBox(width: 8),
          Expanded(
            child: _tile(
              'Bester Monat',
              best == null ? '–' : '${_monthNames[best.key - 1].substring(0, 3)} · ${_euro.format(best.value)}',
              c,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _chart(c, maxValue, now),
      const SizedBox(height: 16),
      ...List.generate(12, (i) => _monthRow(c, i + 1, now)),
    ];
  }

  Widget _tile(String label, String value, ZenColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: c.textTertiary)),
        ],
      ),
    );
  }

  Widget _chart(ZenColors c, double maxValue, DateTime now) {
    const barArea = 110.0;
    return SizedBox(
      height: barArea + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (i) {
          final month = i + 1;
          final value = _amounts[month];
          final isCurrent = _year == now.year && month == now.month;
          final height = (value == null || maxValue <= 0) ? 0.0 : (value / maxValue) * barArea;
          return Expanded(
            child: GestureDetector(
              onTap: () => _edit(month),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: value == null ? 3 : (height < 3 ? 3 : height),
                    decoration: BoxDecoration(
                      color: value == null ? c.divider : (isCurrent ? c.success : c.accent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _monthNames[i].substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isCurrent ? c.textPrimary : c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _monthRow(ZenColors c, int month, DateTime now) {
    final value = _amounts[month];
    final isFuture = _year > now.year || (_year == now.year && month > now.month);
    return GestureDetector(
      onTap: () => _edit(month),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _monthNames[month - 1],
                style: TextStyle(fontSize: 15, color: isFuture ? c.textTertiary : c.textPrimary),
              ),
            ),
            Text(
              value == null ? 'eintragen' : _euro.format(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                color: value == null ? c.textTertiary : c.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
