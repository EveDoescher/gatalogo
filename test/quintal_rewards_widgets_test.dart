import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/services/product_api_service.dart';
import 'package:catlogue/widgets/quintal_bond_progress.dart';
import 'package:catlogue/widgets/quintal_reward_celebration.dart';
import 'package:catlogue/theme/app_theme.dart';

import 'visual_validation_capture_test.dart'
    show ValidationAccount, ValidationStore, ValidationDatabase;

const bondRewards = [
  {'threshold': 20, 'sku': 'friendship_garden', 'name': 'Flores da amizade'},
  {'threshold': 50, 'sku': 'yellow_flowers', 'name': 'Flores amarelas'},
  {'threshold': 100, 'sku': 'leafy_plant', 'name': 'Folhagem'},
  {'threshold': 200, 'sku': 'oak_tree', 'name': 'Carvalho'},
];
const progressReceipt = {
  'id': 'qreward:progress:fixture',
  'kind': 'progress',
  'title': 'Conquista no Quintal',
  'bonuses': [
    {
      'id': 'start_harvest',
      'title': 'Primeira colheita',
      'type': 'initial',
      'xp': 20,
      'coins': 10,
    },
    {
      'id': 'garden_50',
      'title': 'Colheitas com carinho',
      'type': 'achievement',
      'xp': 400,
      'coins': 200,
    },
  ],
  'items': [
    {'sku': 'yellow_flowers', 'name': 'Flores amarelas', 'level': 2},
  ],
};
const bondReceipt = {
  'id': 'qreward:bond:fixture:50',
  'kind': 'bond',
  'title': 'A amizade floresceu!',
  'cat_id': 'cat',
  'threshold': 50,
  'bonuses': [],
  'items': [
    {'sku': 'yellow_flowers', 'name': 'Flores amarelas', 'quantity': 1},
  ],
};

class _Api extends ProductApiService {
  _Api(super.session);
  final acknowledged = <String>[];
  List<Map<String, dynamic>> receipts = [];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final id = (body!['data']['event_ids'] as List).single as String;
    acknowledged.add(id);
    if (fail) {
      fail = false;
      throw const ProductApiException('Sem conexão. Tente novamente.');
    }
    if (pending != null) await pending!.future;
    receipts = receipts.where((r) => r['id'] != id).toList();
    return {
      'production': {},
      'progress': {'celebrations': receipts},
      'outcome': {},
    };
  }
}

class _Habitat extends HabitatService {
  _Habitat(super.session, super.catStore, this.api)
    : super(api: api, database: ValidationDatabase());
  final _Api api;
  void deliver(List<Map<String, dynamic>> receipts) {
    api.receipts = receipts;
    lastProductionProgress = {'celebrations': receipts};
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'rare rewards persist on refresh, retry and open the inventory only after acknowledgement',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = ValidationAccount(),
          store = ValidationStore(ValidationAccount());
      final api = _Api(account);
      final h = _Habitat(account, store, api)
        ..cats = [const HabitatCat(id: 'cat', name: 'Mimi')];
      final sprites = HabitatSprites();
      int opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 844),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: QuintalRewardCelebrations(
                habitat: h,
                sprites: sprites,
                onInventory: () => opened++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Conquista no Quintal'), findsNothing);
      h.deliver([progressReceipt, bondReceipt]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1499));
      expect(find.text('Conquista no Quintal'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Primeira colheita'), findsOneWidget);
      expect(find.text('Colheitas com carinho'), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
      expect(find.text('+200 moedas'), findsOneWidget);
      expect(find.text('Missão concluída'), findsOneWidget);
      expect(find.text('Medalha conquistada'), findsOneWidget);
      h.deliver([progressReceipt, bondReceipt]);
      await tester.pump();
      expect(find.text('Conquista no Quintal'), findsOneWidget);
      expect(find.text('Continuar').hitTestable(), findsOneWidget);
      expect(find.text('Ver no inventário').hitTestable(), findsOneWidget);
      api.fail = true;
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
      expect(h.pendingProductionRewards.length, 2);
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Mimi · 50 pontos de vínculo'), findsOneWidget);
      expect(find.text('Primeira colheita'), findsNothing);
      api.pending = Completer();
      await tester.ensureVisible(find.text('Ver no inventário'));
      await tester.tap(find.text('Ver no inventário'));
      await tester.pump();
      expect(opened, 0);
      expect(find.text('Confirmando…'), findsOneWidget);
      api.pending!.complete();
      await tester.pump();
      expect(opened, 1);
      expect(h.pendingProductionRewards, isEmpty);
      expect(api.acknowledged, [
        progressReceipt['id'],
        progressReceipt['id'],
        bondReceipt['id'],
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      sprites.catAnimations.dispose();
      h.dispose();
      store.dispose();
      account.dispose();
    },
  );

  testWidgets('all bond boundaries use the catalog prize and terminal state', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final account = ValidationAccount(),
        store = ValidationStore(ValidationAccount());
    final api = _Api(account);
    final h = _Habitat(account, store, api);
    final sprites = HabitatSprites();
    for (final affinity in [0, 19, 20, 49, 50, 99, 100, 199, 200]) {
      h.production = {
        'catalog': {'bond_rewards': bondRewards},
        'cats': [
          {'cat_id': 'cat', 'affinity': affinity},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: QuintalBondProgress(
              habitat: h,
              catId: 'cat',
              sprites: sprites,
            ),
          ),
        ),
      );
      final next = bondRewards
          .where((r) => (r['threshold'] as int) > affinity)
          .firstOrNull;
      if (next == null) {
        expect(
          find.text('Todos os marcos de amizade alcançados!'),
          findsOneWidget,
        );
        expect(
          find.text('Seus prêmios estão em Inventário · Decorações.'),
          findsOneWidget,
        );
      } else {
        expect(
          find.text('Próximo marco: ${next['threshold']} pontos'),
          findsOneWidget,
        );
        expect(find.text(next['name'] as String), findsOneWidget);
        expect(
          find.text('Faltam ${(next['threshold'] as int) - affinity} pontos.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    sprites.catAnimations.dispose();
    h.dispose();
    store.dispose();
    account.dispose();
  });
}
