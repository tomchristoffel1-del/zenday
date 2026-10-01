import 'models.dart';
import 'storage.dart';

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

int? _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

bool nowWithin(String start, String end, DateTime now) {
  final nowMinutes = now.hour * 60 + now.minute;
  final startM = _toMinutes(start);
  final endM = _toMinutes(end);
  if (startM == null || endM == null) return true;
  if (startM <= endM) return nowMinutes >= startM && nowMinutes < endM;
  return nowMinutes >= startM || nowMinutes < endM; // über Mitternacht
}

/// Ergebnis der Zusammenführung: der einfache Fokus-Modus plus alle gerade
/// aktiven, an Aufgaben gekoppelten Blocklisten.
class ActiveBlocks {
  final FocusConfig merged;
  final List<BlockList> activeLists;
  const ActiveBlocks(this.merged, this.activeLists);
}

class FocusEngine {
  /// Führt den globalen Fokus-Modus mit allen gerade aktiven, task-verknüpften
  /// Blocklisten zusammen. Eine Liste ist aktiv, wenn ihre Aufgabe heute gilt,
  /// wir uns im Zeitfenster befinden, und sie nicht gerade per Bypass entsperrt ist.
  static Future<ActiveBlocks> computeEffective(ZenStorage storage) async {
    final global = await storage.loadFocusConfig();
    final lists = await storage.loadBlockLists();
    final templates = await storage.loadTemplates();
    final now = DateTime.now();
    final today = _atMidnight(now);

    final processes = <String>{};
    final websites = <String>{};

    final globalActive = global.enabled &&
        (global.startTime == null || global.endTime == null || nowWithin(global.startTime!, global.endTime!, now));
    if (globalActive) {
      processes.addAll(global.blockedProcesses);
      websites.addAll(global.blockedWebsites);
    }

    BlockList? findList(String id) {
      for (final l in lists) {
        if (l.id == id) return l;
      }
      return null;
    }

    final activeLists = <BlockList>[];
    for (final t in templates) {
      if (t.linkedListId == null) continue;
      if (t.startTime == null || t.endTime == null) continue;
      if (!t.appliesOn(today)) continue;
      if (!nowWithin(t.startTime!, t.endTime!, now)) continue;
      final list = findList(t.linkedListId!);
      if (list == null || list.isBypassedNow) continue;
      activeLists.add(list);
      processes.addAll(list.processes);
      websites.addAll(list.websites);
    }

    final adhoc = await storage.loadAdHoc(today);
    for (final a in adhoc) {
      if (a.linkedListId == null) continue;
      if (a.startTime == null || a.endTime == null) continue;
      if (!nowWithin(a.startTime!, a.endTime!, now)) continue;
      final list = findList(a.linkedListId!);
      if (list == null || list.isBypassedNow) continue;
      if (!activeLists.any((l) => l.id == list.id)) activeLists.add(list);
      processes.addAll(list.processes);
      websites.addAll(list.websites);
    }

    final mergedConfig = FocusConfig(
      blockedProcesses: processes.toList(),
      blockedWebsites: websites.toList(),
      enabled: processes.isNotEmpty || websites.isNotEmpty,
    );
    return ActiveBlocks(mergedConfig, activeLists);
  }
}
