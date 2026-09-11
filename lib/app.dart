import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'pages/auth_page.dart';
import 'pages/capture_page.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/notifications_page.dart';
import 'services/push_notification_service.dart';
import 'stores/cat_store.dart';
import 'stores/session_store.dart';
import 'theme/app_theme.dart';

class CatlogueApp extends StatefulWidget {
  const CatlogueApp({super.key});

  @override
  State<CatlogueApp> createState() => _CatlogueAppState();
}

class _CatlogueAppState extends State<CatlogueApp> {
  late final SessionStore _sessionStore;
  bool _offlineMode = false;

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore()..initialize();
  }

  @override
  void dispose() {
    _sessionStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gatálogo',
      theme: AppTheme.lightTheme,
      home: AnimatedBuilder(
        animation: _sessionStore,
        builder: (context, _) {
          if (!_sessionStore.isReady) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (_sessionStore.isSignedIn || _offlineMode) {
            return MainNavigation(sessionStore: _sessionStore);
          }
          return AuthPage(
            sessionStore: _sessionStore,
            onContinueOffline: () => setState(() => _offlineMode = true),
          );
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.sessionStore});
  final SessionStore sessionStore;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int currentIndex = 0;

  late final CatStore catStore;
  late final List<Widget> pages;
  StreamSubscription<String>? _openedNotificationSubscription;
  StreamSubscription<PushMessage>? _foregroundNotificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    catStore = CatStore(widget.sessionStore);

    catStore.loadCats();
    _openedNotificationSubscription = widget
        .sessionStore
        .pushNotifications
        .onOpenedNotification
        .listen(_openNotification);
    _foregroundNotificationSubscription = widget
        .sessionStore
        .pushNotifications
        .onMessage
        .listen((msg) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger == null) return;
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(msg.title ?? 'Nova notificação no Gatálogo'),
              action: SnackBarAction(
                label: 'Ver',
                onPressed: () => _openNotification(msg.id),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        });
    final pending = widget.sessionStore.pushNotifications
        .takePendingOpenedNotification();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotification(pending),
      );
    }

    pages = [
      HomePage(
        sessionStore: widget.sessionStore,
        catStore: catStore,
        onNavigate: (index) => setState(() => currentIndex = index),
      ),
      CapturePage(catStore: catStore),
      LibraryPage(catStore: catStore),
    ];
  }

  @override
  void dispose() {
    _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    catStore.dispose();
    super.dispose();
  }

  void _openNotification(String notificationId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          store: catStore,
          initialNotificationId: notificationId,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(catStore.syncCatalog());
      unawaited(catStore.syncPendingAnalyses());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1.2),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, LucideIcons.home, 'Inicio'),
                _buildNavItem(1, LucideIcons.camera, 'Gatalogar'),
                _buildNavItem(2, LucideIcons.library, 'Coleção'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primary : const Color(0xFF7A6E69);

    return InkWell(
      onTap: () => setState(() => currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
