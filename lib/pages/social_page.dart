import '../widgets/feed_loading_placeholder.dart';
import '../stores/notification_store.dart';
import '../widgets/botanical_scene.dart';
import '../widgets/community_post_card.dart';
import '../widgets/illustrated_home_components.dart';
import 'community_posters_page.dart';
import '../widgets/app_header_actions.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import '../services/cat_sharing_service.dart';
import '../services/social_api_service.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/post_composer.dart';
import '../widgets/social_publish_button.dart';
import '../widgets/gatalogo_components.dart';
import 'auth_page.dart';
import 'friends_page.dart';
import 'inbox_page.dart';
import 'public_profile_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({
    super.key,
    required this.sessionStore,
    this.catStore,
    this.initialTab = 0,
    this.api,
    this.onNavigate,
  });

  final SessionStore sessionStore;
  final CatStore? catStore;
  final int initialTab;
  final SocialApiService? api;
  final ValueChanged<int>? onNavigate;

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final SocialApiService _api;
  late final ScrollController _scrollController;
  int _feedGeneration = 0;
  bool _loading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _contentType = 'all';
  String get _queryMode =>
      _contentType == 'all' ? _feedMode : '$_feedMode:$_contentType';
  String _feedMode = 'all'; // 'all' (comunidade) ou 'friends'
  final Map<String, Uint8List> _base64Cache = {};
  String? _error;
  List<Map<String, dynamic>> _feed = [];
  StreamSubscription? _wsSub;
  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;
  int _currentTab = 0;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _api = widget.api ?? SocialApiService(widget.sessionStore);
    _scrollController = ScrollController()..addListener(_onScroll);
    _load();
    _fetchUnread();
    _wsSub = widget.sessionStore.webSocket.onFeedUpdate.listen(
      _handleFeedUpdate,
    );
    _msgSub = widget.sessionStore.webSocket.onMessage.listen(
      (_) => _fetchUnread(),
    );
    _readSub = widget.sessionStore.webSocket.onMessagesRead.listen(
      (_) => _fetchUnread(),
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        !_isLoadingMore &&
        _hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _fetchUnread() async {
    if (!widget.sessionStore.isSignedIn) return;
    try {
      final list = await _api.conversations();
      int count = 0;
      for (final item in list) {
        count += (item['unread_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wsSub?.cancel();
    _msgSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }

  void _handleFeedUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type']?.toString();
    final itemId = data['item_id']?.toString();

    if (type == 'like_update' && itemId != null) {
      final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
      if (index != -1) {
        final raw = _feed[index]['payload'];
        final payload = raw is Map<String, dynamic>
            ? raw
            : (_feed[index]['payload'] = Map<String, dynamic>.from(
                raw as Map? ?? {},
              ));
        final likesCount = (data['likes_count'] as num?)?.toInt();
        final eventUserId = data['user_id']?.toString();
        final isMe =
            eventUserId != null &&
            eventUserId == widget.sessionStore.session?.userId;

        setState(() {
          if (likesCount != null) payload['likes_count'] = likesCount;
          if (isMe && data.containsKey('liked')) {
            payload['has_liked'] = data['liked'] == true;
          }
        });
      }
    } else if (type == 'new_comment' && itemId != null) {
      final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
      if (index != -1) {
        final raw = _feed[index]['payload'];
        final payload = raw is Map<String, dynamic>
            ? raw
            : (_feed[index]['payload'] = Map<String, dynamic>.from(
                raw as Map? ?? {},
              ));
        final newComment = data['comment'];
        final comments = List<dynamic>.from(payload['comments'] as List? ?? []);
        if (newComment is Map &&
            !comments.any((c) => c is Map && c['id'] == newComment['id'])) {
          comments.add(newComment);
          setState(() {
            payload['comments'] = comments;
          });
        }
      }
    } else if (type == 'new_post') {
      _load(refresh: true);
    }
  }

  Future<void> _load({bool refresh = true}) async {
    if (!widget.sessionStore.isSignedIn) return;
    final generation = ++_feedGeneration;
    final mode = _queryMode;
    if (refresh) {
      setState(() {
        _loading = true;
        _hasMore = true;
        _error = null;
      });
    }
    try {
      final items = await _api.feed(limit: 15, mode: mode);
      if (mounted && generation == _feedGeneration) {
        setState(() {
          _feed = items..sort(NotificationStore.newestFirst);
          _hasMore = items.length >= 15;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _feedGeneration) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _feedGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _isLoadingMore || !_hasMore || _feed.isEmpty) return;
    final generation = _feedGeneration;
    final mode = _queryMode;
    final lastItem = _feed.last;
    final cursor = lastItem['created_at']?.toString();
    if (cursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final moreItems = await _api.feed(
        limit: 15,
        cursor: cursor,
        cursorId: lastItem['id']?.toString(),
        mode: mode,
      );
      if (mounted && generation == _feedGeneration) {
        setState(() {
          final existingIds = _feed.map((it) => it['id']?.toString()).toSet();
          final newUnique = moreItems
              .where((it) => !existingIds.contains(it['id']?.toString()))
              .toList();
          _feed.addAll(newUnique);
          _feed.sort(NotificationStore.newestFirst);
          _hasMore = moreItems.length >= 15;
        });
      }
    } catch (_) {
      // Ignora falha de paginação silenciosamente
    } finally {
      if (mounted && generation == _feedGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _toggleLike(String itemId) async {
    final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
    if (index == -1) return;

    final rawPayload = _feed[index]['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (_feed[index]['payload'] = Map<String, dynamic>.from(
            rawPayload as Map? ?? {},
          ));

    final wasLiked = payload['has_liked'] == true;
    final currentLikes = (payload['likes_count'] as num?)?.toInt() ?? 0;
    final newLiked = !wasLiked;
    final newLikes = newLiked
        ? (currentLikes + 1)
        : (currentLikes > 0 ? currentLikes - 1 : 0);

    // Atualização otimista imediata na memória
    setState(() {
      payload['has_liked'] = newLiked;
      payload['likes_count'] = newLikes;
    });

    try {
      final result = await _api.toggleLike(itemId);
      if (mounted) {
        setState(() {
          payload['has_liked'] = result['liked'] == true;
          payload['likes_count'] =
              result['likes_count'] ?? payload['likes_count'];
        });
      }
    } catch (e) {
      // Reverter se houver erro de rede
      if (mounted) {
        setState(() {
          payload['has_liked'] = wasLiked;
          payload['likes_count'] = currentLikes;
        });
        showMessage(context, 'Não foi possível curtir agora: $e');
      }
    }
  }

  void _showCommentsModal(String itemId, String postTitle) {
    final index = _feed.indexWhere((it) => it['id']?.toString() == itemId);
    if (index == -1) return;

    final rawPayload = _feed[index]['payload'];
    final Map<String, dynamic> payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : (_feed[index]['payload'] = Map<String, dynamic>.from(
            rawPayload as Map? ?? {},
          ));

    final textController = TextEditingController();
    List<dynamic> comments = List.from(payload['comments'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SizedBox(
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.messageCircle,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Comentários • $postTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.borderLight),
                  Expanded(
                    child: comments.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum comentário ainda. Deixe uma mensagem!',
                              style: GoogleFonts.nunito(
                                color: AppColors.textMedium,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: comments.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final comment = comments[i] as Map;
                              final author =
                                  comment['username']?.toString() ?? 'amigo';
                              final text = comment['text']?.toString() ?? '';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PublicProfilePage(
                                              username: author,
                                              sessionStore: widget.sessionStore,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.pets,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '@$author',
                                            style: GoogleFonts.fredoka(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textTitle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: 'Escreva um comentário...',
                            hintStyle: GoogleFonts.nunito(fontSize: 13),
                            filled: true,
                            fillColor: AppColors.inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.send, size: 18),
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isEmpty) return;
                          textController.clear();

                          final tempId =
                              'temp_${DateTime.now().millisecondsSinceEpoch}';
                          final myName =
                              widget.sessionStore.session?.email
                                  .split('@')
                                  .first ??
                              'eu';
                          final optimisticComment = {
                            'id': tempId,
                            'username': myName,
                            'text': text,
                            'created_at': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                          };

                          // 1. Atualização otimista imediata no modal e no feed
                          setModalState(() {
                            comments = [...comments, optimisticComment];
                          });
                          setState(() {
                            payload['comments'] = List.from(comments);
                          });

                          try {
                            final updatedComments = await _api.addComment(
                              itemId,
                              text,
                            );
                            widget.catStore?.recordGamificationAction(
                              'comment',
                            );
                            if (context.mounted) {
                              setModalState(() {
                                comments = updatedComments;
                              });
                            }
                            if (mounted) {
                              setState(() {
                                payload['comments'] = updatedComments;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setModalState(() {
                                comments = comments
                                    .where(
                                      (c) => (c is Map && c['id'] != tempId),
                                    )
                                    .toList();
                              });
                              showMessage(
                                context,
                                'Erro ao enviar comentário: $e',
                              );
                            }
                            if (mounted) {
                              setState(() {
                                payload['comments'] = List.from(comments);
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showShareCatModal() async {
    final post = await showPostComposer(
      context,
      session: widget.sessionStore,
      cats: widget.catStore?.discoveries ?? [],
    );
    if (post == null || !mounted) return;
    await _load();
    await widget.catStore?.refreshGamification();
  }

  Widget _buildPostMedia(Map<String, dynamic> payload) {
    final photoUrl = payload['photo_url']?.toString();
    final encoded = payload['photo_base64']?.toString();
    Widget? photo;
    Widget failed() => const Center(
      child: Icon(LucideIcons.imageOff, color: AppColors.textMedium),
    );
    if (photoUrl?.isNotEmpty == true) {
      final full = photoUrl!.startsWith('http')
          ? photoUrl
          : '${ApiConfig.baseUrl}$photoUrl';
      final token = widget.sessionStore.session?.accessToken;
      photo = Image.network(
        full,
        fit: BoxFit.cover,
        cacheWidth: 1000,
        headers: full.startsWith(ApiConfig.baseUrl) && token != null
            ? {'Authorization': 'Bearer $token'}
            : null,
        errorBuilder: (_, _, _) => failed(),
      );
    } else if (encoded?.isNotEmpty == true) {
      try {
        final bytes = _base64Cache.putIfAbsent(
          encoded!,
          () => base64Decode(encoded),
        );
        photo = Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 1000,
          errorBuilder: (_, _, _) => failed(),
        );
      } catch (_) {
        photo = failed();
      }
    }
    if (photo == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(color: AppColors.cardBackground, child: photo),
      ),
    );
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    if (page is CommunityPostersPage) {
      await _load();
      await widget.catStore?.refreshGamification();
    }
  }

  String _when(dynamic value) {
    final time = DateTime.tryParse(value?.toString() ?? '');
    if (time == null) return '';
    final days = DateTime.now().difference(time).inDays;
    return days == 0
        ? 'Hoje'
        : days == 1
        ? 'Ontem'
        : 'Há $days dias';
  }

  Widget _post(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final author = item['username']?.toString() ?? 'Pessoa da comunidade';
    final type = item['type']?.toString();
    final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
    final location = payload['location_name']?.toString();
    final note = payload['note']?.toString() ?? '';
    final cat = payload['cat_name']?.toString() ?? '';
    final isMilestone = type == 'achievement';
    final caption = isMilestone
        ? payload['title']?.toString() ?? 'Conquista compartilhada'
        : [
            if (cat.isNotEmpty && cat != 'Gato') cat,
            note,
          ].where((v) => v.isNotEmpty).join(' · ');
    void profile() => _open(
      PublicProfilePage(username: author, sessionStore: widget.sessionStore),
    );
    void share() {
      if (type == 'poster_repost' && payload['report_id'] != null) {
        _open(
          CommunityCasePage(
            session: widget.sessionStore,
            reportId: payload['report_id'].toString(),
          ),
        );
        return;
      }
      CatSharingService.sharePost(
        author: author,
        catName: cat,
        note: note,
        location: location,
      );
    }

    return CommunityPostCard(
      author: '@$author',
      when: _when(item['created_at']),
      note: caption,
      avatarUrl: payload['author_avatar_url']?.toString(),
      location: location,
      media: isMilestone
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: GatalogoArt.image(
                'icons/icon_reward_chest_star',
                height: 90,
              ),
            )
          : _buildPostMedia(payload),
      liked: payload['has_liked'] == true,
      likes: (payload['likes_count'] as num?)?.toInt() ?? 0,
      comments:
          (payload['comments_count'] as num?)?.toInt() ??
          (payload['comments'] as List? ?? []).length,
      onAuthor: profile,
      onLike: () => _toggleLike(id),
      onComment: () => _showCommentsModal(id, cat),
      onShare: share,
      contextualAction: type == 'poster_repost'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cartaz · ${payload['report_status'] == 'active' ? 'Busca ativa' : 'Caso encerrado'}',
                  style: const TextStyle(
                    color: AppColors.errorText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (payload['report_id'] != null)
                  TextButton(
                    onPressed: () => _open(
                      CommunityCasePage(
                        session: widget.sessionStore,
                        reportId: payload['report_id'].toString(),
                      ),
                    ),
                    child: const Text('Abrir busca'),
                  ),
              ],
            )
          : null,
    );
  }

  Widget _feedChoice(String key, String label, IconData icon) => Expanded(
    child: Semantics(
      selected: _feedMode == key,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (_feedMode == key) return;
          setState(() => _feedMode = key);
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          decoration: BoxDecoration(
            color: _feedMode == key
                ? AppColors.greenButton
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: _feedMode == key ? HomeArt.paper : AppColors.textMedium,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: HomeArt.title(12).copyWith(
                    color: _feedMode == key
                        ? HomeArt.paper
                        : AppColors.textMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _filters() => LayoutBuilder(
    builder: (context, box) {
      final choices = [
        ('all', 'Tudo', LucideIcons.sprout),
        ('cat_post', 'Conversas e fotos', LucideIcons.messageCircle),
        ('poster_repost', 'Cartazes', LucideIcons.image),
      ];
      Widget chip((String, String, IconData) choice) => ChoiceChip(
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selected: _contentType == choice.$1,
        selectedColor: AppColors.greenLight,
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: _contentType == choice.$1
              ? AppColors.greenButton
              : AppColors.border,
        ),
        shape: const StadiumBorder(),
        avatar: Icon(choice.$3, size: 16, color: AppColors.greenLink),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        label: Text(
          choice.$2,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: HomeArt.ink,
          ),
        ),
        onSelected: (_) {
          setState(() => _contentType = choice.$1);
          _load();
        },
      );
      if (MediaQuery.textScalerOf(context).scale(1) > 1.2) {
        return Wrap(
          spacing: 7,
          runSpacing: 3,
          children: choices.map(chip).toList(),
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: choices.map(chip).toList(),
      );
    },
  );

  Widget _helpSearch() => Material(
    color: const Color(0xFFFFDCD3),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: () => _open(CommunityPostersPage(session: widget.sessionStore)),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          children: [
            GatalogoArt.image('cats/cat_calico_peeking', width: 42, height: 34),
            GatalogoArt.image('ui/ui_speech_heart', width: 25, height: 25),
            const SizedBox(width: 10),
            Expanded(child: Text('Ajudar uma busca', style: HomeArt.title(12))),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.errorText,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_currentTab == 1 && widget.sessionStore.isSignedIn) {
      return BotanicalScaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => setState(() => _currentTab = 0)),
          title: const Text('Conversas'),
        ),
        body: InboxPage(sessionStore: widget.sessionStore, embedded: true),
      );
    }
    return BotanicalScaffold(
      mood: BotanicalMood.community,
      floatingActionButton:
          widget.sessionStore.isSignedIn &&
              MediaQuery.viewInsetsOf(context).bottom == 0
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: SocialPublishButton(onPressed: _showShareCatModal),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.catStore != null)
                            IllustratedAppHeader(
                              store: widget.catStore!,
                              logoWidth: 140,
                              onWallet: widget.onNavigate == null
                                  ? null
                                  : () => widget.onNavigate!(4),
                            )
                          else
                            GatalogoArt.image(
                              'branding/brand_gatalogo_logo',
                              height: 48,
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EADB),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                _feedChoice(
                                  'all',
                                  'Comunidade',
                                  Icons.pets_rounded,
                                ),
                                _feedChoice(
                                  'friends',
                                  'Amigos',
                                  LucideIcons.usersRound,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          _filters(),
                          const SizedBox(height: 6),
                          _helpSearch(),
                          if (widget.sessionStore.isSignedIn &&
                              _feedMode == 'friends')
                            Wrap(
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _open(
                                    FriendsPage(
                                      sessionStore: widget.sessionStore,
                                    ),
                                  ),
                                  icon: const Icon(
                                    LucideIcons.userPlus,
                                    size: 16,
                                  ),
                                  label: const Text('Gerenciar amigos'),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _currentTab = 1),
                                  icon: Badge(
                                    isLabelVisible: _unreadMessages > 0,
                                    label: Text('$_unreadMessages'),
                                    child: const Icon(
                                      LucideIcons.mail,
                                      size: 16,
                                    ),
                                  ),
                                  label: const Text('Conversas'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.sessionStore.isSignedIn)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: BotanicalEmpty(
                          title: 'Encontros que viram histórias',
                          description: 'Entre para conversar, acompanhar amigos e compartilhar suas descobertas.',
                          art: 'ui/ui_cat_photos_stack',
                          action: GatalogoButton(
                            text: 'Entrar na conta',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AuthPage(
                                    sessionStore: widget.sessionStore,
                                    onContinueOffline: () =>
                                        Navigator.pop(context),
                                  ),
                                ),
                              );
                              if (mounted) _load();
                            },
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (_error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: BotanicalPaper(
                            foliage: false,
                            child: Column(
                              children: [
                                const Text(
                                  'Não foi possível atualizar o feed.',
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_loading && _feed.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: FeedLoadingPlaceholder(),
                      )
                    else if (_feed.isEmpty && _error == null)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: BotanicalEmpty(
                            title: 'Uma comunidade para descobrir',
                            description: 'As publicações compartilhadas aparecem aqui. Que tal contar uma história?',
                            art: 'cats/cat_calico_peeking',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _post(_feed[index]),
                            ),
                            childCount: _feed.length,
                          ),
                        ),
                      ),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: FeedLoadingPlaceholder(),
                        ),
                      ),
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 96 + MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
