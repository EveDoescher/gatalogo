// Explicit external campaign oracles. No product behavior is replaced here.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/data/sqlite_id_batches.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/services/authenticated_api_client.dart';
import 'package:catlogue/services/catalog_sync_coordinator.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/services/vision_api_service.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/stores/notification_store.dart';

class Account extends SessionStore {
  String? owner = 'a';
  int refreshes = 0;
  @override
  bool get isSignedIn => false; // no realtime/preferences I/O
  @override
  AuthSession? get session => owner == null
      ? null
      : AuthSession(
          userId: owner!,
          email: 'test@example.com',
          accessToken: 'synthetic',
          refreshToken: 'synthetic',
        );
  @override
  Future<String> deviceId() async => 'device';
  @override
  Future<String?> accessToken({bool refresh = false}) async {
    if (refresh) refreshes++;
    return 'synthetic';
  }
}

class Storage extends CatDatabase {
  String cursor = '0';
  Completer<List<Cat>>? pending;
  @override
  Future<void> bindUnownedCatsToAccount(
    String ownerId,
    String deviceId,
  ) async {}
  @override
  Future<List<Cat>> getCatsForSync(String ownerId) async => [];
  @override
  Future<List<CatReferencePhoto>> getDirtyReferencePhotos(
    String ownerId,
  ) async => [];
  @override
  Future<String> getSyncCursor(String ownerId) async => cursor;
  @override
  Future<void> setSyncCursor(String ownerId, int value) async {
    cursor = '$value';
  }

  @override
  Future<Cat?> getCatById(String id) async => null;
  @override
  Future<List<Cat>> getCats({String? ownerId}) async =>
      pending == null ? [] : await pending!.future;
  @override
  Future<List<CatAnalysis>> getAnalysesForCats(Iterable<String> ids) async =>
      [];
  @override
  Future<Map<String, List<CatReferencePhoto>>> getReferencePhotosForCats(
    Iterable<String> ids,
  ) async => {};
}

class Synced extends CatalogSyncService {
  Synced(super.session);
  @override
  Future<bool> sync() async => true;
}

