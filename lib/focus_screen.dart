import 'platform_info.dart';
import 'package:flutter/material.dart';
import 'app_limits_screen.dart';
import 'app_picker.dart';
import 'autostart.dart';
import 'block_lists_screen.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';

/// Einfacher Fokus-Modus: ein globales Zeitfenster, in dem Programme und
/// Websites blockiert werden. Für an Aufgaben gekoppelte Listen siehe
/// BlockListsScreen. Die eigentliche Durchsetzung übernimmt FocusGuard.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _storage = ZenStorage();
  final _processController = TextEditingController();
  final _websiteController = TextEditingController();
  FocusConfig _config = FocusConfig();
  bool _autostart = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _processController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await _storage.loadFocusConfig();
    final autostart = await _storage.loadAutostart();
    setState(() {
      _config = c;
      _autostart = autostart;
      _loaded = true;
    });
  }

  void _persist() => _storage.saveFocusConfig(_config);

  Future<void> _toggleAutostart(bool value) async {
    setState(() => _autostart = value);
    final ok = value ? await Autostart.enable() : await Autostart.disable();
    if (!ok && mounted) {
      setState(() => _autostart = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autostart konnte nicht geändert werden.')),
      );
      return;
    }
    await _storage.saveAutostart(value);
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _config.startTime : _config.endTime;
    final parts = current?.split(':');
    final initial = parts != null
        ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _config.startTime = formatted;
      } else {
        _config.endTime = formatted;
      }
    });
    _persist();
  }

  void _addProcess() {
    var name = _processController.text.trim();
    if (name.isEmpty) return;
    if (!name.toLowerCase().endsWith('.exe')) name = '$name.exe';
    _addBlockedExe(name);
    _processController.clear();
  }

  void _removeProcess(String name) {
    setState(() => _config.blockedProcesses.remove(name));
    _persist();
  }

  void _addBlockedExe(String exe) {
    if (_config.blockedProcesses.contains(exe)) return;
    setState(() => _config.blockedProcesses.add(exe));
    _persist();
  }

  Future<void> _pickRunningProcess() async {
    final selected = await AppPicker.pickRunningProcess(context);
    if (selected != null) _addBlockedExe(selected);
  }

  Future<void> _pickInstalledApp() async {
    final selected = await AppPicker.pickInstalledApp(context);
    if (selected != null) _addBlockedExe(selected);
  }

  void _addWebsite() {
    var domain = _websiteController.text.trim().toLowerCase();
    if (domain.isEmpty) return;
    domain = domain.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'^www\.'), '');
    domain = domain.split('/').first;
    if (_config.blockedWebsites.contains(domain)) return;
    setState(() {
      _config.blockedWebsites.add(domain);
      _websiteController.clear();
    });
    _persist();
  }

  void _removeWebsite(String domain) {
    setState(() => _config.blockedWebsites.remove(domain));
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
        title: Text('Fokus-Modus', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
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
                      if (!isWindowsDesktop)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Der Fokus-Modus blockiert Programme nur unter Windows.',
                            style: TextStyle(fontSize: 13, color: colors.textTertiary),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BlockListsScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.divider),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add_check, size: 18, color: colors.textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Blocklisten für Aufgaben',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('z. B. "Arbeit" automatisch während einer Aufgabe blockieren',
                                        style: TextStyle(fontSize: 12, color: colors.textTertiary)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AppLimitsScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.divider),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_bottom, size: 18, color: colors.textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('App-Zeitlimits',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('Apps dauerhaft sperren oder Tageslimit setzen – unabhängig von Aufgaben',
                                        style: TextStyle(fontSize: 12, color: colors.textTertiary)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Einfacher Fokus-Modus',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colors.textPrimary),
                          ),
                          Switch(
                            value: _config.enabled,
                            activeThumbColor: colors.success,
                            onChanged: (v) {
                              setState(() => _config.enabled = v);
                              _persist();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Zeitfenster', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _timeField('Start', _config.startTime, () => _pickTime(true), colors)),
                          const SizedBox(width: 10),
                          Expanded(child: _timeField('Ende', _config.endTime, () => _pickTime(false), colors)),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('Blockierte Programme', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _pickerButton('Laufende Programme', Icons.apps, _pickRunningProcess, colors)),
                          const SizedBox(width: 10),
                          Expanded(child: _pickerButton('Installierte Programme', Icons.list_alt, _pickInstalledApp, colors)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _processController,
                              style: TextStyle(color: colors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'z. B. steam.exe',
                                hintStyle: TextStyle(color: colors.textTertiary),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: colors.divider),
                                ),
                              ),
                              onSubmitted: (_) => _addProcess(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _addProcess,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add, size: 18, color: colors.background),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._config.blockedProcesses.map((name) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(name, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                                ),
                                GestureDetector(
                                  onTap: () => _removeProcess(name),
                                  child: Icon(Icons.close, size: 16, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 28),
                      Text('Blockierte Websites', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _websiteController,
                              style: TextStyle(color: colors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'z. B. youtube.com',
                                hintStyle: TextStyle(color: colors.textTertiary),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: colors.divider),
                                ),
                              ),
                              onSubmitted: (_) => _addWebsite(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _addWebsite,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add, size: 18, color: colors.background),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._config.blockedWebsites.map((domain) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(domain, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                                ),
                                GestureDetector(
                                  onTap: () => _removeWebsite(domain),
                                  child: Icon(Icons.close, size: 16, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Mit Windows starten',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
                            ),
                          ),
                          Switch(
                            value: _autostart,
                            activeThumbColor: colors.success,
                            onChanged: isWindowsDesktop ? _toggleAutostart : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Blockaden greifen nur, solange ZenDay läuft (auch minimiert). '
                        'Mit Autostart ist das nach jedem Login automatisch der Fall. '
                        'Website-Blocking braucht Administratorrechte für ZenDay, '
                        'sonst wird es still übersprungen.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _pickerButton(String label, IconData icon, VoidCallback onTap, ZenColors colors) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: colors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(String label, String? value, VoidCallback onTap, ZenColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: c.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value ?? label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: value != null ? c.textPrimary : c.textTertiary),
        ),
      ),
    );
  }
}
