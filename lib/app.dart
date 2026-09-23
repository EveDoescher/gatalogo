import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'pages/auth_page.dart';
import 'pages/capture_page.dart';
import 'pages/home_page.dart';
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
        onNavigate: (index) => setState(() => currentIndex = index),
      ),
      SocialPage(sessionStore: widget.sessionStore, catStore: catStore),
      CapturePage(catStore: catStore),
      LibraryPage(catStore: catStore),
      Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Habitat'),
          actions: [AppHeaderActions(store: catStore)],
        ),
        body: Center(
          child: Text(
            'Em breve',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
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
    _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription?.cancel();
    _msgSub?.cancel();
    _readSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.catStore == null) catStore.dispose();
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
      _fetchUnread();
      unawaited(catStore.refreshNotifications());
      unawaited(catStore.refreshGamification());
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
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildNavItem(0, LucideIcons.home, 'Início'),
                _buildNavItem(
                  1,
                  LucideIcons.users,
                  'Social',
                  badgeCount: _unreadMessages,
                ),
                _buildNavItem(2, LucideIcons.camera, 'Gatalogar'),
                _buildNavItem(3, LucideIcons.library, 'Coleção'),
                _buildNavItem(4, LucideIcons.map, 'Habitat'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textMedium;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => currentIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        color: index == 2
                            ? AppColors.greenButton
                            : isSelected
                            ? AppColors.primaryLight
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: index == 2 ? Colors.white : color,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
