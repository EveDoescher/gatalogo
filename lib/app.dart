import 'services/experience_service.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/illustrated_home_components.dart';

import 'pages/auth_page.dart';
import 'pages/capture_page.dart';
import 'pages/home_page.dart';
import 'pages/habitat_page.dart';
import 'pages/social_page.dart';
import 'pages/library_page.dart';
import 'pages/notifications_page.dart';
import 'services/push_notification_service.dart';
import 'services/social_api_service.dart';
import 'stores/cat_store.dart';
import 'stores/session_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_header_actions.dart';

class CatlogueApp extends StatefulWidget {
  const CatlogueApp({super.key});

  @override
  State<CatlogueApp> createState() => _CatlogueAppState();
}

class _CatlogueAppState extends State<CatlogueApp> {
  late final SessionStore _sessionStore;
  late final CatStore _catStore;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _expiredSubscription;
  bool _offlineMode = false;

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore()..initialize();
    _catStore = CatStore(_sessionStore);
    _expiredSubscription = _sessionStore.onSessionExpired.listen((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Sua sessao expirou. Faca login novamente para continuar conectado.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _expiredSubscription?.cancel();
    _catStore.dispose();
    _sessionStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStoreScope(
      store: _catStore,
      child: MaterialApp(
        scaffoldMessengerKey: _scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Gatálogo',
        navigatorObservers: [ExperienceNavigatorObserver()],
        builder: (context, child) => AnimatedBuilder(
          animation: ExperienceService.instance,
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  MediaQuery.disableAnimationsOf(context) ||
                  !ExperienceService.instance.motion,
            ),
            child: child!,
          ),
        ),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // The screens use the warm light palette, including dialogs and inputs.
        themeMode: ThemeMode.light,
        home: AnimatedBuilder(
          animation: _sessionStore,
          builder: (context, _) {
            if (!_sessionStore.isReady) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (_sessionStore.isSignedIn || _offlineMode) {
              return MainNavigation(
                sessionStore: _sessionStore,
                catStore: _catStore,
              );
            }
            return AuthPage(
              sessionStore: _sessionStore,
              onContinueOffline: () => setState(() => _offlineMode = true),
            );
          },
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.sessionStore, this.catStore});
  final SessionStore sessionStore;
  final CatStore? catStore;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  final ValueNotifier<bool> _habitatActive = ValueNotifier(false);
  int _unreadMessages = 0;

  late final CatStore catStore;
  late final List<Widget> pages;
  StreamSubscription<String>? _openedNotificationSubscription;
  StreamSubscription<PushMessage>? _foregroundNotificationSubscription;
  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    catStore = widget.catStore ?? CatStore(widget.sessionStore);
    catStore.loadCats();
    unawaited(ExperienceService.instance.initialize());
    ExperienceService.instance.selectTab(0);

    _fetchUnread();
    _msgSub = widget.sessionStore.webSocket.onMessage.listen(
      (_) => _fetchUnread(),
    );
    _readSub = widget.sessionStore.webSocket.onMessagesRead.listen(
      (_) => _fetchUnread(),
    );

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
              content: Text(msg.title ?? 'Nova notificacao no Gatalogo'),
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
        onNavigate: _navigateTo,
      ),
      SocialPage(
        sessionStore: widget.sessionStore,
        catStore: catStore,
        onNavigate: _navigateTo,
      ),
      CapturePage(catStore: catStore),
      LibraryPage(catStore: catStore),
      HabitatPage(
        sessionStore: widget.sessionStore,
        catStore: catStore,
        active: _habitatActive,
      ),
    ];
  }

  Future<void> _fetchUnread() async {
    if (!widget.sessionStore.isSignedIn) return;
    try {
      final list = await SocialApiService(widget.sessionStore).conversations();
      int count = 0;
      for (final item in list) {
        count += (item['unread_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    ExperienceService.instance.routeChanged(null);
    _habitatActive.dispose();
    _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription?.cancel();
    _msgSub?.cancel();
    _readSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.catStore == null) catStore.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (index == 3 || index == 4) {
      unawaited(
        catStore.progress.track(
          index == 3 ? 'collection_opened' : 'habitat_opened',
        ),
      );
    }
    ExperienceService.instance.selectTab(index);
    if (index != 2) {
      unawaited(catStore.refreshGamification());
    }
    setState(() => currentIndex = index);
    _habitatActive.value = index == 4;
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
      _fetchUnread();
      unawaited(catStore.refreshNotifications());
      unawaited(catStore.refreshGamification());
    }
  }

  @override
  Widget build(BuildContext context) => IllustratedNavigationScaffold(
    body: IndexedStack(index: currentIndex, children: pages),
    index: currentIndex,
    unread: _unreadMessages,
    onSelect: _navigateTo,
  );
}
