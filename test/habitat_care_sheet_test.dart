import 'package:catlogue/game/habitat_sprites.dart';
import 'package:catlogue/models/auth_session.dart';
import 'package:catlogue/services/habitat_service.dart';
import 'package:catlogue/stores/cat_store.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:catlogue/widgets/habitat_care_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SignedIn extends SessionStore {
  @override
  bool get isSignedIn => true;
  @override
  AuthSession get session => AuthSession(
    userId: 'user',
    email: 'test@example.com',
    accessToken: 'test',
    refreshToken: 'test',
  );
}

void main() {
  testWidgets(
    'care sheet displays affinity, free food and explicit optional treat cost',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final session = _SignedIn();
      final store = CatStore(session);
      final habitat = HabitatService(session, store)..balance = 4;
      final sprites = HabitatSprites();
      await tester.runAsync(
        () => sprites.preloadReady(['animal-cat', 'bag_NE', 'can-open_NE']),
      );
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HabitatCareSheet(
              habitat: habitat,
              cat: const HabitatCat(id: 'cat', name: 'Lua'),
              sprites: sprites,
              preference: 'brincadeira',
              onAction: (action) => selected = action,
            ),
          ),
        ),
      );
      expect(find.text('Afinidade 0/100'), findsOneWidget);
      expect(find.text('3 porções gratuitas disponíveis hoje'), findsOneWidget);
      expect(find.text('4 moedas · +3 afinidade'), findsOneWidget);
      await tester.tap(find.text('Porção diária'));
      expect(selected, 'feed');
      await tester.tap(find.text('Petisco'));
      expect(selected, 'treat');
      await tester.pumpWidget(const SizedBox());
      sprites.catAnimations.dispose();
      habitat.dispose();
      store.dispose();
      session.dispose();
    },
  );
}
