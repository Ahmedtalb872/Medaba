import 'package:flutter_test/flutter_test.dart';
import 'package:medaba/data/storage.dart';
import 'package:medaba/data/synced_storage.dart';
import 'package:medaba/models/models.dart';
import 'package:medaba/state/app_state.dart';

/// قاعدة بيانات وهمية يمكن قطع الاتصال بها.
class FakeRemote implements RemoteStore {
  final Map<String, List<Map<String, dynamic>>> rows = {};
  bool online = true;
  int puts = 0;

  void _check() {
    if (!online) throw Exception('offline');
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchAll() async {
    _check();
    return {for (final e in rows.entries) e.key: List.of(e.value)};
  }

  @override
  Future<void> put(String key, List<Map<String, dynamic>> items) async {
    _check();
    puts++;
    rows[key] = List.of(items);
  }
}

void main() {
  late MemoryStorage local;
  late FakeRemote remote;

  SyncedStorage open() => SyncedStorage(
    local: local,
    remote: remote,
    retryDelay: const Duration(milliseconds: 10),
  );

  setUp(() {
    local = MemoryStorage();
    remote = FakeRemote();
  });

  test('first link uploads the data already on the device', () async {
    local.data['workers'] = [
      {'id': 'w'},
    ];
    final s = open();
    await s.init(AppState.storageKeys);
    await s.flush();
    expect(remote.rows['workers'], [
      {'id': 'w'},
    ]);
    expect(s.status.value, SyncStatus.synced);
  });

  test('the database wins over an old copy on the device', () async {
    local.data['workers'] = [
      {'id': 'old'},
    ];
    remote.rows['workers'] = [
      {'id': 'new'},
    ];
    remote.rows['products'] = [];
    final s = open();
    await s.init(AppState.storageKeys);
    expect(await s.readList('workers'), [
      {'id': 'new'},
    ]);
    expect(remote.puts, 0);
  });

  test('changes made offline are kept and uploaded later', () async {
    remote.rows['workers'] = [];
    final s = open();
    await s.init(AppState.storageKeys);

    remote.online = false;
    await s.writeList('workers', [
      {'id': 'a'},
    ]);
    await s.flush();
    expect(s.status.value, SyncStatus.offline);
    expect(s.hasPending, isTrue);

    // التطبيق أُغلق وفُتح من جديد قبل عودة الاتصال: التغيير لا يضيع.
    final reopened = open();
    remote.online = true;
    await reopened.init(AppState.storageKeys);
    await reopened.flush();
    expect(remote.rows['workers'], [
      {'id': 'a'},
    ]);
    expect(await reopened.readList('workers'), [
      {'id': 'a'},
    ]);
    expect(reopened.hasPending, isFalse);
    expect(reopened.status.value, SyncStatus.synced);
    s.dispose();
  });

  test('a failed upload is retried automatically', () async {
    remote.rows['workers'] = [];
    final s = open();
    await s.init(AppState.storageKeys);
    remote.online = false;
    await s.writeList('workers', [
      {'id': 'b'},
    ]);
    await s.flush();
    remote.online = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s.flush();
    expect(remote.rows['workers'], [
      {'id': 'b'},
    ]);
    expect(s.status.value, SyncStatus.synced);
  });

  test('without internet the app opens with the copy on the device', () async {
    local.data['workers'] = [
      Worker(
        id: 'w',
        name: 'سالم',
        monthlySalary: 1000,
        hiredAt: DateTime(2025),
      ).toJson(),
    ];
    remote.online = false;
    final s = open();
    await s.init(AppState.storageKeys);
    expect(s.status.value, SyncStatus.offline);
    final state = AppState(s);
    await state.load();
    expect(state.workers.single.name, 'سالم');
  });

  test('app state saves go through to the database', () async {
    final s = open();
    await s.init(AppState.storageKeys);
    final state = AppState(s);
    await state.load();
    await state.saveWorker(
      Worker(id: 'w', name: 'عمر', monthlySalary: 500, hiredAt: DateTime(2025)),
    );
    await s.flush();
    expect(remote.rows['workers']!.single['name'], 'عمر');
  });
}
