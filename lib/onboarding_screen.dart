import 'package:flutter/material.dart';
import 'models.dart';
import 'storage.dart';
import 'sync_screen.dart';
import 'theme.dart';
import 'widgets/template_composer.dart';

const _repeatLabels = {
  Repeat.daily: 'Jeden Tag',
  Repeat.weekdays: 'Wochentags',
  Repeat.weekend: 'Wochenende',
  Repeat.custom: 'Eigene Tage',
};

/// Erststart: der Nutzer baut den Grundplan seiner Woche aus wiederkehrenden
/// Aufgaben. Einmalige Aufgaben kommen später direkt im Tagesplan dazu.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _storage = ZenStorage();
  final List<TaskTemplate> _templates = [];

  Future<void> _finish() async {
    await _storage.saveTemplates(_templates);
    await _storage.setOnboarded();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Baue deinen Plan',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Was wiederholt sich in deiner Woche? Einmalige Sachen '
                        'fügst du später direkt im Tagesplan hinzu.',
                        style: TextStyle(fontSize: 14, height: 1.4, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
                    children: [
                      TemplateComposer(
                        colors: colors,
                        onAdd: (t) => setState(() => _templates.add(t)),
                      ),
                      if (_templates.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Divider(color: colors.divider),
                        const SizedBox(height: 12),
                        ..._templates.map((t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      style: TextStyle(fontSize: 15, color: colors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    _repeatLabels[t.repeat]!,
                                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => setState(() => _templates.remove(t)),
                                    child: Icon(Icons.close, size: 16, color: colors.textTertiary),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _finish,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: colors.textPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _templates.isEmpty ? 'Später einrichten' : 'Plan erstellen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.background,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen())),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Schon ZenDay auf einem anderen Gerät? Anmelden & synchronisieren',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: colors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
