import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/models/cat.dart';
import 'package:catlogue/pages/settings_page.dart';
import 'package:catlogue/services/favorites_manager.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/theme/app_theme.dart';

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.fakeSession});
  final AuthSession? fakeSession;

  @override
  AuthSession? get session => fakeSession;

  @override
  bool get isSignedIn => fakeSession != null;

  @override
  bool get isReady => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Cat model and favorites', () {
    test('Cat model handles isFavorite and notes correctly', () {
      final now = DateTime.now();
      final cat = Cat(
        id: 'cat-101',
        name: 'Frajola',
        captureNumber: 7,
        capturedAt: now,
        photoPath: '/tmp/frajola.jpg',
        isFavorite: false,
        notes: null,
      );

      expect(cat.isFavorite, false);
      expect(cat.notes, isNull);

      final favoriteCat = cat.withFavorite(true);
      expect(favoriteCat.isFavorite, true);
      expect(favoriteCat.name, 'Frajola');

      final annotatedCat = favoriteCat.withNotes('Gosta de cafuné na orelha');
      expect(annotatedCat.notes, 'Gosta de cafuné na orelha');
      expect(annotatedCat.isFavorite, true);

      final map = annotatedCat.toMap();
      expect(map['is_favorite'], 1);
      expect(map['notes'], 'Gosta de cafuné na orelha');

      final fromMapCat = Cat.fromMap(map);
      expect(fromMapCat.isFavorite, true);
      expect(fromMapCat.notes, 'Gosta de cafuné na orelha');
      expect(fromMapCat.id, 'cat-101');
    });

    test('FavoritesManager toggles favorites in memory', () async {
      final manager = FavoritesManager.instance;
      expect(manager.isFavorite('cat-test-1'), false);

      await manager.toggleFavorite('cat-test-1');
      expect(manager.isFavorite('cat-test-1'), true);

      await manager.toggleFavorite('cat-test-1');
      expect(manager.isFavorite('cat-test-1'), false);
    });
  });

  group('Dark theme', () {
    test('AppTheme.darkTheme has cozy espresso palette and no pure black', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(darkTheme.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
      expect(darkTheme.colorScheme.surface, AppColors.darkSurface);
      expect(darkTheme.colorScheme.surface, isNot(const Color(0xFF000000)));
      expect(darkTheme.colorScheme.primary, AppColors.primary);
    });
  });

  group('Settings and security dialogs', () {
    testWidgets('renders guest banner when user is not signed in', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = _FakeSessionStore(fakeSession: null);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsPage(sessionStore: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modo Convidado'), findsOneWidget);
      expect(find.text('Criar Conta ou Entrar'), findsOneWidget);
      expect(find.text('Segurança & Privacidade'), findsNothing);
      expect(find.text('Enviar Feedback ou Relatar Problema'), findsOneWidget);
    });

    testWidgets('shows security section and Alterar Senha dialog when signed in', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = _FakeSessionStore(
        fakeSession: const AuthSession(
          userId: 'user-123',
          email: 'felino@gatalogo.app',
          accessToken: 'access-xyz',
          refreshToken: 'refresh-xyz',
        ),
      );
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsPage(sessionStore: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modo Convidado'), findsNothing);
      expect(find.text('Segurança & Privacidade'), findsOneWidget);
      expect(find.text('Exportar Meus Dados (LGPD)'), findsOneWidget);

      final changePasswordTile = find.text('Alterar Senha');
      expect(changePasswordTile, findsOneWidget);

      await tester.tap(changePasswordTile);
      await tester.pumpAndSettle();

      expect(find.textContaining('Nova Senha'), findsWidgets);
      expect(find.text('Confirmar Nova Senha'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });
  });
}
