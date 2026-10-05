import '../widgets/botanical_scene.dart';
import 'discovery_result_page.dart';
import '../services/habitat_navigation.dart';
import 'result_history_page.dart';

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
          final grouped = <String, Map<String, dynamic>>{};
          for (final item in items) {
            final payload = item['payload'] as Map? ?? {};
            final target =
                payload['match_id'] ??
                payload['conversation_id'] ??
                payload['event_id'] ??
                item['id'];
            grouped.putIfAbsent('${item['type']}:$target', () => item);
          }
          _items = grouped.values.toList()
            ..sort((a, b) => _section(a).compareTo(_section(b)));
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

  int _section(Map<String, dynamic> item) => switch (item['type']) {
    'possible_match' || 'match_confirmed' => 0,
    'message' || 'friend_invite' || 'friend_accepted' => 1,
    _ => 2,
  };

  String _title(Map<String, dynamic> item) => switch (item['type']) {
    'habitat_gift' => 'Um visitante deixou um presente!',
    'progress_result' => 'Seu resultado está pronto',
    'possible_match' => 'Possível avistamento do seu gato',
    'match_confirmed' => 'Seu avistamento ajudou uma busca!',
    'friend_invite' => 'Novo convite de amizade',
    'friend_accepted' => 'Convite de amizade aceito',
    'message' => 'Nova mensagem no chat',
    'achievement' => 'Nova conquista desbloqueada!',
    _ => 'Novidade no Gatálogo',
  };

  String _artForType(String? type) => switch (type) {
    'possible_match' => 'icons/icon_search_paw_magnifier',
    'match_confirmed' => 'icons/icon_heart_coral',
    'friend_invite' || 'friend_accepted' => 'ui/ui_speech_heart',
    'message' => 'ui/ui_speech_ellipsis',
    'achievement' => 'rewards/reward_medal_star_gold_ribbon_01',
    'habitat_gift' => 'icons/icon_reward_chest_star',
    'progress_result' => 'ui/ui_notebook_cat',
    _ => 'icons/icon_bell_gold_coral',
  };

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      final source = item['payload'] as Map? ?? {};
      final target =
          source['match_id'] ?? source['conversation_id'] ?? source['event_id'];
      for (final notice in widget.store.notifications.items.toList()) {
        final data = notice['payload'] as Map? ?? {};
        if (notice['id'] == item['id'] ||
            (target != null &&
                notice['type'] == item['type'] &&
                (data['match_id'] ??
                        data['conversation_id'] ??
                        data['event_id']) ==
                    target)) {
          await widget.store.notifications.markRead(notice['id'].toString());
        }
      }
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      if (item['type'] == 'habitat_gift') {
        if (!mounted) return;
        Navigator.pop(context);
        HabitatNavigation.focusGift.value = payload['gift_id']?.toString();
        return;
      }
      Widget? page;
      if (item['type'] == 'message' && payload['conversation_id'] != null) {
        page = ConversationPage(
          sessionStore: widget.store.sessionStore,
          conversationId: payload['conversation_id'] as String,
        );
      } else if (item['type'] == 'progress_result' &&
          const [
            'care',
            'review',
            'post',
            'comment',
            'repost',
          ].contains(payload['record_type'])) {
        page = JourneyPage(store: widget.store);
      } else if (item['type'] == 'progress_result' &&
          payload['event_id'] != null) {
        page = DiscoveryResultPage(
          store: widget.store,
          eventId: payload['event_id'] as String,
        );
      } else if (item['type'] == 'match_confirmed' &&
          payload['match_id'] != null) {
        page = ContributionPage(
          store: widget.store,
          matchId: payload['match_id'] as String,
        );
      } else if (item['type'] == 'achievement') {
        page = JourneyPage(store: widget.store, initialSection: 'achievement');
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
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(
              name: page is DiscoveryResultPage ? '/result' : null,
            ),
            builder: (_) => page!,
          ),
        );
      }
      if (mounted) _load();
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BotanicalScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
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

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: IllustratedPaperHeading(
                        title: 'Seu correio do Gatálogo',
                        description: 'Avistamentos, mensagens e conquistas chegam por aqui.',
                        art: 'icons/icon_bell_gold_coral',
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
                              IllustratedGardenStage(
                                height: 172,
                                child: GatalogoArt.image(
                                  'environment/environment_mailbox_coral',
                                  width: 132,
                                  height: 140,
                                ),
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
                                  GatalogoArt.image(
                                    _artForType(type),
                                    width: 44,
                                    height: 48,
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
                                                '${_items.indexOf(item) == 0 || _section(_items[_items.indexOf(item) - 1]) != _section(item) ? '${const ['Buscas e pistas', 'Conversas', 'Novidades do jogo'][_section(item)]}\n' : ''}${_title(item)}',
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
