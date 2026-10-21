import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/services/catalog_sync_coordinator.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/services/vision_api_service.dart';
import 'package:catlogue/stores/session_store.dart';

class CountingDatabase implements Database {
  CountingDatabase(this.delegate);
  final Database delegate;
  int reads = 0;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    reads++;
    return delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late CatDatabase original;
  late CatDatabase storage;
  late Database db;
  late CountingDatabase counted;
  late SessionStore session;
  late CatalogSyncCoordinator coordinator;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    folder = await Directory.systemTemp.createTemp('gatalogo-perf-test-');
    await databaseFactory.setDatabasesPath(folder.path);
    original = CatDatabase();
    db = await original.database;
    counted = CountingDatabase(db);
    storage = CatDatabase.withConnection(() async => counted);
    session = SessionStore();
    coordinator = CatalogSyncCoordinator(
      session,
      storage,
      CatalogSyncService(session, database: storage),
      VisionApiService(session),
    );
  });
  setUp(() async {
    await db.delete('cat_analyses');
    await db.delete('cat_reference_photos');
    await db.delete('cats');
    counted.reads = 0;
  });
  tearDownAll(() async {
    session.dispose();
    await db.close();
    expect(
      p.isWithin(Directory.systemTemp.absolute.path, folder.absolute.path),
      isTrue,
    );
    await folder.delete(recursive: true);
  });
  for (final count in [1, 40, 501]) {
    test(
      'snapshot preserves content and account boundaries for $count cats with bounded queries',
      () async {
        final batch = db.batch();
        for (final id in [
          ...List.generate(count, (i) => 'a-$i'),
          'guest',
          'foreign',
          'deleted',
        ]) {
          final cat = Cat(
            id: id,
            captureNumber: 1,
            photoPath: '$id.jpg',
            capturedAt: DateTime(2026),
            ownerId: id == 'guest'
                ? null
                : id == 'foreign'
                ? 'b'
                : 'a',
            deletedAt: id == 'deleted' ? DateTime(2026) : null,
          );
          batch.insert('cats', cat.toMap());
          batch.insert(
            'cat_analyses',
            CatAnalysis(
              catId: id,
              status: AnalysisStatus.completed,
              coatType: 'Rajado',
            ).toMap(),
          );
          for (final kind in ['left', 'front', 'back']) {
            batch.insert(
              'cat_reference_photos',
              CatReferencePhoto(
                catId: id,
                kind: kind,
                localPath: '$id/$kind.jpg',
                status: 'ready',
                updatedAt: DateTime.utc(2026),
                deletedAt: kind == 'back' ? DateTime.utc(2026) : null,
              ).toMap(),
            );
          }
        }
        await batch.commit(noResult: true);
        final cats = await original.getCats(ownerId: 'a');
        final ids = cats.map((cat) => cat.id).toSet();
        final expectedAnalyses = {
          for (final a in await original.getAnalyses())
            if (ids.contains(a.catId)) a.catId: a.toMap(),
        };
        final expectedReferences = {
          for (final id in ids)
            id: (await original.getReferencePhotos(id))
                .map((p) => p.toMap())
                .toList(),
        };
        final snapshot = await coordinator.read('a');
        expect(
          snapshot.cats.map((cat) => cat.toMap()).toList(),
          cats.map((cat) => cat.toMap()).toList(),
        );
        expect({
          for (final a in snapshot.analyses) a.catId: a.toMap(),
        }, expectedAnalyses);
        expect({
          for (final e in snapshot.references.entries)
            e.key: e.value.map((p) => p.toMap()).toList(),
        }, expectedReferences);
        expect(snapshot.ownerId, 'a');
        expect(snapshot.references.keys, isNot(contains('foreign')));
        expect(snapshot.references.keys, isNot(contains('deleted')));
        final batches = (ids.length / 500).ceil();
        expect(counted.reads, 1 + 2 * batches);
        counted.reads = 0;
        final duplicateIds = [...ids, ids.first, 'absent'];
        expect(
          (await storage.getAnalysesForCats(duplicateIds)).length,
          ids.length,
        );
        expect(
          (await storage.getReferencePhotosForCats(duplicateIds))['absent'],
          isEmpty,
        );
        expect(counted.reads, 2 * ((ids.length + 1) / 500).ceil());
      },
    );
  }
  test(
    'empty snapshots read only cats and empty batch selections never query',
    () async {
      final snapshot = await coordinator.read('a');
      expect(snapshot.cats, isEmpty);
      expect(snapshot.analyses, isEmpty);
      expect(snapshot.references, isEmpty);
      expect(counted.reads, 1);
      counted.reads = 0;
      expect(await storage.getAnalysesForCats([]), isEmpty);
      expect(await storage.getReferencePhotosForCats([]), isEmpty);
      expect(counted.reads, 0);
    },
  );
}
