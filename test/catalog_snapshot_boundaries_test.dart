import 'dart:convert';
import 'dart:io';

import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/services/catalog_sync_coordinator.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/services/vision_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../tool/campaign_probe_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final count in [0, 1, 40, 499, 500, 501, 2000]) {
    for (final guest in [false, true]) {
      test(
        'DB01 real coordinator snapshot count=$count guest=$guest',
        () async {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          final folder = await Directory.systemTemp.createTemp(
            'gatalogo-db01-',
          );
          final root = await Directory.systemTemp.resolveSymbolicLinks();
          final target = await folder.resolveSymbolicLinks();
          expect(p.isWithin(root, target), isTrue);
          await databaseFactory.setDatabasesPath(target);
          final storage = CatDatabase();
          final real = await storage.database;
          final account = fixture.Account();
          try {
            final cats = <Cat>[];
            final analyses = <String, Map<String, dynamic>>{};
            final references = <String, List<Map<String, dynamic>>>{};
            final ids = [
              ...List.generate(count, (i) => 'a-$i'),
              if (guest) 'guest',
              'foreign',
              'deleted',
            ];
            final stamp = DateTime.utc(2026, 10, 25);
            final batch = real.batch();
            for (var i = 0; i < ids.length; i++) {
              final id = ids[i];
              final cat = Cat(
                id: id,
                captureNumber: i + 1,
                photoPath: '$id.png',
                capturedAt: stamp.add(Duration(seconds: i)),
                localUpdatedAt: stamp,
                ownerId: id == 'guest'
                    ? null
                    : id == 'foreign'
                    ? 'b'
                    : 'a',
                name: 'cat-$id',
                syncState: 'synced',
                deletedAt: id == 'deleted' ? stamp : null,
              );
              cats.add(cat);
              batch.insert('cats', cat.toMap());
              if (i.isEven) {
                final analysis = CatAnalysis(
                  catId: id,
                  status: AnalysisStatus.completed,
                  coatType: 'coat-$id',
                  analyzedAt: stamp,
                  patternMap: {'future_field': 'preserved'},
                ).toMap();
                analyses[id] = analysis;
                batch.insert('cat_analyses', analysis);
              }
              references[id] = [];
              if (i % 3 != 0) {
                for (final kind in [
                  'right',
                  'front',
                  'back',
                  'left',
                  'obsolete',
                ]) {
                  final ref = CatReferencePhoto(
                    catId: id,
                    kind: kind,
                    localPath: '$id/$kind.png',
                    status: 'ready',
                    updatedAt: stamp,
                    syncState: 'synced',
                    deletedAt: kind == 'obsolete' ? stamp : null,
                  );
                  batch.insert('cat_reference_photos', ref.toMap());
                  if (kind != 'obsolete') references[id]!.add(ref.toMap());
                }
                references[id]!.sort(
                  (a, b) =>
                      (a['kind'] as String).compareTo(b['kind'] as String),
                );
              }
            }
            await batch.commit(noResult: true);
            final counted = fixture.Counted(real);
            final measured = CatDatabase.withConnection(() async => counted);
            final coordinator = CatalogSyncCoordinator(
              account,
              measured,
              CatalogSyncService(account, database: measured),
              VisionApiService(account),
            );
            for (final owner in ['a', null, 'b']) {
              final expected =
                  cats
                      .where(
                        (c) =>
                            c.deletedAt == null &&
                            (c.ownerId == null ||
                                (owner != null && c.ownerId == owner)),
                      )
                      .toList()
                    ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
              counted.reads = 0;
              final watch = Stopwatch()..start();
              final result = await coordinator.read(owner);
              watch.stop();
              final queries = expected.isEmpty
                  ? 1
                  : 1 + 2 * (expected.length / 500).ceil();
              expect(counted.reads, queries);
              expect(result.ownerId, owner);
              expect(
                result.cats.map((c) => c.toMap()).toList(),
                expected.map((c) => c.toMap()).toList(),
              );
              expect(
                {for (final a in result.analyses) a.catId: a.toMap()},
                {
                  for (final c in expected)
                    if (analyses.containsKey(c.id)) c.id: analyses[c.id],
                },
              );
              expect(
                {
                  for (final entry in result.references.entries)
                    entry.key: entry.value.map((r) => r.toMap()).toList(),
                },
                {for (final c in expected) c.id: references[c.id]},
              );
            debugPrintSynchronously(
                jsonEncode({
                  'scenario': 'DB-01',
                  'owned': count,
                  'guest': guest,
                  'owner': owner,
                  'visible': expected.length,
                  'selects': counted.reads,
                  'elapsed_us': watch.elapsedMicroseconds,
                  'cache': 'warm from fixture creation; no cold IO claim',
                }),
              );
            }
            final first = cats.first;
            expect(
              Cat.fromMap({...first.toMap(), 'future_unknown_field': 'ignored'})
                  .toMap(),
              first.toMap(),
            );
          } finally {
            account.dispose();
            await real.close();
            expect(
              p.isWithin(root, await folder.resolveSymbolicLinks()),
              isTrue,
            );
            await folder.delete(recursive: true);
          }
        },
      );
    }
  }
}
