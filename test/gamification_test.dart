import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/models/cat_analysis.dart';
import 'package:catlogue/models/cat_reference_photo.dart';
import 'package:catlogue/models/gamification.dart';
import 'package:catlogue/pages/journey_page.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/widgets/gatalogo_gamification.dart';

class GamificationMockStore extends CatStore {
  GamificationMockStore(super.session);

  final List<Cat> mockCats = [];
  final Map<String, CatAnalysis> mockAnalyses = {};
  final Map<String, List<CatReferencePhoto>> mockPhotos = {};

  @override
  List<Cat> get cats => mockCats;

  @override
  List<Cat> get discoveries => mockCats.where((c) => !c.isOwned).toList();

  @override
  List<Cat> get pets => mockCats.where((c) => c.isOwned).toList();

  @override
  CatAnalysis? analysisFor(String catId) => mockAnalyses[catId];

  @override
  List<CatReferencePhoto> referencePhotosFor(String catId) =>
      mockPhotos[catId] ?? const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gamification Models & State', () {
    test('GamificationState.initial creates correct defaults', () {
      final state = GamificationState.initial();
      expect(state.level, equals(1));
      expect(state.levelTitle, equals('Curioso'));
      expect(state.xp, equals(0));
      expect(state.targetXp, equals(100));
      expect(state.streak, equals(0));
      expect(state.multiplier, equals(1.0));
      expect(state.freezeShields, equals(1));
      expect(state.dailyMissions.length, equals(3));
      expect(state.weeklyMission, isNotNull);
      expect(state.totalAchievements, equals(28));
    });

    test('Mission.fromMap and toMap serialize properly', () {
      final mission = const Mission(
        id: 'daily_photo',
        title: 'Fotografar 1 gato',
        target: 1,
        progress: 1,
        xpReward: 60,
        completed: true,
      );

      final map = mission.toMap();
      final roundtrip = Mission.fromMap(map);

      expect(roundtrip.id, equals('daily_photo'));
      expect(roundtrip.title, equals('Fotografar 1 gato'));
      expect(roundtrip.target, equals(1));
      expect(roundtrip.progress, equals(1));
      expect(roundtrip.xpReward, equals(60));
      expect(roundtrip.completed, isTrue);
      expect(roundtrip.progressFraction, equals(1.0));
    });

    test('Mission.copyWith correctly updates attributes', () {
      const mission = Mission(
        id: 'daily_photo',
        title: 'Fotografar 1 gato',
        target: 1,
        progress: 0,
        xpReward: 60,
        completed: false,
      );

      final updated = mission.copyWith(
        progress: 1,
        completed: true,
      );

      expect(updated.id, equals('daily_photo'));
      expect(updated.progress, equals(1));
      expect(updated.completed, isTrue);
      expect(updated.xpReward, equals(60));
    });

    test('GamificationState.fromMap supports new_xp and xp keys', () {
      final stateFromNewXp = GamificationState.fromMap({
        'new_xp': 250,
        'level': 2,
        'level_title': 'Explorador',
      });
      expect(stateFromNewXp.xp, equals(250));

      final stateFromXp = GamificationState.fromMap({
        'xp': 180,
        'level': 1,
      });
      expect(stateFromXp.xp, equals(180));
    });

