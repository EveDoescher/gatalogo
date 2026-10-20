import 'package:catlogue/widgets/quintal_hold_control.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/pages/quintal_game_page.dart';
import 'package:catlogue/game/habitat_game.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationDatabase, ValidationStore;

class _GameApi extends ProductApiService {
  _GameApi(super.session, this.fixture);
  final Map<String, dynamic> fixture;
  final calls = <String>[];
  bool fail = false;
  ProductApiException? finishError;
  Map<String, dynamic> finishResult = {'success': true, 'quantity': 1};
  final requests = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? pendingStart;
  @override
  Future<Map<String, dynamic>> get(String path) async => switch (path) {
    '/app/quintal' => fixture,
    '/app/habitat' => Map<String, dynamic>.from(fixture['habitat']),
    '/app/habitat/shop' => Map<String, dynamic>.from(fixture['shop']),
    _ => {},
  };
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    calls.add(body!['action']);
    requests.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(body))));
    if (body['action'].toString().startsWith('finish_')) {
      if (finishError != null) throw finishError!;
      return {...fixture, 'outcome': finishResult};
    }
    if (fail) throw const ProductApiException('Sem conexão para começar.');
    if (pendingStart != null) return pendingStart!.future;
    return {
      ...fixture,
      'outcome': {
        'session_id': 'session-${calls.length}',
        'bite_seconds': 0,
        'zone': .3,
        'speed': .3,
        'phase': .2,
      },
    };
  }
}

class _Clock extends Stopwatch {
  int milliseconds = 0;
  bool running = false;
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  bool get isRunning => running;
  @override
  void start() => running = true;
  @override
  void stop() => running = false;
  @override
  void reset() => milliseconds = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HabitatService habitat;
  late _GameApi api;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final account = ValidationAccount();
    final fixture = Map<String, dynamic>.from(
      jsonDecode(
        File('test/fixtures/quintal_production.json').readAsStringSync(),
      ),
    );
    api = _GameApi(account, fixture);
    habitat = HabitatService(
      account,
      ValidationStore(account),
      database: ValidationDatabase(),
      api: api,
    );
    await habitat.load();
  });
  tearDown(() => habitat.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => QuintalGamePage.open(context, habitat: habitat),
              child: const Text('Pescar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pescar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> completeRound(WidgetTester tester, _Clock clock) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuintalGamePage(habitat: habitat, clock: clock),
      ),
    );
    await tester.pump();
    for (var second = 0; second <= 20; second++) {
      clock.milliseconds = second * 1000;
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump();
    expect(api.calls, ['start_fish', 'finish_fish']);
  }

  testWidgets('uncertain finish retries the same session, trace and key', (
    tester,
  ) async {
    api.finishError = const ProductApiException(
      'Resposta não recebida.',
      statusCode: 503,
    );
    final before = Map.of(habitat.productionStock);
    final clock = _Clock();
    await completeRound(tester, clock);
    expect(find.text('Resposta não recebida.'), findsOneWidget);
    expect(find.text('Boa pescaria!'), findsNothing);
    expect(habitat.productionStock, before);
    final request = api.requests.last;
    api.finishError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(api.calls, ['start_fish', 'finish_fish', 'finish_fish']);
    expect(api.requests.last, request);
    expect(find.text('Boa pescaria!'), findsOneWidget);
    expect(find.text('1 peixe(s) no inventário!'), findsOneWidget);
    expect(clock.isRunning, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  for (final rejection in [409, 422]) {
    testWidgets(
      'rejected activity $rejection starts a fresh session on retry',
      (tester) async {
        api.finishError = ProductApiException(
          'Interação inválida.',
          statusCode: rejection,
        );
        final before = Map.of(habitat.productionStock);
        final clock = _Clock();
        await completeRound(tester, clock);
        expect(find.text('Interação inválida.'), findsOneWidget);
        expect(habitat.productionStock, before);
        api.finishError = null;
        await tester.tap(find.text('Tentar novamente'));
        await tester.pump();
        expect(api.calls, ['start_fish', 'finish_fish', 'start_fish']);
        expect(find.byType(QuintalHoldControl), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
        expect(clock.elapsedMilliseconds, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final result in [
    {'success': false, 'quantity': 0},
    {'success': true, 'quantity': 0, 'practice': true},
  ]) {
    testWidgets('result follows API even when local score differs: $result', (
      tester,
    ) async {
      api.finishResult = result;
      final before = Map.of(habitat.productionStock);
      await completeRound(tester, _Clock());
      expect(
        find.text(
          result['success'] == true
              ? 'Boa captura de treino!'
              : 'O peixe escapou',
        ),
        findsOneWidget,
      );
      expect(habitat.productionStock, before);
      expect(find.text('1 peixe(s) no inventário!'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'hold and release controls fishing; backgrounding never finishes or rewards a session',
    (tester) async {
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Slider), findsNothing);
      final hold = find.byType(QuintalHoldControl);
      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<QuintalHoldControl>(hold).held, isTrue);
      await gesture.up();
      await tester.pump();
      expect(tester.widget<QuintalHoldControl>(hold).held, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.text('A atividade foi pausada. Vamos tentar de novo?'),
        findsOneWidget,
      );
      expect(api.calls, ['start_fish']);
      expect(find.byType(Slider), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(api.calls, ['start_fish', 'start_fish']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'start failure exposes retry without a permanent loading spinner',
    (tester) async {
      api.fail = true;
      await open(tester);
      expect(find.text('Sem conexão para começar.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      api.fail = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(find.byType(QuintalHoldControl), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a start response arriving after backgrounding requires a new session',
    (tester) async {
      api.pendingStart = Completer();
      await open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      api.pendingStart!.complete({
        ...api.fixture,
        'outcome': {'session_id': 'late', 'bite_seconds': 0},
      });
      await tester.pump();
      expect(
        find.text('A atividade foi pausada. Vamos tentar de novo?'),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsNothing);
      expect(api.calls, ['start_fish']);
      api.pendingStart = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(api.calls, ['start_fish', 'start_fish']);
      expect(find.byType(QuintalHoldControl), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'world activity fits large text and releases the scene without a success on close',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 568);
        final game = HabitatGame(habitat, HabitatSprites())
          ..onGameResize(Vector2(width, 568));
        bool? success;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    success = await QuintalGamePage.open(
                      context,
                      habitat: habitat,
                      scene: game,
                    );
                  },
                  child: const Text('Começar'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Começar'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(game.activityInProgress, isTrue);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
          Colors.transparent,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Voltar ao Quintal'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(success, isFalse);
        expect(game.activityInProgress, isFalse);
        await tester.pumpWidget(const SizedBox());
        game.onRemove();
      }
    },
  );
}
