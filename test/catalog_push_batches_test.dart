import 'dart:convert';

import 'package:catlogue/models/cat.dart';
import 'package:catlogue/services/catalog_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/campaign_resilience_test.dart' show Account, Storage;

class _Storage extends Storage {
  _Storage(this.cats);
  final List<Cat> cats;
  @override
  Future<List<Cat>> getCatsForSync(String ownerId) async => cats;
}

Cat _cat(int i, {String? target}) => Cat(
  id: '$i',
  individualId: target,
  captureNumber: i,
  photoPath: 'unused',
  capturedAt: DateTime.utc(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final count in [0, 1, 499, 500, 501, 1001]) {
    test(
      'push respects limit and preserves every operation at $count',
      () async {
        final account = Account();
        addTearDown(account.dispose);
        final storage = _Storage(List.generate(count, _cat));
        final batches = <List<dynamic>>[];
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            final operations = jsonDecode(request.body)['operations'] as List;
            expect(operations.length, lessThanOrEqualTo(500));
            batches.add(operations);
            return http.Response('{}', 200);
          }
          return http.Response('{"changes":[],"next_cursor":0}', 200);
        });
        expect(
          await http.runWithClient(
            () => CatalogSyncService(account, database: storage).sync(),
            () => client,
          ),
          true,
        );
        final ids = batches
            .expand((batch) => batch)
            .map((op) => op['client_id'])
            .toList();
        expect(ids, [for (var i = 0; i < count; i++) '$i']);
        expect(batches.length, (count / 500).ceil());
      },
    );
  }
  test('cross-batch identity chain is sent after its offline anchor', () async {
    final account = Account();
    addTearDown(account.dispose);
    final storage = _Storage([
      _cat(0, target: '500'),
      for (var i = 1; i < 500; i++) _cat(i),
      _cat(500, target: '501'),
      _cat(501),
    ]);
    final known = <String>{};
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        final ops = jsonDecode(request.body)['operations'] as List;
        for (final op in ops) {
          final target = op['payload']['individual_id'];
          if (target != null) expect(known, contains(target));
          expect(known.add(op['client_id']), true);
        }
        return http.Response('{}', 200);
      }
      return http.Response('{"changes":[],"next_cursor":0}', 200);
    });
    expect(
      await http.runWithClient(
        () => CatalogSyncService(account, database: storage).sync(),
        () => client,
      ),
      true,
    );
    expect(known.length, 502);
  });
  for (final status in [401, 503]) {
    test(
      'second-batch $status preserves pending data and retries idempotently',
      () async {
        final account = Account();
        addTearDown(account.dispose);
        final storage = _Storage(List.generate(501, _cat));
        final service = CatalogSyncService(account, database: storage);
        var requests = 0, pulls = 0;
        final applied = <String>{};
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            final ops = jsonDecode(request.body)['operations'] as List;
            expect(ops.length, lessThanOrEqualTo(500));
            if (++requests == 2) return http.Response('{}', status);
            applied.addAll(ops.map((op) => op['client_id'] as String));
            return http.Response('{}', 200);
          }
          pulls++;
          return http.Response('{"changes":[],"next_cursor":0}', 200);
        });
        await http.runWithClient(() async {
          expect(await service.sync(), status == 401);
          expect(pulls, status == 401 ? 1 : 0);
          expect(storage.cats.length, 501);
          if (status == 503) expect(await service.sync(), true);
        }, () => client);
        expect(applied.length, 501);
        expect(account.refreshes, status == 401 ? 1 : 0);
      },
    );
  }
  test('cyclic identities cannot commit a partial multi-batch push', () async {
    final account = Account();
    addTearDown(account.dispose);
    final storage = _Storage([
      _cat(0, target: '1'),
      _cat(1, target: '0'),
      for (var i = 2; i <= 500; i++) _cat(i),
    ]);
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    expect(
      await http.runWithClient(
        () => CatalogSyncService(account, database: storage).sync(),
        () => client,
      ),
      false,
    );
    expect(calls, 0);
    expect(storage.cursor, '0');
  });
}