class Failure implements Exception {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('DB07 persisted partial page retries after restart without skipped rows or duplicates', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final folder = await Directory.systemTemp.createTemp(
      'gatalogo-page-campaign-',
    );
    await databaseFactory.setDatabasesPath(folder.path);
    final storage = CatDatabase();
    await storage.database;
    final account = Account();
    addTearDown(account.dispose);
    addTearDown(() async {
      await (await storage.database).close();
      final root = await Directory.systemTemp.resolveSymbolicLinks();
      final target = await folder.resolveSymbolicLinks();
      expect(p.isWithin(root, target), true);
      await folder.delete(recursive: true);
    });
    const firstId = '00000000-0000-4000-8000-000000000001';
    const secondId = '00000000-0000-4000-8000-000000000002';
    final stamp = DateTime.utc(2026, 10, 21);
    final photo = File(p.join(folder.path, 'private-fixture.jpg'));
    await photo.writeAsBytes([1, 2, 3]);
    Cat local(String id) => Cat(
      id: id,
      captureNumber: id == firstId ? 1 : 2,
      photoPath: photo.path,
      capturedAt: stamp,
      ownerId: 'a',
      syncState: 'synced',
      localUpdatedAt: stamp,
    );
    await storage.insertCat(local(firstId));
    final body = {
      'next_cursor': 2,
      'changes': [
        for (final entry in [
          (firstId, 'server-first', 1),
          (secondId, 'server-second', 2),
        ])
          {
            'client_id': entry.$1,
            'revision': entry.$3,
            'updated_at': stamp.toIso8601String(),
            'device_id': 'server',
            'payload': {
              'name': entry.$2,
              'captured_at': stamp.toIso8601String(),
            },
            'photo_url': null,
            'reference_photos': [],
          },
      ],
    };
    final cursors = <String?>[];
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      cursors.add(request.url.queryParameters['cursor']);
      return http.Response(jsonEncode(body), 200);
    });
    await http.runWithClient(() async {
      expect(
        await CatalogSyncService(account, database: storage).sync(),
        false,
      );
      expect((await storage.getCatById(firstId))!.name, 'server-first');
      expect(await storage.getCatById(secondId), isNull);
      expect(await storage.getSyncCursor('a'), '0');
      // The missing local photo becomes available before a new coordinator retries.
      await storage.insertCat(local(secondId));
      expect(await CatalogSyncService(account, database: storage).sync(), true);
      expect(await storage.getSyncCursor('a'), '2');
      final rows = await storage.getCats(ownerId: 'a');
      expect(
        {for (final cat in rows) cat.id: cat.name},
        {firstId: 'server-first', secondId: 'server-second'},
      );
      expect(rows, hasLength(2));
      expect(cursors, ['0', '0']);
    }, () => client);
  });

  test(
    'RES03 explicit inbox owner oracle rejects late account A snapshot',
    () async {
      final old = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      final store = NotificationStore(
        loadItems: () {
          calls++;
          return calls == 1
              ? old.future
              : Future.value([
                  {'id': 'B'},
                ]);
        },
        saveRead: (_) async {},
      );
      addTearDown(store.dispose);
      final stale = store.refresh();
      store.clear();
      await store.refresh();
      expect(store.items.map((item) => item['id']).toList(), ['B']);
      old.complete([
        {'id': 'A'},
      ]);
      await stale;
      expect(store.items.map((item) => item['id']).toList(), ['B']);
    },
  );

  test('DB07 real SQLite concurrent opening shares failure then retries without discarding data', () async {
    sqfliteFfiInit();
    final real = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(real.close);
    await real.execute('CREATE TABLE sentinel(value TEXT)');
    await real.insert('sentinel', {'value': 'preserved'});
    var opens = 0;
    final first = Completer<Database>();
    final storage = CatDatabase.withConnection(() {
      opens++;
      return opens == 1 ? first.future : Future.value(real);
    });
    final a = storage.database, b = storage.database;
    expect(identical(a, b), true);
    final checkedA = expectLater(a, throwsA(isA<StateError>()));
    final checkedB = expectLater(b, throwsA(isA<StateError>()));
    first.completeError(StateError('controlled open failure'));
    await Future.wait([checkedA, checkedB]);
    expect(opens, 1);
    final retried = await storage.database;
    expect(opens, 2);
    expect(identical(retried, await storage.database), true);
    expect((await retried.query('sentinel')).single['value'], 'preserved');
  });

  for (final count in [0, 1, 499, 500, 501, 1001]) {
    test('DB01 batch boundary count=$count duplicates and missing IDs', () {
      final unique = List.generate(count, (i) => '$i');
      final result = sqliteIdBatches([...unique, ...unique]).toList();
      expect(result.expand((b) => b).toList(), unique);
      expect(result.length, (count / 500).ceil());
      expect(result.every((b) => b.isNotEmpty && b.length <= 500), true);
    });
  }
  test(
    'RES07 sync single flight shares triggers and releases after failure',
    () async {
      final account = Account();
      addTearDown(account.dispose);
      final storage = Storage();
      final sync = CatalogSyncService(account, database: storage);
      final waiting = Completer<http.Response>();
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? waiting.future
            : http.Response('{"changes":[],"next_cursor":0}', 200);
      });
      await http.runWithClient(() async {
        final operations = List.generate(8, (_) => sync.sync());
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        waiting.completeError(const SocketException('injected offline'));
        expect(await Future.wait(operations), everyElement(false));
        expect(await sync.sync(), true);
        expect(calls, 2);
      }, () => client);
    },
  );
  test('DB07 cursor remains unchanged if remote application fails and retry starts at same cursor', () async {
    final account = Account();
    addTearDown(account.dispose);
    final storage = Storage();
    final sync = CatalogSyncService(account, database: storage);
    final cursors = <String?>[];
    final client = MockClient((r) async {
      cursors.add(r.url.queryParameters['cursor']);
      return http.Response(
        jsonEncode({
          'next_cursor': 5,
          'changes': [
            {
              'client_id': 'remote',
              'revision': 5,
              'updated_at': '2026-10-21T00:00:00Z',
              'payload': {},
              'photo_url': null,
            },
          ],
        }),
        200,
      );
    });
    await http.runWithClient(() async {
      expect(await sync.sync(), false);
      expect(storage.cursor, '0');
      expect(
        await CatalogSyncService(account, database: storage).sync(),
        false,
      );
      expect(storage.cursor, '0');
      expect(cursors, ['0', '0']);
    }, () => client);
  });
  for (final nextOwner in ['b', null]) {
    test(
      'RES03 snapshot after owner changes during read to $nextOwner is rejected',
      () async {
        final account = Account();
        addTearDown(account.dispose);
        final storage = Storage()..pending = Completer<List<Cat>>();
        final coordinator = CatalogSyncCoordinator(
          account,
          storage,
          Synced(account),
          VisionApiService(account),
        );
        final pending = coordinator.synchronize();
        await Future<void>.delayed(Duration.zero);
        account.owner = nextOwner;
        storage.pending!.complete([]);
        expect(await pending, isNull);
      },
    );
  }
  test(
    'SEC07 permanent 401 stops after one refresh and two requests',
    () async {
      final account = Account();
      addTearDown(account.dispose);
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls > 2) {
          throw const SocketException('test guard stops defective recursion');
        }
        return http.Response('', 401);
      });
      await expectLater(
        () => AuthenticatedApiClient(account, client).request(
          'GET',
          '/test',
          null,
          accepted: {200},
          error: (_) => Failure(),
          signInMessage: 'login',
          connectionMessage: 'offline',
        ),
        throwsA(isA<Failure>()),
      );
      expect(calls, 2);
      expect(account.refreshes, 1);
    },
  );
}
