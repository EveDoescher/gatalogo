import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/cat.dart';

void main() {
  late Directory folder;
  final storage = CatDatabase.instance;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    folder = await Directory.systemTemp.createTemp('gatalogo-db-test-');
    await databaseFactory.setDatabasesPath(folder.path);
  });
  tearDownAll(() async {
    await (await storage.database).close();
    await folder.delete(recursive: true);
  });
  test('private local records are isolated between accounts', () async {
    for (final owner in [null, 'a', 'b']) {
      await storage.insertCat(
        Cat(
          id: owner ?? 'local',
          captureNumber: 1,
          photoPath: 'photo.jpg',
          capturedAt: DateTime(2026),
          ownerId: owner,
          isOwned: owner == 'a',
        ),
      );
    }
    expect((await storage.getCats()).map((cat) => cat.id), ['local']);
    expect((await storage.getCats(ownerId: 'a')).map((cat) => cat.id).toSet(), {
      'local',
      'a',
    });
    await storage.bindUnownedCatsToAccount('a', 'device');
    expect(await storage.getCats(), isEmpty);
    expect((await storage.getCatById('a'))!.isOwned, isTrue);
  });
  test('an offline removal remains a syncable tombstone', () async {
    await storage.markDeleted('a', 'a', 'device');
    expect(
      (await storage.getCats(ownerId: 'a')).any((cat) => cat.id == 'a'),
      isFalse,
    );
    final pending = await storage.getCatsForSync('a');
    expect(pending.firstWhere((cat) => cat.id == 'a').deletedAt, isNotNull);
  });
  test(
    'queued sighting persists its location date and note until acknowledged',
    () async {
      await storage.queueSighting({
        'cat_client_id': 'local',
        'latitude': -23.5,
        'longitude': -46.6,
        'observed_at': '2026-09-08T10:00:00Z',
        'note': 'Perto da praça',
      });
      final queued = await storage.queuedSightings();
      expect(queued.single['note'], 'Perto da praça');
      expect(queued.single['latitude'], -23.5);
      await storage.removeQueuedSighting(queued.single['queue_key'] as String);
      expect(await storage.queuedSightings(), isEmpty);
    },
  );
}
