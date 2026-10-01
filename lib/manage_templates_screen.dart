import 'package:flutter/material.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets/template_composer.dart';

const _repeatLabels = {
  Repeat.daily: 'Jeden Tag',
  Repeat.weekdays: 'Wochentags',
  Repeat.weekend: 'Wochenende',
  Repeat.custom: 'Eigene Tage',
};

/// Verwaltung des Grundplans: wiederkehrende Aufgaben hinzufügen/entfernen.
class ManageTemplatesScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ManageTemplatesScreen({super.key, required this.onChanged});

  @override
  State<ManageTemplatesScreen> createState() => _ManageTemplatesScreenState();
}

class _ManageTemplatesScreenState extends State<ManageTemplatesScreen> {
  final _storage = ZenStorage();
  List<TaskTemplate> _templates = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _storage.loadTemplates();
    setState(() {
      _templates = t;
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    await _storage.saveTemplates(_templates);
    widget.onChanged();
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
        title: Text('Dein Grundplan', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                    children: [
                      TemplateComposer(
                        colors: colors,
                        onAdd: (t) {
                          setState(() => _templates.add(t));
                          _persist();
                        },
                      ),
                      const SizedBox(height: 24),
                      Divider(color: colors.divider),
                      const SizedBox(height: 12),
                      if (_templates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Noch keine wiederkehrenden Aufgaben.',
                            style: TextStyle(fontSize: 14, color: colors.textTertiary),
                          ),
                        ),
                      ..._templates.map((t) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.title,
                                          style: TextStyle(fontSize: 15, color: colors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          _repeatLabels[t.repeat]!,
                                          if (t.startTime != null) t.startTime!,
                                        ].join(' · '),
                                        style: TextStyle(fontSize: 12, color: colors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _templates.remove(t));
                                    _persist();
                                  },
                                  child: Icon(Icons.close, size: 18, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
