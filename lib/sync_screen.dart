import 'package:flutter/material.dart';
import 'sync/firebase_client.dart';
import 'sync/sync_service.dart';
import 'theme.dart';

/// Anmeldung und Status der Cloud-Synchronisierung.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _service = SyncService.instance;
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit({required bool create}) async {
    if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty) {
      setState(() => _error = 'Bitte E-Mail und Passwort eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.signIn(_emailC.text, _passwordC.text, createAccount: create);
      _passwordC.clear();
    } on SyncException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Keine Verbindung – bitte Internet prüfen und erneut versuchen.';
    }
    if (mounted) setState(() => _busy = false);
  }

  String _statusText() {
    switch (_service.state) {
      case SyncState.syncing:
        return 'Synchronisiere …';
      case SyncState.offline:
        return 'Offline – Änderungen werden nachgeholt, sobald du wieder online bist.';
      case SyncState.error:
        return 'Fehler: ${_service.lastError ?? 'unbekannt'}';
      default:
        final last = _service.lastSync;
        if (last == null) return 'Noch nicht synchronisiert.';
        final secs = DateTime.now().difference(last).inSeconds;
        if (secs < 60) return 'Auf dem neuesten Stand (vor $secs s).';
        return 'Auf dem neuesten Stand (vor ${secs ~/ 60} min).';
    }
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
        title: Text('Synchronisierung', style: TextStyle(color: c.textPrimary, fontSize: 17)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: !_service.configured
                  ? [_notConfigured(c)]
                  : (_service.signedIn ? _signedIn(c) : _signedOut(c)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notConfigured(ZenColors c) => Text(
        'Die Synchronisierung ist in dieser App-Version noch nicht eingerichtet. '
        'Die Daten bleiben nur auf diesem Gerät.',
        style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
      );

  List<Widget> _signedOut(ZenColors c) => [
        Text(
          'Mit einem Konto gleichen sich Handy und PC automatisch ab – auch ein laufender Lern-Timer. '
          'Offline arbeitest du normal weiter, die Änderungen werden später nachgeholt.',
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _emailC,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: TextStyle(color: c.textPrimary),
          decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordC,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          style: TextStyle(color: c.textPrimary),
          decoration: const InputDecoration(labelText: 'Passwort', border: OutlineInputBorder()),
          onSubmitted: (_) => _busy ? null : _submit(create: false),
        ),
        if (_error != null || (_service.lastError != null && !_busy)) ...[
          const SizedBox(height: 12),
          Text(_error ?? _service.lastError!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
        ],
        const SizedBox(height: 18),
        _button('Anmelden', c, filled: true, onTap: _busy ? null : () => _submit(create: false)),
        const SizedBox(height: 10),
        _button('Neues Konto anlegen', c, filled: false, onTap: _busy ? null : () => _submit(create: true)),
        const SizedBox(height: 22),
        Text(
          'Wichtig: Melde dich zuerst auf dem Gerät an, auf dem deine echten Daten liegen (PC). '
          'Bei der ersten Anmeldung eines Geräts gelten die Cloud-Daten; was dabei ersetzt wird, wird vorher gesichert.',
          style: TextStyle(fontSize: 12, height: 1.5, color: c.textTertiary),
        ),
      ];

  List<Widget> _signedIn(ZenColors c) => [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Angemeldet als', style: TextStyle(fontSize: 12, color: c.textTertiary)),
              const SizedBox(height: 2),
              Text(_service.email ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    _service.state == SyncState.error
                        ? Icons.error_outline
                        : (_service.state == SyncState.offline ? Icons.cloud_off : Icons.cloud_done_outlined),
                    size: 18,
                    color: _service.state == SyncState.error
                        ? Colors.redAccent
                        : (_service.state == SyncState.offline ? Colors.orangeAccent : c.success),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusText(), style: TextStyle(fontSize: 13, color: c.textSecondary))),
                ],
              ),
              if (_service.pending > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${_service.pending} Änderung(en) warten noch auf den Upload.',
                      style: TextStyle(fontSize: 12, color: c.textTertiary)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _button('Jetzt synchronisieren', c, filled: true, onTap: () => _service.syncNow()),
        const SizedBox(height: 10),
        _button('Abmelden', c, filled: false, onTap: () async {
          await _service.signOut();
        }),
        if (_service.hasBackups) ...[
          const SizedBox(height: 20),
          Text(
            'Beim ersten Abgleich wurden lokale Werte durch Cloud-Daten ersetzt. Die alten Werte sind gesichert '
            '(Schlüssel „zenday_sync_backup“) und können bei Bedarf wiederhergestellt werden.',
            style: TextStyle(fontSize: 12, height: 1.5, color: c.textTertiary),
          ),
        ],
      ];

  Widget _button(String label, ZenColors c, {required bool filled, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: filled ? c.accent : Colors.transparent,
            border: Border.all(color: filled ? c.accent : c.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: filled ? c.background : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
