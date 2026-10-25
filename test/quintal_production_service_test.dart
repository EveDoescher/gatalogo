import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';

class _Account extends SessionStore {
  String? id = 'one';
  @override
  bool get isSignedIn => id != null;
  @override
  AuthSession? get session => id == null
      ? null
      : AuthSession(
          userId: id!,
          email: 'qa@test.local',
          accessToken: 'test',
          refreshToken: 'test',
        );
}

class _Store extends CatStore {
  _Store(super.session);
  @override
  Future<void> refreshGamification() async {}
}

class _Database implements CatDatabase {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> readHabitatCache(String owner) async =>
      values[owner] == null ? null : {'snapshot': values[owner]};
  @override
  Future<void> saveHabitatSnapshot(
    String owner,
    Map<String, dynamic> value,
  ) async {
    values[owner] = value;
  }

  @override
  Future<void> saveHabitatDraft(
    String owner,
    Map<String, dynamic>? value,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, dynamic> state(int amount) => {
  'production': {
    'server_now': DateTime.now().toUtc().toIso8601String(),
    'stock': {'corn': amount},
    'catalog': {},
    'cats': [],
  },
  'habitat': {
    'items': [],
    'cats': [],
    'selected_cat_ids': [],
    'balance': 0,
    'revision': amount,
  },
  'outcome': {},
  'progress': {},
};

class _Api extends ProductApiService {
  _Api(super.session);
  Completer<Map<String, dynamic>>? delayedGet, delayedPost;
  bool fail = false;
  Map<String, dynamic>? currentState;
  Map<String, dynamic>? careResponse;
  final keys = <String>[];
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/app/quintal') {
      return delayedGet?.future ?? currentState ?? state(0);
    }
    return path.endsWith('/shop')
        ? {'items': []}
        : Map<String, dynamic>.from(state(0)['habitat'] as Map);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    keys.add(body!['idempotency_key'].toString());
    if (fail) {
      fail = false;
      throw const ProductApiException('Sem conexão');
    }
    return delayedPost?.future ??
        (path == '/app/habitat/interactions' && careResponse != null
            ? careResponse!
            : currentState ?? state(10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final boundary in ['switch', 'logout', 'dispose']) {
    for (final method in ['load', 'produce']) {
      test('RES03 Quintal late $method after $boundary is ignored', () async {
        final account = _Account(), db = _Database();
        final store = _Store(account), api = _Api(account);
        final habitat = HabitatService(account, store, database: db, api: api);
        var disposed = false;
        try {
          await habitat.load();
          final pending = Completer<Map<String, dynamic>>();
          if (method == 'load') {
            api.delayedGet = pending;
          } else {
            api.delayedPost = pending;
          }
          Object? failure;
          final request =
              (method == 'load'
                      ? habitat.load()
                      : habitat.produce('harvest', '0').then<void>((_) {}))
                  .catchError((Object error) {
                    failure = error;
                  });
          await Future<void>.delayed(Duration.zero);
          if (boundary == 'dispose') {
            habitat.dispose();
            disposed = true;
          } else {
            account.id = boundary == 'switch' ? 'two' : null;
            api.delayedGet = null;
            api.currentState = state(2);
            await habitat.load();
          }
          final beforeStock = Map<String, int>.from(habitat.productionStock);
          final beforeCache = Map<String, Map<String, dynamic>>.from(db.values);
          pending.complete(state(999));
          await request;
          expect(
            failure == null || failure is ProductApiException,
            isTrue,
            reason:
                'Disposed notifier must not receive a late update: $failure',
          );
          expect(habitat.productionStock, beforeStock);
          expect(db.values, beforeCache);
        } finally {
          if (!disposed) habitat.dispose();
          store.dispose();
          account.dispose();
        }
      });
    }
  }
  test('pet response updates affinity immediately and persists across restart', () async {
    final a = _Account(), db = _Database();
    final store = _Store(a), api = _Api(a);
    final h = HabitatService(a, store, database: db, api: api);
    await h.load();
    h.production = {
      ...h.production,
      'cats': [
        {'cat_id': 'cat', 'affinity': 12},
      ],
    };
    api.careResponse = {
      ...Map<String, dynamic>.from(state(13)['habitat'] as Map),
      'care': {
        'cats': {
          'cat': {'affinity': 13},
        },
      },
      'production': {
        ...Map<String, dynamic>.from(state(13)['production'] as Map),
        'cats': [
          {'cat_id': 'cat', 'affinity': 13},
        ],
      },
    };
    api.delayedGet = Completer();
    final stale = h.refreshProduction();
    await Future<void>.delayed(Duration.zero);
    await h.interact('pet', 'cat');
    expect(h.affinity('cat'), 13);
    api.delayedGet!.complete(state(0));
    await stale;
    expect(h.affinity('cat'), 13);
    expect((db.values['one']!['production'] as Map)['cats'][0]['affinity'], 13);
    h.dispose();
    final restored = HabitatService(a, store, database: db, api: api);
    api.fail = true;
    // Inspect the durable cache through load even when the refresh is pending.
    api.delayedGet = Completer();
    final loading = restored.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.affinity('cat'), 13);
    api.delayedGet!.complete({
      'production': api.careResponse!['production'],
      'habitat': state(13)['habitat'],
    });
    await loading;
    expect(restored.affinity('cat'), 13);
    restored.dispose();
    store.dispose();
    a.dispose();
  });
  test('reward receipts persist, refresh replaces the queue, and stale accounts cannot restore it', () async {
    final account = _Account(), db = _Database();
    final store = _Store(account), api = _Api(account);
    final receipt = {
      'id': 'qreward:one',
      'kind': 'progress',
      'bonuses': [
        {
          'id': 'start_harvest',
          'title': 'Primeira colheita',
          'xp': 20,
          'coins': 10,
        },
      ],
      'items': [],
    };
    final secondReceipt = {...receipt, 'id': 'qreward:two'};
    api.currentState = {
      ...state(10),
      'progress': {
        'celebrations': [receipt, secondReceipt],
      },
    };
    final h = HabitatService(account, store, database: db, api: api);
    await h.load();
    expect(h.pendingProductionRewards.length, 2);
    await h.refreshProduction();
    expect(h.pendingProductionRewards.length, 2);
    h.dispose();
    final restored = HabitatService(account, store, database: db, api: api);
    api.delayedGet = Completer();
    final loading = restored.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.pendingProductionRewards.first['id'], receipt['id']);
    api.delayedGet!.complete(api.currentState!);
    await loading;
    api.delayedGet = Completer();
    final stale = restored.refreshProduction();
    await Future<void>.delayed(Duration.zero);
    api.fail = true;
    await expectLater(
      restored.acknowledgeProductionReward(receipt['id'] as String),
      throwsA(isA<ProductApiException>()),
    );
    expect(restored.pendingProductionRewards.length, 2);
    api.currentState = {
      ...state(10),
      'progress': {
        'celebrations': [secondReceipt],
      },
    };
    await restored.acknowledgeProductionReward(receipt['id'] as String);
    expect(api.keys[0], api.keys[1]);
    api.delayedGet!.complete({
      ...state(999),
      'progress': {
        'celebrations': [receipt, secondReceipt],
      },
    });
    await stale;
    expect(restored.pendingProductionRewards.single['id'], secondReceipt['id']);
    expect(restored.productionStock['corn'], 10);
    expect(
      (db.values['one']!['last_production_progress'] as Map)['celebrations'],
      [secondReceipt],
    );
    api.delayedGet = null;
    api.delayedPost = Completer();
    final oldAck = restored.acknowledgeProductionReward(
      secondReceipt['id'] as String,
    );
    final rejected = expectLater(oldAck, throwsA(isA<ProductApiException>()));
    await Future<void>.delayed(Duration.zero);
    account.id = 'two';
    api.currentState = state(0);
    await restored.load();
    api.delayedPost!.complete({
      ...state(10),
      'progress': {
        'celebrations': [receipt],
      },
    });
    await rejected;
    expect(restored.pendingProductionRewards, isEmpty);
    expect(
      (db.values['two']?['last_production_progress'] as Map?) ?? {},
      isEmpty,
    );
    restored.dispose();
    store.dispose();
    account.dispose();
  });
  test('a retry after restart retains its operation key', () async {
    final a = _Account(), db = _Database();
    final store = _Store(a), api = _Api(a);
    final first = HabitatService(a, store, database: db, api: api);
    await first.load();
    api.fail = true;
    await expectLater(
      first.produce('plant', '0', {'crop': 'corn'}),
      throwsA(isA<ProductApiException>()),
    );
    first.dispose();
    final second = HabitatService(a, store, database: db, api: api);
    await second.load();
    await second.produce('plant', '0', {'crop': 'corn'});
    expect(api.keys.length, 2);
    expect(api.keys[0], api.keys[1]);
    expect(second.productionStock['corn'], 10);
    second.dispose();
    store.dispose();
    a.dispose();
  });
  test('an older projection cannot overwrite a completed action', () async {
    final a = _Account(), db = _Database();
    final store = _Store(a), api = _Api(a);
    final h = HabitatService(a, store, database: db, api: api);
    await h.load();
    api.delayedGet = Completer();
    final stale = h.refreshProduction();
    await Future<void>.delayed(Duration.zero);
    await h.produce('harvest', '0');
    api.delayedGet!.complete(state(999));
    await stale;
    expect(h.productionStock['corn'], 10);
    h.dispose();
    store.dispose();
    a.dispose();
  });
  test(
    'a response from a former account cannot change the new account',
    () async {
      final a = _Account(), db = _Database();
      final store = _Store(a), api = _Api(a);
      final h = HabitatService(a, store, database: db, api: api);
      await h.load();
      api.delayedPost = Completer();
      final request = h.produce('harvest', '0');
      final rejected = expectLater(
        request,
        throwsA(isA<ProductApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      a.id = 'two';
      await h.load();
      api.delayedPost!.complete(state(999));
      await rejected;
      expect(h.productionStock['corn'], isNull);
      expect(db.values['two']?['production'], isEmpty);
      h.dispose();
      store.dispose();
      a.dispose();
    },
  );
}
