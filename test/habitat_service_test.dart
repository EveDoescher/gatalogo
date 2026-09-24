import 'dart:async';

import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _Account extends SessionStore {
  @override
  bool get isSignedIn => true;

  @override
  AuthSession get session => AuthSession(
    userId: 'account',
    email: 'account@example.com',
    accessToken: 'test',
    refreshToken: 'test',
  );
}

class _HabitatDatabase implements CatDatabase {
  Map<String, String> pending = {};
  Map<String, dynamic>? draft;
  Map<String, dynamic>? snapshot;

  @override
  Future<Map<String, dynamic>?> readHabitatCache(String ownerId) async => {
    if (snapshot != null) 'snapshot': snapshot,
    if (draft != null) 'draft': draft,
  };

  @override
  Future<void> saveHabitatDraft(
    String ownerId,
    Map<String, dynamic>? value,
  ) async {
    draft = value;
  }

  @override
  Future<void> saveHabitatPendingPurchases(
    String ownerId,
    Map<String, String> pendingPurchases,
  ) async {
    pending = Map.of(pendingPurchases);
  }

  @override
  Future<void> saveHabitatSnapshot(
    String ownerId,
    Map<String, dynamic> value,
  ) async {
    snapshot = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PurchaseApi extends ProductApiService {
  _PurchaseApi(super.session);
  final keys = <String>[];

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    keys.add(body!['idempotency_key'] as String);
    if (keys.length == 1) {
      throw const ProductApiException('Conexão interrompida.');
    }
    return {
      'item': {
        'id': 'purchased',
        'sku': body['sku'],
        'x': null,
        'y': null,
        'rotation': 0,
      },
      'balance': 10,
    };
  }
}

class _LayoutApi extends ProductApiService {
  _LayoutApi(super.session);
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  final requests = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    requests.add(body!);
    if (requests.length == 1) {
      firstStarted.complete();
      await releaseFirst.future;
    }
    final placement = (body['placements'] as List).single as Map;
    return {
      'balance': 0,
      'revision': (body['expected_revision'] as int) + 1,
      'items': [
        {
          'id': 'bed',
          'sku': 'cat_bed',
          'x': placement['x'],
          'y': placement['y'],
          'rotation': 0,
        },
      ],
      'cats': [],
      'selected_cat_ids': [],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'placement respects occupied cells, item footprint and scene capacity',
    () {
      final session = SessionStore();
      final service = HabitatService(session, CatStore(session));
      service.items = [
        const HabitatItem(id: 'oak', sku: 'oak_tree', x: 2, y: 2),
        const HabitatItem(id: 'bed', sku: 'cat_bed'),
      ];

      expect(service.canPlace(service.items[1], 3, 3, 0), isFalse);
      expect(service.canPlace(service.items[1], 4, 3, 0), isTrue);
      expect(service.canPlace(service.items[0], 7, 7, 0), isFalse);
      expect(service.canPlace(service.items[0], 5, 5, 1), isTrue);

      service.items = [
        for (var index = 0; index < 24; index++)
          HabitatItem(
            id: '$index',
            sku: 'cat_bed',
            x: index % 8,
            y: index ~/ 8,
          ),
        const HabitatItem(id: 'extra', sku: 'cat_bed'),
      ];
      expect(service.canPlace(service.items.last, 7, 7, 0), isFalse);
      service.dispose();
    },
  );

  test('purchase retry reuses the saved idempotency key', () async {
    final session = _Account();
    final database = _HabitatDatabase();
    final api = _PurchaseApi(session);
    final service = HabitatService(
      session,
      CatStore(session),
      database: database,
      api: api,
    );

    await expectLater(
      service.buy('yellow_flowers'),
      throwsA(isA<ProductApiException>()),
    );
    expect(database.pending['yellow_flowers:1'], api.keys.single);
    await service.buy('yellow_flowers');
    expect(api.keys[0], api.keys[1]);
    expect(service.items.single.id, 'purchased');
    expect(service.balance, 10);
    expect(database.pending, isEmpty);
    service.dispose();
    session.dispose();
  });

  test('directional footprints rotate while cottages remain fixed', () {
    final session = SessionStore();
    final service = HabitatService(session, CatStore(session));
    service.items = [
      const HabitatItem(id: 'log', sku: 'large_log'),
      const HabitatItem(id: 'cottage', sku: 'green_cottage'),
      const HabitatItem(id: 'bush', sku: 'small_bush', x: 2, y: 3),
    ];
    expect(service.canPlace(service.items[0], 1, 2, 0), isTrue);
    expect(service.canPlace(service.items[0], 1, 2, 1), isTrue);
    expect(service.canPlace(service.items[0], 2, 2, 1), isFalse);
    expect(service.canPlace(service.items[1], 3, 3, 1), isFalse);
    expect(service.definition('cat_bed').width, 1);
    expect(service.definition('cat_bed').height, 2);
    expect(service.definition('floor_bed').height, 2);
    service.dispose();
    session.dispose();
  });

