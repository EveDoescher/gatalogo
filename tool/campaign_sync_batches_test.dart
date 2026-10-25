// Actual client/SQLite/HTTP against the campaign's disposable API only.
import 'dart:convert';
import 'dart:io';

import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Account extends SessionStore {
  _Account(this.options);
  final Map<String, dynamic> options;
  @override
  bool get isSignedIn => false;
  @override
  AuthSession get session => AuthSession(
    userId: options['owner'],
    email: 'batch@example.invalid',
    accessToken: options['token'],
    refreshToken: 'unused',
  );
  @override
  Future<String> deviceId() async => 'batch-fixture';
  @override
  Future<String?> accessToken({bool refresh = false}) async => options['token'];
}

class _Measured extends http.BaseClient {
  final http.Client delegate = IOClient();
  final List<Map<String, dynamic>> samples = [];
  bool failSecondPush;
  int pushes = 0;
  _Measured(this.failSecondPush);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final watch = Stopwatch()..start();
    final push = request.url.path == '/sync/push';
    final operations = push
        ? (jsonDecode((request as http.Request).body)['operations'] as List)
              .length
        : 0;
    final injected = push && ++pushes == 2 && failSecondPush;
    final reply = injected
        ? http.StreamedResponse(Stream.value(utf8.encode('{}')), 503)
        : await delegate.send(request);
    final bytes = await reply.stream.toBytes();
    samples.add({
      'method': request.method,
      'path_query':
          request.url.path +
          (request.url.hasQuery ? '?${request.url.query}' : ''),
      'operations': operations,
      'status': reply.statusCode,
      'request_bytes': request.contentLength,
      'response_bytes': bytes.length,
      'elapsed_us': watch.elapsedMicroseconds,
      'injected': injected,
    });
    return http.StreamedResponse(
      Stream.value(bytes),
      reply.statusCode,
      headers: reply.headers,
    );
  }

  @override
  void close() {} // HTTP helpers close borrowed clients after each request.

  void dispose() => delegate.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final options = jsonDecode(
    File(Platform.environment['QUALITY_SYNC_FIXTURES']!).readAsStringSync(),
  ) as Map<String, dynamic>;
  final accounts =
      jsonDecode(Platform.environment['QUALITY_SYNC_ACCOUNTS']!) as List;
  final variants = options['variants'] as List;
  for (var index = 0; index < variants.length; index++) {
    final variant = Map<String, dynamic>.from(variants[index]);
    for (var trial = 0; trial < (variant['trials'] as int); trial++) {
      test('LAT04 ${variant['name']} trial $trial', () async {
        HttpOverrides.global = null;
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final folder = Directory(
          p.join(options['root'], '${variant['name']}-$trial'),
        );
        await folder.create();
        await databaseFactory.setDatabasesPath(folder.path);
        final storage = CatDatabase();
        final db = await storage.database;
        final account = _Account(Map<String, dynamic>.from(accounts[index]));
        final client = _Measured(variant['failure'] == true);
        final photo = File(p.join(folder.path, 'private.png'));
        await photo.writeAsBytes([1, 2, 3]);
        final stamp = DateTime.parse(options['stamp']);
        final ids = (variant['ids'] as List).cast<String>();
        final batch = db.batch();
        for (var i = 0; i < ids.length; i++) {
          batch.insert(
            'cats',
            Cat(
              id: ids[i],
              captureNumber: i + 1,
              ownerId: account.session.userId,
              name: 'batch-$i',
              individualId: 'pending',
              photoPath: photo.path,
              capturedAt: stamp,
              localUpdatedAt: stamp,
              syncDeviceId: 'batch-fixture',
            ).toMap(),
          );
        }
        await batch.commit(noResult: true);
        final service = CatalogSyncService(account, database: storage);
        final cycles = <Map<String, dynamic>>[];
        final watch = Stopwatch()..start();
        try {
          await http.runWithClient(() async {
            final bound =
                (ids.length * (variant['history'] as int) / 200).ceil() + 4;
            for (var pass = 0; pass < bound; pass++) {
              final cycle = Stopwatch()..start();
              final ok = await service.sync();
              final rows = await storage.getCats(
                ownerId: account.session.userId,
              );
              final dirty = rows
                  .where((cat) => cat.syncState != 'synced')
                  .length;
              cycles.add({
                'ok': ok,
                'elapsed_us': cycle.elapsedMicroseconds,
                'dirty': dirty,
                'cursor': await storage.getSyncCursor(account.session.userId),
              });
              if (pass == 0 && variant['failure'] == true) {
                expect(ok, false);
                expect(dirty, ids.length);
                expect(
                  await storage.getSyncCursor(account.session.userId),
                  '0',
                );
                continue;
              }
              expect(
                ok,
                true,
                reason: 'All metadata requests must respect API limit',
              );
              if (dirty == 0) break;
            }
          }, () => client);
          final rows = await storage.getCats(ownerId: account.session.userId);
          expect(rows.length, ids.length);
          expect(rows.map((cat) => cat.id).toSet(), ids.toSet());
          expect(rows.every((cat) => cat.syncState == 'synced'), true);
          expect(rows.map((cat) => cat.name).toSet(), {
            for (var i = 0; i < ids.length; i++) 'batch-$i',
          });
          expect(await photo.readAsBytes(), [1, 2, 3]);
          expect(
            client.samples.where((s) => s['operations'] as int > 500),
            isEmpty,
          );
        } finally {
          await File(p.join(folder.path, 'metrics.json')).writeAsString(
            jsonEncode({
              'variant': variant['name'],
              'trial': trial,
              'cycles': cycles,
              'requests': client.samples,
              'elapsed_us': watch.elapsedMicroseconds,
              'rss_bytes_observed': ProcessInfo.currentRss,
            }),
          );
          client.dispose();
          account.dispose();
          await db.close();
        }
      });
    }
  }
}
