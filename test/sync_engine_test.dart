import 'package:flutter_test/flutter_test.dart';
import 'package:zenday/sync/kv_store.dart';
import 'package:zenday/sync/sync_engine.dart';

class FakeRemote implements RemoteStore {
  final Map<String, SyncDoc> docs = {};
  final Map<String, int> _seq = {};
  int _counter = 0;
  bool offline = false;

  @override
  Future<void> push(List<SyncDoc> list) async {
    if (offline) throw Exception('offline');
    for (final d in list) {
      docs[d.key] = d;
      _seq[d.key] = ++_counter;
    }
  }

  @override
  Future<RemotePage> pull(String? cursor) async {
    if (offline) throw Exception('offline');
    final since = int.tryParse(cursor ?? '') ?? 0;
    final keys = _seq.entries.where((e) => e.value > since).toList()..sort((a, b) => a.value.compareTo(b.value));
    return RemotePage(keys.map((e) => docs[e.key]!).toList(), keys.isEmpty ? null : '${keys.last.value}', false);
  }
}

class Device {
  final MemoryKvStore store = MemoryKvStore();
  late final SyncEngine engine;
  int clock;
  Device(this.clock) {
    engine = SyncEngine(store, now: () => clock);
  }

  Future<void> write(String key, Object value) async {
    await store.put(key, value);
    await engine.onLocalWrite(key);
  }

  Future<void> remove(String key) async {
    await store.delete(key);
    await engine.onLocalWrite(key, deleted: true);
  }
}

Future<Device> device(int clock) async {
  final d = Device(clock);
  await d.engine.init();
  return d;
}

void main() {
  test('Erstes Gerät lädt hoch, zweites leeres Gerät übernimmt alles', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    await pc.write('zenday_templates', '[{"id":"a"}]');
    await pc.write('zenday_focus_points', 7);
    await pc.write('zenday_order_2026-10-07', ['x', 'y']);

    await pc.engine.sync(remote);
    expect(remote.docs.length, 3);

    final phone = await device(2000);
    final result = await phone.engine.sync(remote);

    expect(result.changedKeys, containsAll(['zenday_templates', 'zenday_focus_points', 'zenday_order_2026-10-07']));
    expect(phone.store.get('zenday_templates'), '[{"id":"a"}]');
    expect(phone.store.get('zenday_focus_points'), 7);
    expect(phone.store.get('zenday_order_2026-10-07'), ['x', 'y']);
    expect(phone.engine.pendingCount, 0);
  });

  test('Vorhandene Daten ohne Zeitstempel werden beim ersten Abgleich hochgeladen', () async {
    final remote = FakeRemote();
    final pc = Device(1000);
    await pc.store.put('zenday_templates', '[1]'); // Altbestand aus der Zeit vor dem Sync
    await pc.engine.init();

    expect(pc.engine.pendingCount, 1);
    await pc.engine.sync(remote);
    expect(remote.docs['zenday_templates']!.value, contains('[1]'));
    expect(pc.engine.pendingCount, 0);
  });

  test('Erster Abgleich: Cloud gewinnt gegen lokale Testdaten, Original wird gesichert', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    await pc.write('zenday_templates', 'echter plan');
    await pc.engine.sync(remote);

    final phone = await device(5000); // Handy-Uhr ist sogar neuer
    await phone.write('zenday_templates', 'testdaten vom handy');
    await phone.engine.sync(remote);

    expect(phone.store.get('zenday_templates'), 'echter plan');
    expect(phone.engine.backups['zenday_templates'], contains('testdaten vom handy'));
    expect(remote.docs['zenday_templates']!.value, contains('echter plan'));
  });

  test('Spätere Änderung gewinnt, in beide Richtungen', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    final phone = await device(1000);
    await pc.write('zenday_focus_points', 1);
    await pc.engine.sync(remote);
    await phone.engine.sync(remote);

    pc.clock = 2000;
    await pc.write('zenday_focus_points', 2);
    await pc.engine.sync(remote);
    await phone.engine.sync(remote);
    expect(phone.store.get('zenday_focus_points'), 2);

    phone.clock = 3000;
    await phone.write('zenday_focus_points', 3);
    await phone.engine.sync(remote);
    await pc.engine.sync(remote);
    expect(pc.store.get('zenday_focus_points'), 3);
  });

  test('Bei gleichzeitiger Offline-Änderung gewinnt die jüngere, beide Geräte werden gleich', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    final phone = await device(1000);
    await pc.write('zenday_study_running_start', 'start');
    await pc.engine.sync(remote);
    await phone.engine.sync(remote);

    remote.offline = true;
    pc.clock = 2000;
    await pc.write('zenday_focus_points', 10);
    phone.clock = 3000;
    await phone.write('zenday_focus_points', 20);
    expect(() => pc.engine.sync(remote), throwsException);
    expect(pc.engine.pendingCount, 1);

    remote.offline = false;
    await pc.engine.sync(remote);
    await phone.engine.sync(remote);
    await pc.engine.sync(remote);

    expect(pc.store.get('zenday_focus_points'), 20);
    expect(phone.store.get('zenday_focus_points'), 20);
    expect(pc.engine.pendingCount, 0);
    expect(phone.engine.pendingCount, 0);
  });

  test('Löschen (z. B. Timer stoppen) kommt auf dem anderen Gerät an', () async {
    final remote = FakeRemote();
    final phone = await device(1000);
    final pc = await device(1000);

    await phone.write('zenday_study_running_start', '2026-10-07T09:00:00');
    await phone.engine.sync(remote);
    await pc.engine.sync(remote);
    expect(pc.store.get('zenday_study_running_start'), '2026-10-07T09:00:00');

    pc.clock = 2000;
    await pc.remove('zenday_study_running_start');
    await pc.engine.sync(remote);
    final result = await phone.engine.sync(remote);

    expect(result.changedKeys, contains('zenday_study_running_start'));
    expect(phone.store.get('zenday_study_running_start'), isNull);
  });

  test('Geräteabhängige Schlüssel werden nie synchronisiert', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    await pc.write('zenday_focus_config', '{"enabled":true}');
    await pc.write('zenday_theme_mode', 'dark');
    await pc.write('zenday_usage_2026-10-07', '{}');
    await pc.write('zenday_templates', '[]');
    await pc.engine.sync(remote);

    expect(remote.docs.keys, ['zenday_templates']);
  });

  test('Ungeänderte Daten werden nicht erneut hochgeladen', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    await pc.write('zenday_templates', '[]');
    final first = await pc.engine.sync(remote);
    final second = await pc.engine.sync(remote);
    expect(first.pushed, 1);
    expect(second.pushed, 0);
  });

  test('Abgleichsstand überlebt einen Neustart', () async {
    final remote = FakeRemote();
    final pc = await device(1000);
    await pc.write('zenday_templates', '[1]');
    await pc.engine.sync(remote);
    await pc.write('zenday_templates', '[2]');

    final restarted = SyncEngine(pc.store, now: () => 5000);
    await restarted.init();
    expect(restarted.hasSyncedBefore, isTrue);
    expect(restarted.pendingCount, 1);
    await restarted.sync(remote);
    expect(remote.docs['zenday_templates']!.value, contains('[2]'));
  });
}
