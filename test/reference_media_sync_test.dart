import 'dart:convert';
import 'dart:io';

import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../tool/campaign_resilience_test.dart' show Account;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final variant in [
    'same',
    'new-same-timestamp',
    'status-only',
    'removed',
    'dirty-during-pull',
    'http403',
    'http404',
  ]) {
    test(
      'IMG03 reference $variant preserves authorized bytes across offline reopen',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final folder = await Directory.systemTemp.createTemp('gatalogo-img03-');
        await databaseFactory.setDatabasesPath(folder.path);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        messenger.setMockMethodCallHandler(channel, (_) async => folder.path);
        final storage = CatDatabase();
        final db = await storage.database;
        final account = Account();
        final stamp = DateTime.utc(2026, 10, 25);
        final primary = File(p.join(folder.path, 'primary.png'));
        await primary.writeAsBytes([9, 8, 7]);
        final reference = File(
          p.join(folder.path, 'cats', 'cat', 'references', 'front.jpg'),
        );
        await reference.parent.create(recursive: true);
        await reference.writeAsBytes([1, 2, 3]);
        await storage.insertCat(
          Cat(
            id: 'cat',
            ownerId: 'a',
            captureNumber: 1,
            photoPath: primary.path,
            capturedAt: stamp,
            syncState: 'synced',
          ),
        );
        CatReferencePhoto local(String state) => CatReferencePhoto(
          catId: 'cat',
          kind: 'front',
          localPath: reference.path,
          updatedAt: stamp,
          status: 'ready',
          syncState: state,
        );
        await storage.upsertReferencePhoto(local('synced'));
        final changed =
            variant == 'new-same-timestamp' || variant.startsWith('http');
        final expected = changed ? [4, 5, 6] : [1, 2, 3];
        var downloads = 0;
        var fault = variant.startsWith('http');
        final client = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic');
          if (request.url.path == '/sync/pull') {
            if (variant == 'dirty-during-pull') {
              await storage.upsertReferencePhoto(local('dirty'));
            }
            return http.Response(
              jsonEncode({
                'next_cursor': 1,
                'changes': [
                  {
                    'client_id': 'cat',
                    'revision': 1,
                    'updated_at': stamp.toIso8601String(),
                    'device_id': 'server',
                    'payload': {
                      'name': 'preserved',
                      'status': 'pending_analysis',
                    },
                    'reference_photos': variant == 'removed'
                        ? []
                        : [
                            {
                              'kind': 'front',
                              'photo_url': '/private/front',
                              'updated_at': stamp.toIso8601String(),
                              'status': variant == 'status-only'
                                  ? 'analyzing'
                                  : 'ready',
                            },
                          ],
                  },
                ],
              }),
              200,
            );
          }
          expect(request.url.path, '/private/front');
          downloads++;
          return http.Response.bytes(
            fault ? [] : expected,
            fault ? int.parse(variant.substring(4)) : 200,
          );
        });
        try {
          await http.runWithClient(() async {
            final service = CatalogSyncService(account, database: storage);
            if (fault) {
              expect(
                await service.sync(),
                false,
                reason: 'A failed reference must not consume the revision',
              );
              expect(await storage.getSyncCursor('a'), '0');
              expect(await reference.readAsBytes(), [1, 2, 3]);
              fault = false;
            }
            expect(await service.sync(), true);
          }, () => client);
          expect(await storage.getSyncCursor('a'), '1');
          expect(
            downloads,
            variant == 'removed' || variant == 'dirty-during-pull'
                ? 0
                : variant.startsWith('http')
                ? 2
                : 1,
          );
          expect(await primary.readAsBytes(), [9, 8, 7]);
          await db.close();
          final reopened = CatDatabase();
          try {
            final photos = await reopened.getReferencePhotos('cat');
            if (variant == 'removed') {
              expect(photos, isEmpty);
            } else {
              expect(photos.length, 1);
              expect(
                await File(photos.single.localPath).readAsBytes(),
                expected,
              );
              expect(
                photos.single.status,
                variant == 'status-only' ? 'analyzing' : 'ready',
              );
              expect(
                photos.single.syncState,
                variant == 'dirty-during-pull' ? 'dirty' : 'synced',
              );
            }
            expect(await reopened.getSyncCursor('a'), '1');
          } finally {
            await (await reopened.database).close();
          }
        } finally {
          if (db.isOpen) await db.close();
          account.dispose();
          messenger.setMockMethodCallHandler(channel, null);
          expect(
            p.isWithin(
              await Directory.systemTemp.resolveSymbolicLinks(),
              await folder.resolveSymbolicLinks(),
            ),
            true,
          );
          await folder.delete(recursive: true);
        }
      },
    );
  }
}
