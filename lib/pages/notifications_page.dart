import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/app_header_actions.dart';
import '../widgets/gatalogo_components.dart';
import 'missing_cats_page.dart';
import 'conversation_page.dart';
import 'social_page.dart';
import 'journey_page.dart';
import 'friends_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.store,
    this.initialNotificationId,
  });
  final CatStore store;
  final String? initialNotificationId;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  late final ProductApiService _api;
  bool _openedInitialNotification = false;

  @override
  void initState() {
    super.initState();
    _api = ProductApiService(widget.store.sessionStore);
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.store.notifications.refresh();
      final items = widget.store.notifications.items;
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
      final initialId = widget.initialNotificationId;
      if (!_openedInitialNotification && initialId != null) {
        _openedInitialNotification = true;
        final matching = items.where((item) => item['id'] == initialId);
        if (matching.isNotEmpty && mounted) await _open(matching.first);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title(Map<String, dynamic> item) => switch (item['type']) {
    'possible_match' => 'Possível avistamento do seu gato',
    'match_confirmed' => 'Seu avistamento ajudou uma busca!',
    'friend_invite' => 'Novo convite de amizade',
    'friend_accepted' => 'Convite de amizade aceito',
    'message' => 'Nova mensagem no chat',
    'achievement' => 'Nova conquista desbloqueada!',
    _ => 'Novidade no Gatálogo',
  };

  IconData _iconForType(String? type) => switch (type) {
    'possible_match' || 'match_confirmed' => Icons.pets,
    'friend_invite' || 'friend_accepted' => LucideIcons.users,
    'message' => LucideIcons.messageCircle,
    'achievement' => LucideIcons.trophy,
    _ => LucideIcons.bell,
  };

  Color _colorForType(String? type) => switch (type) {
    'possible_match' || 'match_confirmed' => AppColors.green,
    'friend_invite' || 'friend_accepted' => AppColors.socialPurpleText,
    'message' => AppColors.primary,
    'achievement' => AppColors.achievementText,
    _ => AppColors.textMedium,
  };

  Color _bgForType(String? type) => switch (type) {
    'possible_match' || 'match_confirmed' => AppColors.greenLight,
    'friend_invite' || 'friend_accepted' => AppColors.socialPurpleBg,
    'message' => AppColors.primaryLight,
    'achievement' => AppColors.achievementBg,
    _ => AppColors.cardAltBackground,
  };

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      await widget.store.notifications.markRead(item['id'].toString());
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      Widget? page;
      if (item['type'] == 'message' && payload['conversation_id'] != null) {
        page = ConversationPage(
          sessionStore: widget.store.sessionStore,
          conversationId: payload['conversation_id'] as String,
        );
      } else if (item['type'] == 'achievement' ||
          item['type'] == 'match_confirmed') {
        page = JourneyPage(store: widget.store);
      } else if (item['type'] == 'possible_match') {
        final matches = await _api.list('/vision/matches');
        final target = matches.where(
          (match) => match['id'] == payload['match_id'],
        );
        if (target.isNotEmpty) {
          final reports = await _api.list('/app/reports');
          final report = reports.where(
            (report) => report['id'] == target.first['report_id'],
          );
          if (report.isNotEmpty) {
            page = CluesPage(
              report: report.first,
              store: widget.store,
              openMatchId: payload['match_id'] as String,
            );
          }
        }
        page ??= MissingCatsPage(
          catStore: widget.store,
          sessionStore: widget.store.sessionStore,
        );
      } else if (item['type'] == 'friend_invite' ||
          item['type'] == 'friend_accepted') {
        page = FriendsPage(sessionStore: widget.store.sessionStore);
      } else {
        page = SocialPage(sessionStore: widget.store.sessionStore);
      }
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
      }
      if (mounted) _load();
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Folhagens decorativas
            Positioned(
              top: -10,
              right: -10,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/Folha_3.png',
                  width: 70,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: -15,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/Folha_6.png',
                  width: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Conteúdo
            RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const BackButton(),
                          const Expanded(
                            child: Text(
                              'Notificações',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTitle,
                              ),
                            ),
                          ),
                          AppHeaderActions(store: widget.store),
                        ],
                      ),
                    ),
                  ),

                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        child: LinearProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: GatalogoCard(
                          backgroundColor: AppColors.errorBg,
                          child: Column(
                            children: [
                              const Icon(
                                LucideIcons.alertCircle,
                                size: 28,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Não foi possível carregar',
                                style: GoogleFonts.fredoka(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.errorText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: AppColors.errorText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextButton(
                                onPressed: _load,
                                child: Text(
                                  'Tentar novamente',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (!_loading && _error == null && _items.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xxxl,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/gato_2.png',
                                width: 120,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Tudo calmo por aqui',
                                style: GoogleFonts.fredoka(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Quando surgirem novos avistamentos, mensagens de amigos ou conquistas, você verá os avisos aqui.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xs,
                        AppSpacing.xl,
                        AppSpacing.xxxl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = _items[index];
                          final isUnread = item['read_at'] == null;
                          final type = item['type'] as String?;
                          final icon = _iconForType(type);
                          final color = _colorForType(type);
                          final bgColor = _bgForType(type);

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: GatalogoCard(
                              backgroundColor: isUnread
                                  ? AppColors.surface
                                  : AppColors.cardAltBackground,
                              onTap: () => _open(item),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _title(item),
                                                style: GoogleFonts.fredoka(
                                                  fontSize: 15,
                                                  fontWeight: isUnread
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: AppColors.textTitle,
                                                ),
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          displayDate(item['created_at']),
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 16,
                                    color: AppColors.textLight,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: _items.length),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
