// Real page widgets with fixture data; SDK guidelines do not replace readers.
import 'dart:convert';
import 'dart:io';

import 'package:catlogue/widgets/app_header_actions.dart';
import 'package:catlogue/pages/cat_details_page.dart';
import 'package:catlogue/pages/library_page.dart';
import 'package:catlogue/pages/profile_page.dart';
import 'package:catlogue/pages/settings_page.dart';
import 'package:catlogue/stores/session_store.dart';
import 'package:catlogue/data/cat_database.dart';
import 'package:catlogue/services/favorites_manager.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:catlogue/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../test/screen_corrections_test.dart' show ScreenStore;
import 'campaign_accessibility_test.dart' as audit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final output = Platform.environment['QUALITY_ACC_OUTPUT']!;
    final documents = Directory('$output/platform-documents')
      ..createSync(recursive: true);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath('$output/platform-sqlite');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.absolute.path,
        );
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'Gatálogo',
      packageName: 'campaign.fixture',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await FavoritesManager.instance.initialize();
  });
  tearDownAll(() async {
    await (await CatDatabase.instance.database).close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final pageName in ['collection', 'details', 'settings', 'profile']) {
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final reduced in [false, true]) {
          testWidgets(
            'ACC flows page=$pageName width=$width scale=$scale reduced=$reduced',
            (tester) async {
              final handle = tester.ensureSemantics();
              final account = SessionStore();
              final actualStore = ScreenStore(account);
              tester.view.physicalSize = Size(width, 800);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              try {
                final Widget page = switch (pageName) {
                  'collection' => Scaffold(
                    body: LibraryPage(catStore: actualStore),
                  ),
                  'details' => CatDetailsPage(
                    cat: actualStore.cats.first,
                    catStore: actualStore,
                  ),
                  'settings' => SettingsPage(
                    sessionStore: account,
                    catStore: actualStore,
                  ),
                  _ => ProfilePage(
                    sessionStore: account,
                    catStore: actualStore,
                  ),
                };
                await tester.pumpWidget(
                  AppStoreScope(
                    store: actualStore,
                    child: MaterialApp(
                      theme: AppTheme.lightTheme,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: reduced,
                        ),
                        child: child!,
                      ),
                      home: page,
                    ),
                  ),
                );
                await tester.runAsync(() async => GoogleFonts.pendingFonts());
                await tester.pumpAndSettle();
                final states = <Map<String, Object?>>[];
                for (final position in ['initial', 'scrolled']) {
                  if (position == 'scrolled' &&
                      find.byType(Scrollable).evaluate().isNotEmpty) {
                    await tester.drag(
                      find.byType(Scrollable).first,
                      const Offset(0, -600),
                    );
                    await tester.pumpAndSettle();
                  }
                  final error = tester.takeException();
                  final findings = await audit.guidelines(tester);
                  final clipped = <String>[];
                  for (final element in find.byType(Text).evaluate()) {
                    if (element.renderObject
                        case final RenderParagraph paragraph) {
                      if (paragraph.didExceedMaxLines) {
                        clipped.add((element.widget as Text).data ?? '<rich>');
                      }
                    }
                  }
                  final record = <String, Object?>{
                    'scenarios': [
                      'ACC-01',
                      'ACC-02',
                      'ACC-03',
                      'ACC-05',
                      'ACC-07',
                    ],
                    'page': pageName,
                    'width': width,
                    'height': 800,
                    'scale': scale,
                    'position': position,
                    'disableAnimationsInjected': reduced,
                    'guidelines': findings,
                    'layoutError': error?.toString(),
                    'clippedLabelsForManualReview': clipped,
                    'scope': 'SDK visible semantics/rendered content, fixture data, initial and one scroll; injected reduction flag does not prove every animation respects it; no physical readers or whole-flow certification',
                  };
                  audit.record(
                    'flow-$pageName-$width-$scale-$reduced-$position',
                    record,
                  );
                  states.add(record);
                }
                await tester.pumpWidget(const SizedBox());
                expect(
                  states.every((s) => s['layoutError'] == null),
                  isTrue,
                  reason: jsonEncode(states),
                );
                expect(
                  states.every(
                    (s) => (s['guidelines'] as Map).values.every(
                      (v) => v['passed'] == true,
                    ),
                  ),
                  isTrue,
                  reason: jsonEncode(states),
                );
              } finally {
                actualStore.dispose();
                account.dispose();
                handle.dispose();
                debugDefaultTargetPlatformOverride = null;
              }
            },
          );
        }
      }
    }
  }
  test('ACC evidence destination is explicitly private', () {
    expect(Platform.environment['QUALITY_ACC_OUTPUT'], isNotNull);
  });
}
