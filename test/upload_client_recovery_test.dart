import 'dart:convert';
import 'dart:io';

import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../tool/campaign_resilience_test.dart' show Account;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final window in ['before-commit', 'after-commit']) {
    test(
      'RES02 client $window upload disconnect retains photo and retries after SQLite reopen',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final folder = await Directory.systemTemp.createTemp('gatalogo-res02-');
        await databaseFactory.setDatabasesPath(folder.path);
        final photo = File(p.join(folder.path, 'synthetic.png'));
        await photo.writeAsBytes([1, 2, 3]);
        var storage = CatDatabase();
        var db = await storage.database;
        final stamp = DateTime.utc(2026, 10, 25);
        await storage.insertCat(
          Cat(
            id: 'cat',
            ownerId: 'a',
            captureNumber: 1,
            photoPath: photo.path,
            capturedAt: stamp,
            status: 'completed',
          ),
        );
        final account = Account();
        var puts = 0, pulls = 0;
        var remoteBytes = [9, 9, 9];
        final client = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic');
          if (request.method == 'POST') return http.Response('{}', 200);
          if (request.method == 'PUT') {
            puts++;
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data'),
            );
            expect(
              latin1.decode(request.bodyBytes),
              contains(latin1.decode([1, 2, 3])),
            );
            if (puts == 1) {
              if (window == 'after-commit') remoteBytes = [1, 2, 3];
              throw http.ClientException('Controlled response loss');
            }
            remoteBytes = [1, 2, 3];
            return http.Response('', 204);
          }
          pulls++;
          return http.Response(
            jsonEncode({
              'next_cursor': 1,
              'changes': [
                {
                  'client_id': 'cat',
                  'revision': 1,
                  'updated_at': stamp.toIso8601String(),
                  'payload': {'status': 'completed', 'capture_number': 1},
                  'reference_photos': [],
                },
              ],
            }),
            200,
          );
        });
        try {
          await http.runWithClient(() async {
            expect(
              await CatalogSyncService(account, database: storage).sync(),
              false,
            );
            expect(pulls, 0);
            expect(await storage.getSyncCursor('a'), '0');
            expect((await storage.getCatById('cat'))!.syncState, 'dirty');
            expect(await photo.readAsBytes(), [1, 2, 3]);
            expect(
              remoteBytes,
              window == 'after-commit' ? [1, 2, 3] : [9, 9, 9],
            );
            await db.close();
            storage = CatDatabase();
            db = await storage.database;
            expect((await storage.getCatById('cat'))!.syncState, 'dirty');
            expect(
              await CatalogSyncService(account, database: storage).sync(),
              true,
            );
          }, () => client);
          expect(puts, 2);
          expect(pulls, 1);
          expect(remoteBytes, [1, 2, 3]);
          expect(await photo.readAsBytes(), [1, 2, 3]);
          expect(await storage.getSyncCursor('a'), '1');
          expect((await storage.getCatById('cat'))!.syncState, 'synced');
        } finally {
          if (db.isOpen) await db.close();
          account.dispose();
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
