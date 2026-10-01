import 'dart:async';
import 'package:flutter/material.dart';
import 'app_picker.dart';
import 'focus_engine.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';

const _bypassLabels = {
  BypassMode.easy: 'Einfach · kurze, feste Wartezeit',
  BypassMode.medium: 'Mittel · frei wählbare Wartezeit',
  BypassMode.hard: 'Hart · kein vorzeitiges Entsperren',
};

/// Benannte Blocklisten, die man an Aufgaben hängen kann (siehe
/// TemplateComposer). Hier legt man Name, Inhalt und Bypass-Regeln fest,
/// und kann eine gerade aktive Liste mit Wartezeit vorzeitig entsperren.
class BlockListsScreen extends StatefulWidget {
  const BlockListsScreen({super.key});

  @override
  State<BlockListsScreen> createState() => _BlockListsScreenState();
}

class _BlockListsScreenState extends State<BlockListsScreen> {
  final _storage = ZenStorage();
  List<BlockList> _lists = [];
  Set<String> _activeIds = {};
  bool _loaded = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final lists = await _storage.loadBlockLists();
    setState(() {
      _lists = lists;
      _loaded = true;
    });
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final active = await FocusEngine.computeEffective(_storage);
    if (!mounted) return;
    setState(() => _activeIds = active.activeLists.map((l) => l.id).toSet());
  }

  Future<void> _persist() async {
    await _storage.saveBlockLists(_lists);
  }

  void _createList() async {
    final name = await _promptName(context, 'Neue Liste', '');
    if (name == null || name.trim().isEmpty) return;
    setState(() => _lists.add(BlockList(name: name.trim())));
    _persist();
  }

  Future<String?> _promptName(BuildContext context, String title, String initial) async {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(title, style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Speichern', style: TextStyle(color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _deleteList(BlockList list) {
    setState(() => _lists.remove(list));
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
        title: Text('Blocklisten', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
        actions: [
          IconButton(onPressed: _createList, icon: Icon(Icons.add, color: colors.textPrimary)),
        ],
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _lists.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'Noch keine Liste. Lege eine an (z. B. "Arbeit" oder '
                              '"Nicht stören") und verknüpfe sie in einer Aufgabe.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: colors.textTertiary),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                          children: _lists
                              .map((l) => _ListCard(
                                    list: l,
                                    colors: colors,
                                    isActive: _activeIds.contains(l.id),
                                    onChanged: _persist,
                                    onRename: () async {
                                      final name = await _promptName(context, 'Liste umbenennen', l.name);
                                      if (name != null && name.trim().isNotEmpty) {
                                        setState(() => l.name = name.trim());
                                        _persist();
                                      }
                                    },
                                    onDelete: () => _deleteList(l),
                                    onUnlocked: _refreshStatus,
                                  ))
                              .toList(),
                        ),
                ),
              ),
            ),
    );
  }
}

class _ListCard extends StatefulWidget {
  final BlockList list;
  final ZenColors colors;
  final bool isActive;
  final VoidCallback onChanged;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onUnlocked;

  const _ListCard({
    required this.list,
    required this.colors,
    required this.isActive,
    required this.onChanged,
    required this.onRename,
    required this.onDelete,
    required this.onUnlocked,
  });

  @override
  State<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<_ListCard> {
  bool _waiting = false;
  int _secondsLeft = 0;
  Timer? _waitTimer;
  final _processController = TextEditingController();

  @override
  void dispose() {
    _waitTimer?.cancel();
    _processController.dispose();
    super.dispose();
  }

  void _addProcess(String exe) {
    if (!widget.list.processes.contains(exe)) {
      setState(() => widget.list.processes.add(exe));
    }
    widget.onChanged();
  }

  void _startUnlock() {
    final list = widget.list;
    if (list.bypassMode == BypassMode.hard) return;
    final wait = list.bypassWaitSeconds;
    setState(() {
      _waiting = true;
      _secondsLeft = wait;
    });
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _finishUnlock();
      }
    });
  }

  void _finishUnlock() {
    final list = widget.list;
    final duration = list.unlockDurationMinutes;
    list.unlockedUntil = duration != null
        ? DateTime.now().add(Duration(minutes: duration))
        : DateTime.now().add(const Duration(hours: 12));
    setState(() => _waiting = false);
    widget.onChanged();
    widget.onUnlocked();
  }

  void _cancelUnlock() {
    _waitTimer?.cancel();
    setState(() => _waiting = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final list = widget.list;
    final bypassedNow = list.isBypassedNow;

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
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onRename,
                  child: Text(list.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
              ),
              if (widget.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bypassedNow ? c.divider : c.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    bypassedNow ? 'entsperrt' : 'aktiv',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bypassedNow ? c.textTertiary : c.success),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(onTap: widget.onDelete, child: Icon(Icons.delete_outline, size: 18, color: c.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final selected = await AppPicker.pickRunningProcess(context);
                    if (selected != null) _addProcess(selected);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apps, size: 13, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Text('Laufend', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final selected = await AppPicker.pickInstalledApp(context);
                    if (selected != null) _addProcess(selected);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt, size: 13, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Text('Installiert', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (list.processes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: list.processes
                  .map((p) => Chip(
                        label: Text(p, style: TextStyle(fontSize: 11, color: c.textPrimary)),
                        backgroundColor: c.background,
                        side: BorderSide(color: c.divider),
                        onDeleted: () {
                          setState(() => list.processes.remove(p));
                          widget.onChanged();
                        },
                        deleteIconColor: c.textTertiary,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text('Bypass-Modus', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 6),
          ...BypassMode.values.map((mode) {
            return RadioListTile<BypassMode>(
              value: mode,
              groupValue: list.bypassMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: c.accent,
              title: Text(_bypassLabels[mode]!, style: TextStyle(fontSize: 13, color: c.textPrimary)),
              onChanged: (m) {
                setState(() => list.bypassMode = m!);
                widget.onChanged();
              },
            );
          }),
          if (list.bypassMode != BypassMode.hard) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Wartezeit:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    initialValue: (list.bypassWaitSeconds ~/ 60).toString(),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) {
                      final minutes = int.tryParse(v) ?? 5;
                      list.bypassWaitSeconds = minutes * 60;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Text('Min.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Danach entsperrt für:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: list.unlockDurationMinutes?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: '∞',
                  ),
                  onChanged: (v) {
                    list.unlockDurationMinutes = v.trim().isEmpty ? null : int.tryParse(v);
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text('Min. (leer = bis Aufgabenende)', style: TextStyle(fontSize: 11, color: c.textTertiary)),
            ],
          ),
          if (widget.isActive && !bypassedNow) ...[
            const SizedBox(height: 14),
            if (list.bypassMode == BypassMode.hard)
              Text('Hart-Modus: kein vorzeitiges Entsperren möglich.',
                  style: TextStyle(fontSize: 12, color: c.textTertiary))
            else if (_waiting)
              Row(
                children: [
                  Expanded(
                    child: Text('Entsperrt in $_secondsLeft Sek. …',
                        style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ),
                  TextButton(onPressed: _cancelUnlock, child: const Text('Abbrechen')),
                ],
              )
            else
              GestureDetector(
                onTap: _startUnlock,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  width: double.infinity,
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
                  child: Text('Entsperren',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.background)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
