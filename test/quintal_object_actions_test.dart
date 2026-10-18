import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/game/quintal_scene_target.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/widgets/quintal_object_actions.dart';
import 'package:catlogue/widgets/quintal_game_action.dart';
import 'package:catlogue/widgets/habitat_object_balloon.dart';
import 'package:catlogue/theme/app_theme.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;

class _ActionsApi extends ProductApiService {
  _ActionsApi(super.session, this.fixture);
  final Map<String, dynamic> fixture;
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> get(String path) async => switch (path) {
    '/app/quintal' => fixture,
    '/app/habitat' => Map<String, dynamic>.from(fixture['habitat']),
    '/app/habitat/shop' => Map<String, dynamic>.from(fixture['shop']),
    _ => {},
  };
  @override
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? data]) {
    calls.add('${data?['action']}:${data?['target']}');
    bodies.add(Map<String, dynamic>.from(data ?? {}));
    return pending?.future ?? Future.value(fixture);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HabitatService service;
  late _ActionsApi api;
  final confirmed = <String>[];
  final confirmedTargets = <QuintalSceneTarget>[];
  setUp(() async {
    confirmed.clear();
    confirmedTargets.clear();
    GoogleFonts.config.allowRuntimeFetching = false;
    final fixture = Map<String, dynamic>.from(
      jsonDecode(
        File('test/fixtures/quintal_production.json').readAsStringSync(),
      ),
    );
    final account = ValidationAccount();
    api = _ActionsApi(account, fixture);
    service = HabitatService(
      account,
      ValidationStore(account),
      database: ValidationDatabase(),
      api: api,
    );
    await service.load();
  });
  tearDown(() => service.dispose());
  Future<void> show(WidgetTester tester, QuintalSceneTarget target) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: HabitatObjectBalloon(
                  anchor: const Offset(200, 340),
                  objectHeight: 24,
                  child: QuintalObjectActions(
                    habitat: service,
                    target: target,
                    onClose: () {},
                    onFish: () {},
                    onConfirmed: (target, action) {
                      confirmed.add(action);
                      confirmedTargets.add(target);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final fruit in ['apple', 'pear']) {
    testWidgets(
      'collecting $fruit preserves the other tree through confirmation',
      (tester) async {
        final slot = fruit == 'apple' ? 0 : 1;
        final trees = [
          for (var i = 0; i < 2; i++)
            {'id': 'tree-$i', 'slot': i, 'ready': 3, 'progress': 0},
        ];
        service.production['residents'] = [
          {'kind': 'orchard', 'count': 2, 'ready': 6, 'animals': trees},
        ];
        final before = Map.of(service.productionStock);
        api.pending = Completer();
        await show(
          tester,
          QuintalSceneTarget('orchard', fruit, 'collect', 2, 3),
        );
        await tester.tap(find.text('Recolher'));
        await tester.pump();
        expect(api.bodies.single['data']['resident_id'], 'tree-$slot');
        expect(confirmed, isEmpty);
        expect(service.productionRows('residents').single['animals'], trees);
        expect(service.productionStock, before);
        final response =
            jsonDecode(jsonEncode(api.fixture)) as Map<String, dynamic>;
        final after = [
          for (var i = 0; i < 2; i++) {...trees[i], if (i == slot) 'ready': 0},
        ];
        response['production']['residents'] = [
          {'kind': 'orchard', 'count': 2, 'ready': 3, 'animals': after},
        ];
        response['production']['stock'][fruit] = (before[fruit] ?? 0) + 3;
        api.pending!.complete(response);
        await tester.pump();
        expect(confirmed, ['collect_residents']);
        expect(confirmedTargets.single.target, fruit);
        expect(service.productionStock[fruit], (before[fruit] ?? 0) + 3);
        final other = fruit == 'apple' ? 'pear' : 'apple';
        expect(service.productionStock[other], before[other]);
        expect(
          service.productionRows('residents').single['animals'][1 - slot],
          trees[1 - slot],
        );
        api.fixture['production'] = response['production'];
        await service.refreshProduction();
        await tester.pump();
        expect(confirmed, hasLength(1));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'market keeps the crate through pending and failure, then confirms once',
    (tester) async {
      final ready = service.serverNow
          .subtract(const Duration(minutes: 1))
          .toIso8601String();
      final task = {
        'id': 'market-ready',
        'kind': 'order',
        'target': 'chicken',
        'status': 'ready',
        'ready_at': ready,
      };
      api.fixture['production']['tasks'] = [task];
      service.production['tasks'] = [task];
      final before = Map.of(service.productionStock);
      api.pending = Completer();
      await show(
        tester,
        const QuintalSceneTarget('market', 'market', 'market', 2, 3),
      );
      await tester.tap(find.text('Retirar'));
      await tester.pump();
      await tester.tap(find.text('Retirar'));
      await tester.pump();
      expect(api.calls, ['collect:market-ready']);
      expect(confirmed, isEmpty);
      expect(service.productionRows('tasks'), [task]);
      expect(service.productionStock, before);
      api.pending!.completeError(const ProductApiException('Sem resposta'));
      await tester.pump();
      expect(confirmed, isEmpty);
      expect(service.productionRows('tasks'), [task]);
      api.pending = Completer();
      await tester.tap(find.text('Retirar'));
      await tester.pump();
      expect(
        api.bodies.last['idempotency_key'],
        api.bodies.first['idempotency_key'],
      );
      final response =
          jsonDecode(jsonEncode(api.fixture)) as Map<String, dynamic>;
      response['production']['tasks'] = [];
      response['production']['stock']['chicken'] = (before['chicken'] ?? 0) + 2;
      api.pending!.complete(response);
      await tester.pump();
      expect(confirmed, ['collect']);
      expect(confirmedTargets.single.kind, 'market');
      expect(service.productionRows('tasks'), isEmpty);
      expect(service.productionStock['chicken'], (before['chicken'] ?? 0) + 2);
      api.fixture['production'] = response['production'];
      await service.refreshProduction();
      await tester.pump();
      expect(confirmed, ['collect']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'harvest retains the original crop and plot until API confirmation',
    (tester) async {
      final ready = service.serverNow
          .subtract(const Duration(minutes: 1))
          .toIso8601String();
      service.production['plots'] = [
        {'slot': 0, 'crop': 'carrot', 'ready_at': ready},
        {'slot': 1, 'crop': 'turnip', 'ready_at': ready},
      ];
      final before = Map.of(service.productionStock);
      api.pending = Completer();
      await show(tester, const QuintalSceneTarget('garden', '0', 'plot', 2, 3));
      await tester.tap(find.text('Colher'));
      await tester.pump();
      expect(confirmed, isEmpty);
      expect(service.productionRows('plots').first['crop'], 'carrot');
      expect(service.productionStock, before);
      // Selection changes while the original request is still in flight.
      await show(tester, const QuintalSceneTarget('garden', '1', 'plot', 4, 5));
      final response =
          jsonDecode(jsonEncode(api.fixture)) as Map<String, dynamic>;
      response['production']['plots'] = [
        {'slot': 0, 'crop': null},
        {'slot': 1, 'crop': 'turnip', 'ready_at': ready},
      ];
      api.pending!.complete(response);
      await tester.pump();
      expect(confirmed, ['harvest']);
      final snapshot = confirmedTargets.single;
      expect(
        (snapshot.target, snapshot.x, snapshot.y, snapshot.crop),
        ('0', 2.0, 3.0, 'carrot'),
      );
      expect(service.productionRows('plots').first['crop'], isNull);
      await service.refreshProduction();
      await tester.pump();
      expect(confirmed, ['harvest']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'water is a local command and repeated taps do not submit twice',
    (tester) async {
      final row = service
          .productionRows('residents')
          .firstWhere((r) => r['kind'] == 'coop');
      service.production['residents'] = [
        {...row, 'water_day': null},
      ];
      api.pending = Completer();
      await show(
        tester,
        const QuintalSceneTarget('coop', 'coop', 'water', 0, 0),
      );
      await tester.tap(find.text('Encher'));
      await tester.pump();
      await tester.tap(find.text('Encher'));
      await tester.pump();
      expect(api.calls, ['water_residents:coop']);
      expect(confirmed, isEmpty);
      api.pending!.complete(api.fixture);
      await tester.pump();
      expect(confirmed, ['water_residents']);
      await service.refreshProduction();
      await tester.pump();
      expect(confirmed, ['water_residents']);
      expect(find.text('Água fresquinha por 24 h!'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed operation has no confirmed effect and retry emits once', (
    tester,
  ) async {
    api.pending = Completer();
    await show(
      tester,
      const QuintalSceneTarget('coop', 'coop', 'collect', 0, 0),
    );
    await tester.tap(find.text('Recolher'));
    await tester.pump();
    final stockBefore = Map.of(service.productionStock);
    api.pending!.completeError(const ProductApiException('Sem resposta'));
    await tester.pump();
    expect(confirmed, isEmpty);
    expect(service.productionStock, stockBefore);
    expect(find.text('Sem resposta'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    api.pending = null;
    await tester.tap(find.text('Recolher'));
    await tester.pump();
    expect(confirmed, ['collect_residents']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'offline collection is disabled and selecting an object never spends stock',
    (tester) async {
      service.offline = true;
      await show(
        tester,
        const QuintalSceneTarget('coop', 'coop', 'collect', 0, 0),
      );
      await tester.tap(find.text('Recolher'));
      await tester.pump();
      expect(api.calls, isEmpty);
      expect(find.text('Sem conexão · progresso salvo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'queue collects the selected ready recipe and only cancels unstarted tasks',
    (tester) async {
      final now = service.serverNow;
      String at(int minutes) =>
          now.add(Duration(minutes: minutes)).toIso8601String();
      service.production['tasks'] = [
        {
          'id': 'ready-task',
          'kind': 'cook',
          'target': 'garden',
          'status': 'ready',
          'started_at': at(-20),
          'ready_at': at(-10),
        },
        {
          'id': 'running-task',
          'kind': 'cook',
          'target': 'fish',
          'status': 'running',
          'started_at': at(-5),
          'ready_at': at(10),
        },
        {
          'id': 'queued-task',
          'kind': 'cook',
          'target': 'chicken',
          'status': 'queued',
          'started_at': at(10),
          'ready_at': at(30),
        },
      ];
      await show(
        tester,
        const QuintalSceneTarget('kitchen', 'kitchen', 'kitchen', 0, 0),
      );
      await tester.tap(find.text('Fila'));
      await tester.pump();
      expect(find.text('Pronto para recolher'), findsOneWidget);
      expect(find.textContaining('Preparando ·'), findsOneWidget);
      expect(find.byTooltip('Cancelar preparo'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Cancelar preparo'));
      await tester.tap(find.byTooltip('Cancelar preparo'));
      await tester.pump();
      expect(api.calls, ['cancel:queued-task']);
      final readyId = service
          .productionRows('tasks')
          .firstWhere((t) => t['status'] == 'ready')['id'];
      await tester.tap(find.text('Fila'));
      await tester.pump();
      await tester.tap(find.text('Recolher'));
      await tester.pump();
      expect(api.calls.last, 'collect:$readyId');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'large text balloon stays centered on its target near the viewport edge',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: HabitatObjectBalloon(
                      anchor: const Offset(280, 400),
                      objectHeight: 24,
                      child: QuintalObjectActions(
                        habitat: service,
                        target: const QuintalSceneTarget(
                          'coop',
                          'coop',
                          'food',
                          0,
                          0,
                        ),
                        onClose: () {},
                        onFish: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(QuintalObjectActions));
      expect(rect.center.dx, 280);
      expect(rect.bottom, lessThan(400));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'confirmed tool briefly clears controls without losing the action state',
    (tester) async {
      final game = HabitatGame(service, HabitatSprites())..reducedMotion = true;
      game.onGameResize(Vector2(800, 600));
      final target = game.productionTargets.firstWhere(
        (t) => t.kind == 'coop' && t.role == 'water',
      );
      game.selectedProduction = target;
      api.pending = Completer();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                QuintalObjectOverlay(
                  game: game,
                  target: target,
                  onClose: () {},
                  onFish: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final state = tester.state(find.byType(QuintalObjectActions));
      await tester.tap(find.text('Encher'));
      await tester.pump();
      expect(game.productionToolActive(target), isFalse);
      api.pending!.complete(api.fixture);
      await tester.pump();
      game.update(.01);
      await tester.pump();
      expect(game.productionToolActive(target), isTrue);
      expect(find.text('Encher').hitTestable(), findsNothing);
      expect(tester.state(find.byType(QuintalObjectActions)), same(state));
      expect(find.text('Água fresquinha por 24 h!'), findsOneWidget);
      game.update(1.4);
      await tester.pump();
      expect(game.productionToolActive(target), isFalse);
      expect(find.text('Encher').hitTestable(), findsOneWidget);
      expect(tester.state(find.byType(QuintalObjectActions)), same(state));
      expect(api.calls, ['water_residents:coop']);
      await tester.pumpWidget(const SizedBox());
      game.onRemove();
    },
  );

  testWidgets(
    'construction preview frames once, keeps capacity and clears on exit',
    (tester) async {
      service.production['facilities'] = [
        for (final row in service.productionRows('facilities'))
          {...row, if (row['kind'] == 'coop') 'level': 1},
      ];
      service.production['residents'] = [
        for (final row in service.productionRows('residents'))
          {
            ...row,
            if (row['kind'] == 'coop') ...{
              'count': 2,
              'animals': (row['animals'] as List).take(2).toList(),
            },
          },
      ];
      service.production['offers'] = [
        {'id': 'coop:2', 'available': false, 'reasons': <String>[]},
      ];
      final game = HabitatGame(service, HabitatSprites());
      game.onGameResize(Vector2(800, 600));
      final target = game.productionTargets.firstWhere(
        (t) => t.kind == 'coop' && t.role == 'collect',
      );
      final stock = Map.of(service.productionStock);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                QuintalObjectOverlay(
                  game: game,
                  target: target,
                  onClose: () {},
                  onFish: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final before = game.pan;
      await tester.tap(find.text('Melhorar espaço'));
      await tester.pump();
      expect(game.constructionPreviewKind, 'coop');
      expect(game.pan, isNot(before));
      expect(find.text('Galinhas: de 2 para 4'), findsOneWidget);
      expect(
        game.productionTargets.where(
          (t) => t.kind == 'coop' && t.role == 'resident',
        ),
        hasLength(2),
      );
      expect(service.productionStock, stock);
      expect(api.calls, isEmpty);
      game.moveCamera(const Offset(20, 10));
      final moved = game.pan;
      game.interactionPositions.value++;
      await tester.pump();
      expect(game.pan, moved);
      await tester.tap(find.byTooltip('Voltar às ações'));
      await tester.pump();
      expect(game.constructionPreviewKind, isNull);
      await tester.pump(); // Apply the automatic framing after the tray closes.
      expect(find.text('Melhorar espaço').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Melhorar espaço'));
      await tester.pump();
      expect(game.constructionPreviewKind, 'coop');
      await tester.pumpWidget(const SizedBox());
      expect(game.constructionPreviewKind, isNull);
      game.onRemove();
    },
  );

  testWidgets(
    'selection frames camera once and keeps actions attached during pan and zoom',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0]) {
        final height = width == 320 ? 568.0 : 844.0;
        tester.view.physicalSize = Size(width, height);
        final game = HabitatGame(service, HabitatSprites());
        game.onGameResize(Vector2(width, height));
        const target = QuintalSceneTarget('garden', '0', 'plot', 0, 0);
        game.moveCamera(Offset(width - 12, 200) - game.productionFocus(target));
        final before = game.pan;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, height),
                textScaler: const TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: Stack(
                  children: [
                    QuintalObjectOverlay(
                      game: game,
                      target: target,
                      onClose: () {},
                      onFish: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(game.pan, isNot(before));
        final actions = find.byType(QuintalObjectActions);
        final rect = tester.getRect(actions);
        expect(rect.left, greaterThanOrEqualTo(8));
        expect(rect.right, lessThanOrEqualTo(width - 8));
        expect(rect.top, greaterThanOrEqualTo(78));
        expect(rect.center.dx, closeTo(game.productionFocus(target).dx, .001));
        expect(find.text('Enquadrar ações'), findsNothing);
        // A deliberate pan must stay under the player's control.
        game.moveCamera(const Offset(-40, 30));
        final moved = game.pan;
        game.interactionPositions.value++;
        await tester.pump();
        await tester.pump();
        expect(game.pan, moved);
        expect(
          tester.getRect(actions).center.dx,
          closeTo(game.productionFocus(target).dx, .001),
        );
        game.scaleCamera(1.5, Offset(width / 2, height / 2));
        game.interactionPositions.value++;
        await tester.pump();
        expect(
          tester.getRect(actions).bottom,
          closeTo(
            game.productionFocus(target).dy -
                game.productionObjectHeight(target) -
                10,
            .001,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        game.onRemove();
      }
    },
  );
  testWidgets('all production balloons frame at every edge and camera scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = AppTheme.lightTheme;
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    final stock = Map.of(service.productionStock);
    for (final width in [320.0, 390.0]) {
      final height = width == 320 ? 568.0 : 844.0;
      tester.view.physicalSize = Size(width, height);
      final game = HabitatGame(service, HabitatSprites());
      game.onGameResize(Vector2(width, height));
      final targets = <String, QuintalSceneTarget>{};
      for (final target in game.productionTargets) {
        targets.putIfAbsent('${target.kind}:${target.role}', () => target);
      }
      for (final zoom in [.8, 1.9]) {
        game.zoom = zoom;
        for (final edge in [
          Offset(12, height / 2),
          Offset(width - 12, height / 2),
          Offset(width / 2, 12),
          Offset(width / 2, height - 12),
        ]) {
          for (final target in targets.values) {
            game.selectedProduction = target;
            game.moveCamera(edge - game.productionFocus(target));
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, height),
                    textScaler: const TextScaler.linear(1.5),
                  ),
                  child: Scaffold(
                    body: Stack(
                      children: [
                        QuintalObjectOverlay(
                          game: game,
                          target: target,
                          onClose: () {},
                          onFish: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            final rect = tester.getRect(find.byType(QuintalObjectActions));
            final context =
                '${target.kind}/${target.role} width=$width zoom=$zoom edge=$edge';
            expect(rect.left, greaterThanOrEqualTo(7.99), reason: context);
            expect(
              rect.right,
              lessThanOrEqualTo(width - 7.99),
              reason: context,
            );
            expect(rect.top, greaterThanOrEqualTo(77.99), reason: context);
            expect(
              rect.bottom,
              lessThanOrEqualTo(height - 11.99),
              reason: context,
            );
            expect(
              rect.center.dx,
              closeTo(game.productionFocus(target).dx, .001),
              reason: context,
            );
            expect(tester.takeException(), isNull, reason: context);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
      game.onRemove();
    }
    expect(service.productionStock, stock);
    expect(api.calls, isEmpty);
  });
  testWidgets(
    'camera framing preserves a choice tray and an in-flight action offscreen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = HabitatGame(service, HabitatSprites());
      game.onGameResize(Vector2(390, 844));
      Future<void> select(QuintalSceneTarget target) async {
        game.moveCamera(const Offset(195, 480) - game.productionFocus(target));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  QuintalObjectOverlay(
                    game: game,
                    target: target,
                    onClose: () {},
                    onFish: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await select(
        const QuintalSceneTarget('kitchen', 'kitchen', 'kitchen', 0, 0),
      );
      await tester.tap(find.text('Receitas'));
      await tester.pump();
      expect(find.text('Escolher receita'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar às ações'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Receitas'), findsOneWidget);
      final row = service
          .productionRows('residents')
          .firstWhere((r) => r['kind'] == 'coop');
      service.production['residents'] = [
        {...row, 'water_day': null},
      ];
      await select(const QuintalSceneTarget('coop', 'coop', 'water', 0, 0));
      api.pending = Completer();
      await tester.tap(find.text('Encher'));
      await tester.pump();
      final panBefore = game.pan;
      game.moveCamera(const Offset(-900, 0));
      game.interactionPositions.value++;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      api.pending!.complete(api.fixture);
      await tester.pump();
      game.pan = panBefore;
      game.interactionPositions.value++;
      await tester.pump();
      expect(api.calls, ['water_residents:coop']);
      expect(find.text('Água fresquinha por 24 h!'), findsOneWidget);
      game.moveCamera(const Offset(250, 0));
      final manualPan = game.pan;
      game.interactionPositions.value++;
      await tester.pump();
      await tester.pump();
      expect(
        game.pan,
        manualPan,
        reason: 'A confirmation must not rearm camera framing.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.onRemove();
    },
  );
  testWidgets(
    'expansion badge opens works while existing production stays usable',
    (tester) async {
      for (final kind in ['garden', 'coop', 'pasture', 'kitchen']) {
        final stock = Map.of(service.productionStock);
        service.production['facilities'] = [
          for (final f in service.productionRows('facilities'))
            {
              ...f,
              if (f['kind'] == kind) ...{
                'level': 1,
                'target_level': 2,
                'started_at': service.serverNow
                    .subtract(const Duration(hours: 1))
                    .toIso8601String(),
                'ready_at': service.serverNow
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
              },
            },
        ];
        final game = HabitatGame(service, HabitatSprites());
        game.onGameResize(Vector2(390, 844));
        final works = game.productionTargets.singleWhere(
          (t) => t.kind == kind && t.role == 'build',
        );
        final badge =
            game.productionFocus(works) -
            Offset(0, game.productionObjectHeight(works) + 18);
        expect(game.productionObjectAt(badge)?.role, 'build', reason: kind);
        final normal = game.productionTargets.firstWhere(
          (t) => t.kind == kind && t.role != 'build',
        );
        expect(
          game.productionObjectAt(game.productionFocus(normal))?.role,
          isNot('build'),
          reason: kind,
        );
        await show(tester, works);
        expect(find.textContaining('Fica pronto em'), findsOneWidget);
        expect(
          tester
              .widget<QuintalGameAction>(
                find.ancestor(
                  of: find.text('Concluir'),
                  matching: find.byType(QuintalGameAction),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(api.calls, isEmpty);
        service.production['facilities'] = [
          for (final f in service.productionRows('facilities'))
            {
              ...f,
              if (f['kind'] == kind)
                'ready_at': service.serverNow
                    .subtract(const Duration(seconds: 1))
                    .toIso8601String(),
            },
        ];
        await tester.pumpWidget(const SizedBox());
        await show(tester, works);
        expect(find.text('Obra pronta!'), findsOneWidget);
        expect(service.facilityLevel(kind), 1);
        expect(service.productionStock, stock);
        expect(
          api.calls,
          isEmpty,
          reason: 'Deadline alone must not finish or credit works',
        );
        await tester.pumpWidget(const SizedBox());
        game.onRemove();
      }
    },
  );

  testWidgets(
    'legacy kitchen task without start keeps deadline without fake progress',
    (tester) async {
      service.production['tasks'] = [
        {
          'id': 'legacy',
          'kind': 'cook',
          'target': 'garden',
          'status': 'active',
          'ready_at': service.serverNow
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        },
      ];
      await show(
        tester,
        const QuintalSceneTarget('kitchen', 'kitchen', 'kitchen', 0, 0),
      );
      await tester.tap(find.text('Fila'));
      await tester.pump();
      expect(find.textContaining('Preparando ·'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fruit trade sends its option without changing the old payment shape',
    (tester) async {
      service.production['stock'] = {
        ...service.productionStock,
        'apple': 3,
        'pear': 3,
      };
      await show(
        tester,
        const QuintalSceneTarget('market', 'market', 'market', 0, 0),
      );
      await tester.tap(find.text('Fazer pedido'));
      await tester.pump();
      await Scrollable.ensureVisible(
        tester.element(
          find.ancestor(
            of: find.text('Frutas'),
            matching: find.byType(QuintalGameAction),
          ),
        ),
        alignment: .5,
      );
      await tester.pump();
      expect(find.text('Frutas').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Frutas'));
      await tester.pump();
      expect(api.calls, ['order:chicken']);
      expect(api.bodies.single['data'], {
        'payment': 'products',
        'product_option': 'fruit',
      });
    },
  );

  testWidgets('orchard project explains fruit uses before construction', (
    tester,
  ) async {
    service.production['facilities'] = [
      for (final f in service.productionRows('facilities'))
        {...f, if (f['kind'] == 'orchard') 'level': 0},
    ];
    service.production['offers'] = [
      {'id': 'orchard:1', 'available': true, 'reasons': []},
    ];
    await show(
      tester,
      const QuintalSceneTarget('orchard', 'orchard', 'build', 0, 0),
    );
    await tester.tap(find.text('Ver projeto'));
    await tester.pump();
    expect(find.textContaining('Colha maçãs e peras'), findsOneWidget);
    expect(api.calls, isEmpty);
  });
}