  test('bed collision cells follow its long axis in all four orientations', () {
    final session = SessionStore();
    final service = HabitatService(session, CatStore(session));
    const bed = HabitatItem(id: 'bed', sku: 'cat_bed');
    for (var rotation = 0; rotation < 4; rotation++) {
      service.items = [
        bed,
        const HabitatItem(id: 'bush', sku: 'small_bush', x: 3, y: 4),
      ];
      expect(service.canPlace(bed, 3, 3, rotation), rotation.isOdd);
      service.items = [
        bed,
        const HabitatItem(id: 'bush', sku: 'small_bush', x: 4, y: 3),
      ];
      expect(service.canPlace(bed, 3, 3, rotation), rotation.isEven);
    }
    service.dispose();
    session.dispose();
  });

  test(
    'offline cache and draft migrate bed axes without losing placed items',
    () async {
      final session = SessionStore();
      final database = _HabitatDatabase();
      final service = HabitatService(
        session,
        CatStore(session),
        database: database,
      );
      database.snapshot = {
        'layout_rules_version': 2,
        'shop': service.shop
            .map(
              (item) => {
                ...item.toMap(),
                if (item.sku == 'cat_bed') ...{'width': 2, 'height': 1},
              },
            )
            .toList(),
        'items': [
          const HabitatItem(id: 'bed', sku: 'cat_bed', x: 1, y: 1).toMap(),
          const HabitatItem(id: 'tree', sku: 'small_tree', x: 1, y: 2).toMap(),
        ],
        'selected_cat_ids': ['free', 'blocked'],
        'cat_anchors': {
          'free': [5, 5],
          'blocked': [1, 2],
        },
      };
      database.draft = {
        'placements': [
          {'item_id': 'bed', 'x': 1, 'y': 1, 'rotation': 0},
          {'item_id': 'tree', 'x': 1, 'y': 2, 'rotation': 0},
        ],
        'selected_cat_ids': ['free', 'blocked'],
        'cat_anchors': {
          'free': [5, 5],
          'blocked': [1, 2],
        },
      };
      await service.load();
      expect(service.definition('cat_bed').height, 2);
      expect(service.items.every((item) => item.isPlaced), isTrue);
      expect((service.items.last.x, service.items.last.y), isNot((1, 2)));
      expect(service.catAnchors['free'], (5, 5));
      final movedCat = service.catAnchors['blocked']!;
      expect(service.isFreeForCat(movedCat.$1, movedCat.$2), isTrue);
      expect(service.layoutAdjusted, isTrue);
      expect(database.snapshot!['layout_rules_version'], 3);
      final saved = database.draft;
      await service.load();
      expect(database.draft, saved);
      service.dispose();
      session.dispose();
    },
  );

  test(
    'irregular expansions, separate path layer and stock-limited painting',
    () async {
      final session = SessionStore();
      final service = HabitatService(
        session,
        CatStore(session),
        database: _HabitatDatabase(),
      );
      expect(service.buildableCells.contains((0, -1)), isFalse);
      expect(service.buildableCells.contains((3, -1)), isTrue);
      service.items = [
        const HabitatItem(id: 'bed', sku: 'cat_bed', x: 1, y: 1),
        const HabitatItem(id: 'path-1', sku: 'pebble_path'),
        const HabitatItem(id: 'path-2', sku: 'pebble_path'),
        const HabitatItem(id: 'rock', sku: 'large_rock'),
      ];
      expect(service.canPlace(service.items[3], 1, 1, 0), isFalse);
      expect(service.canPlace(service.items[1], 1, 1, 0), isTrue);
      final painted = await service.paintPath('pebble_path', [
        (1, 1),
        (1, 2),
        (1, 3),
        (1, 4),
      ]);
      expect(painted, 2);
      expect(
        service.items
            .where((item) => item.sku == 'pebble_path' && item.isPlaced)
            .length,
        2,
      );
      expect(service.canPlace(service.items[3], 8, 4, 0), isFalse);
      service.expansionLevel = 1;
      service.buildableCells = HabitatService.yardCells(1);
      expect(service.catCapacity, 4);
      expect(service.canPlace(service.items[3], 8, 4, 0), isTrue);
      service.dispose();
      session.dispose();
    },
  );

  test(
    'later placement survives an earlier synchronization response',
    () async {
      final session = _Account();
      final database = _HabitatDatabase();
      final api = _LayoutApi(session);
      final service = HabitatService(
        session,
        CatStore(session),
        database: database,
        api: api,
      )..items = [const HabitatItem(id: 'bed', sku: 'cat_bed')];

      final first = service.place('bed', 1, 1, 0);
      await api.firstStarted.future;
      final second = service.place('bed', 2, 2, 0);
      api.releaseFirst.complete();
      await Future.wait([first, second]);

      expect(api.requests.length, 2);
      expect(api.requests.last['expected_revision'], 1);
      expect(service.items.single.x, 2);
      expect(service.items.single.y, 2);
      expect(service.revision, 2);
      expect(service.hasDraft, isFalse);
      expect(database.draft, isNull);
      service.dispose();
      session.dispose();
    },
  );
}