    test('GamificationState fromMap and toMap roundtrip preserves data', () {
      final original = GamificationState(
        xp: 350,
        level: 3,
        levelTitle: 'Observador',
        levelMinXp: 300,
        targetXp: 600,
        levelReward: 'Desbloqueio de filtros avançados',
        streak: 5,
        longestStreak: 7,
        multiplier: 1.2,
        freezeShields: 2,
        dailyMissions: const [
          Mission(
            id: 'daily_photo',
            title: 'Fotografar 1 gato',
            target: 1,
            progress: 1,
            xpReward: 60,
            completed: true,
          ),
        ],
        weeklyMission: const Mission(
          id: 'weekly_sightings',
          title: 'Registrar 3 avistamentos',
          target: 3,
          progress: 1,
          xpReward: 150,
          completed: false,
        ),
        unlockedAchievements: 6,
        totalAchievements: 28,
      );

      final map = original.toMap();
      final reconstructed = GamificationState.fromMap(map);

      expect(reconstructed.xp, equals(350));
      expect(reconstructed.level, equals(3));
      expect(reconstructed.levelTitle, equals('Observador'));
      expect(reconstructed.streak, equals(5));
      expect(reconstructed.multiplier, closeTo(1.2, 0.01));
      expect(reconstructed.freezeShields, equals(2));
      expect(reconstructed.dailyMissions.length, equals(1));
      expect(reconstructed.dailyMissions.first.completed, isTrue);
      expect(reconstructed.weeklyMission, isNotNull);
      expect(reconstructed.weeklyMission!.progress, equals(1));
      expect(reconstructed.unlockedAchievements, equals(6));
      expect(reconstructed.totalAchievements, equals(28));
    });
  });

  group('Journey 28 Achievements Local Calculations', () {
    test('localJourney returns exactly 28 achievements', () {
      final session = SessionStore();
      final store = GamificationMockStore(session);
      final journey = localJourney(store);

      expect(journey.length, equals(28));
      final ids = journey.map((it) => it['id'] as String).toSet();
      expect(ids.length, equals(28));

      expect(ids, contains('first'));
      expect(ids, contains('collector_5'));
      expect(ids, contains('collector_10'));
      expect(ids, contains('master_collector'));
      expect(ids, contains('legend_collector'));
      expect(ids, contains('black_cat'));
      expect(ids, contains('orange_tabby'));
      expect(ids, contains('calico'));
      expect(ids, contains('siamese_pattern'));
      expect(ids, contains('bicolor'));
      expect(ids, contains('neighborhood_3'));
      expect(ids, contains('city_wanderer'));
      expect(ids, contains('night_owl'));
      expect(ids, contains('early_bird'));
      expect(ids, contains('days'));
      expect(ids, contains('streak_3'));
      expect(ids, contains('streak_7'));
      expect(ids, contains('streak_30'));
      expect(ids, contains('angles'));
      expect(ids, contains('portrait'));
      expect(ids, contains('angles_master'));
      expect(ids, contains('helper'));
      expect(ids, contains('guardian_shield'));
      expect(ids, contains('poster_share'));
      expect(ids, contains('social_heart'));
      expect(ids, contains('commentator'));
      expect(ids, contains('first_share'));
      expect(ids, contains('owned_pet'));
    });

    test('localJourney calculates coat, location and owned pet progress', () {
      final session = SessionStore();
      final store = GamificationMockStore(session);

      store.mockCats.add(
        Cat(
          id: 'cat_black',
          captureNumber: 1,
          photoPath: 'black.jpg',
          capturedAt: DateTime(2026, 9, 10, 22, 0), // night owl!
          locationName: 'Parque Central',
          status: 'completed',
        ),
      );
      store.mockAnalyses['cat_black'] = const CatAnalysis(
        catId: 'cat_black',
        status: AnalysisStatus.completed,
        confidence: 0.9,
        primaryColor: 'preto',
        coatType: 'curto',
      );

      store.mockCats.add(
        Cat(
          id: 'cat_pet',
          captureNumber: 2,
          photoPath: 'pet.jpg',
          capturedAt: DateTime(2026, 9, 11, 7, 0), // early bird!
          locationName: 'Casa',
          isOwned: true,
        ),
      );

      final journey = localJourney(store);
      final blackAchievement = journey.firstWhere((it) => it['id'] == 'black_cat');
      final nightAchievement = journey.firstWhere((it) => it['id'] == 'night_owl');
      final petAchievement = journey.firstWhere((it) => it['id'] == 'owned_pet');

      expect(blackAchievement['progress'], equals(1));
      expect(nightAchievement['progress'], equals(1));
      expect(petAchievement['progress'], equals(1));
    });
  });

  group('Gamification Widgets UI', () {
    testWidgets('GatalogoXPBar renders level and progress correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: GatalogoXPBar(
                currentLevel: 2,
                currentXP: 150,
                targetXP: 300,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nível 2'), findsOneWidget);
      expect(find.text('150 / 300 XP'), findsOneWidget);
    });

    testWidgets('Conquistas filters unlocked achievements without a journey heading', (tester) async {
      final session = SessionStore();
      final store = GamificationMockStore(session);
      store.mockCats.add(Cat(id: 'one', captureNumber: 1, photoPath: 'missing.jpg', capturedAt: DateTime(2026, 9, 22)));
      await tester.pumpWidget(MaterialApp(home: JourneyPage(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conquistadas'));
      await tester.pumpAndSettle();
      expect(find.text('Conquistas'), findsOneWidget);
      expect(find.text('Primeira Descoberta'), findsOneWidget);
      expect(find.text('Olhar Curioso'), findsNothing);
      expect(find.textContaining('Conquistas e jornada'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose(); session.dispose();
    });
  });
}
