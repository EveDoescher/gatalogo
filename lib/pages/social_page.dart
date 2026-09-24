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
import '../widgets/gatalogo_components.dart';
import 'auth_page.dart';
import 'friends_page.dart';
import 'inbox_page.dart';
import 'journey_page.dart';
import 'public_profile_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({
    super.key,
    required this.sessionStore,
    this.catStore,
    this.initialTab = 0,
    this.api,
  });

  final SessionStore sessionStore;
  final CatStore? catStore;
  final int initialTab;
  final SocialApiService? api;

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final SocialApiService _api;
  late final ScrollController _scrollController;
  bool _loading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
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
    if (refresh) {
      setState(() {
        _loading = true;
        _hasMore = true;
        _error = null;
      });
    }
    try {
      final items = await _api.feed(limit: 15, mode: _feedMode);
      if (mounted) {
        setState(() {
          _feed = items;
          _hasMore = items.length >= 15;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _feed.isEmpty) return;
    final lastItem = _feed.last;
    final cursor = lastItem['created_at']?.toString();
    if (cursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final moreItems = await _api.feed(
        limit: 15,
        cursor: cursor,
        mode: _feedMode,
      );
      if (mounted) {
        setState(() {
          final existingIds = _feed.map((it) => it['id']?.toString()).toSet();
          final newUnique = moreItems
              .where((it) => !existingIds.contains(it['id']?.toString()))
              .toList();
          _feed.addAll(newUnique);
          _hasMore = moreItems.length >= 15;
        });
      }
    } catch (_) {
      // Ignora falha de paginação silenciosamente
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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
      if (result['liked'] == true) {
        widget.catStore?.recordGamificationAction('like', contextId: itemId);
      }
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
    setState(() => _feed.insert(0, post));
    await widget.catStore?.recordGamificationAction('post');
  }

  Widget _buildPostMedia(Map<String, dynamic> payload) {
    final photoUrl = payload['photo_url']?.toString();
    final photoBase64 = payload['photo_base64']?.toString();

    if (photoUrl != null && photoUrl.isNotEmpty) {
      final token = widget.sessionStore.session?.accessToken;
      final fullUrl = photoUrl.startsWith('http')
          ? photoUrl
          : '${ApiConfig.baseUrl}$photoUrl${token != null ? '?token=$token' : ''}';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.photo),
          child: SizedBox(
            height: 210,
            width: double.infinity,
            child: Image.network(
              fullUrl,
              fit: BoxFit.cover,
              cacheWidth: 800,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(
                    LucideIcons.imageOff,
                    color: AppColors.textLight,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      Uint8List? cached = _base64Cache[photoBase64];
      if (cached == null) {
        try {
          cached = base64Decode(photoBase64);
          _base64Cache[photoBase64] = cached;
        } catch (_) {}
      }
      if (cached != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.photo),
            child: SizedBox(
              height: 210,
              width: double.infinity,
              child: Image.memory(
                cached,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(
                      LucideIcons.imageOff,
                      color: AppColors.textLight,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sessionStore.isSignedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          actions: [AppHeaderActions(store: widget.catStore)],
          title: Text(
            'Social',
            style: GoogleFonts.fredoka(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.globe,
                    size: 48,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Feed de Amigos & Conexões',
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Entre na sua conta para acompanhar as descobertas e conquistas compartilhadas pelos seus amigos!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GatalogoButton(
                  text: 'Entrar na conta',
                  icon: LucideIcons.logIn,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthPage(
                          sessionStore: widget.sessionStore,
                          onContinueOffline: () => Navigator.pop(context),
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              elevation: 0,
              highlightElevation: 0,
              onPressed: _showShareCatModal,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.camera, size: 20),
              label: Text(
                'Postar Gato',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            // Folhagem decorativa
            Positioned(
              top: -10,
              right: -15,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/Folha_1.png',
                  width: 95,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (Navigator.canPop(context))
                                BackButton(
                                  onPressed: () => Navigator.maybePop(context),
                                ),
                              const Expanded(
                                child: Text(
                                  'Social',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTitle,
                                  ),
                                ),
                              ),
                              AppHeaderActions(store: widget.catStore),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FriendsPage(
                                      sessionStore: widget.sessionStore,
                                    ),
                                  ),
                                ),
                                icon: const Icon(LucideIcons.users, size: 18),
                                label: const Text('Amigos'),
                              ),
                              if (widget.catStore != null)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          JourneyPage(store: widget.catStore!),
                                    ),
                                  ),
                                  icon: const Icon(
                                    LucideIcons.trophy,
                                    size: 18,
                                  ),
                                  label: const Text('Conquistas'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Segmented Bar: Feed Social vs Conversas (com badge de não lidas)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              onTap: () => setState(() => _currentTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentTab == 0
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.newspaper,
                                      size: 16,
                                      color: _currentTab == 0
                                          ? Colors.white
                                          : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Feed Social',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _currentTab == 0
                                            ? Colors.white
                                            : AppColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              onTap: () => setState(() => _currentTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentTab == 1
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.messageSquare,
                                      size: 16,
                                      color: _currentTab == 1
                                          ? Colors.white
                                          : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Conversas',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _currentTab == 1
                                            ? Colors.white
                                            : AppColors.textMedium,
                                      ),
                                    ),
                                    if (_unreadMessages > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _currentTab == 1
                                              ? Colors.white
                                              : AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                        ),
                                        child: Text(
                                          '$_unreadMessages',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _currentTab == 1
                                                ? AppColors.primary
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_currentTab == 1)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: InboxPage(
                        sessionStore: widget.sessionStore,
                        embedded: true,
                      ),
                    )
                  else ...[
                    // Barra de Filtro de Feed e Ação de Postar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Row(
                          children: [
                            // Pills: Comunidade vs Amigos
                            InkWell(
                              onTap: () {
                                if (_feedMode != 'all') {
                                  setState(() => _feedMode = 'all');
                                  _load(refresh: true);
                                }
                              },
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _feedMode == 'all'
                                      ? AppColors.primary
                                      : AppColors.cardAltBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  border: Border.all(
                                    color: _feedMode == 'all'
                                        ? AppColors.primary
                                        : AppColors.borderLight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.globe,
                                      size: 13,
                                      color: _feedMode == 'all'
                                          ? Colors.white
                                          : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Comunidade',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _feedMode == 'all'
                                            ? Colors.white
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                if (_feedMode != 'friends') {
                                  setState(() => _feedMode = 'friends');
                                  _load(refresh: true);
                                }
                              },
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _feedMode == 'friends'
                                      ? AppColors.primary
                                      : AppColors.cardAltBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  border: Border.all(
                                    color: _feedMode == 'friends'
                                        ? AppColors.primary
                                        : AppColors.borderLight,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.users,
                                      size: 13,
                                      color: _feedMode == 'friends'
                                          ? Colors.white
                                          : AppColors.textMedium,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Amigos',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _feedMode == 'friends'
                                            ? Colors.white
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Erro de Conexão
                    if (_error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.alertCircle,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Não foi possível atualizar o feed: $_error',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: AppColors.errorText,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.refreshCw,
                                    size: 16,
                                  ),
                                  onPressed: _load,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Feed de Itens Reais
                    if (_feed.isEmpty && !_loading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/gato_2.png',
                                  width: 90,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma atividade recente',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTitle,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Quando você ou seus amigos compartilharem conquistas ou postarem fotos de gatos, elas aparecerão aqui!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FriendsPage(
                                            sessionStore: widget.sessionStore,
                                          ),
                                        ),
                                      ).then((_) => _load()),
                                      icon: const Icon(
                                        LucideIcons.userPlus,
                                        size: 16,
                                      ),
                                      label: const Text('Convidar Amigos'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: _showShareCatModal,
                                      icon: const Icon(
                                        LucideIcons.camera,
                                        size: 16,
                                      ),
                                      label: const Text('Postar Gato'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = _feed[index];
                            final itemId = item['id']?.toString() ?? '';
                            final author =
                                item['username']?.toString() ?? 'amigo';
                            final type = item['type']?.toString() ?? '';
                            final payload =
                                item['payload'] is Map<String, dynamic>
                                ? (item['payload'] as Map<String, dynamic>)
                                : (item['payload'] = Map<String, dynamic>.from(
                                    item['payload'] as Map? ?? {},
                                  ));

                            // 1. Item do Tipo: Conquista Compartilhada
                            if (type == 'achievement') {
                              final title =
                                  payload['title']?.toString() ??
                                  'Nova Conquista!';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
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
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.achievementBg,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.achievement.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.achievement
                                                .withValues(alpha: 0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.trophy,
                                            size: 20,
                                            color: AppColors.achievementDark,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '@$author desbloqueou um marco!',
                                                style: GoogleFonts.fredoka(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.achievementText,
                                                ),
                                              ),
                                              Text(
                                                title,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.pets,
                                          size: 16,
                                          color: AppColors.achievementText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            // 2. Item do Tipo: Postagem de Gato
                            final catName =
                                payload['cat_name']?.toString() ?? 'Gato';
                            final note = payload['note']?.toString() ?? '';
                            final location = payload['location_name']
                                ?.toString();
                            final hasLiked = payload['has_liked'] == true;
                            final likesCount =
                                (payload['likes_count'] as num?)?.toInt() ?? 0;
                            final commentsList =
                                payload['comments'] as List? ?? [];
                            final rawAvatar = payload['author_avatar_url']
                                ?.toString();
                            final authorAvatarUrl =
                                rawAvatar != null && rawAvatar.isNotEmpty
                                ? (rawAvatar.startsWith('http')
                                      ? rawAvatar
                                      : '${ApiConfig.baseUrl}$rawAvatar${widget.sessionStore.session?.accessToken != null ? '?token=${widget.sessionStore.session!.accessToken}' : ''}')
                                : null;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.borderLight,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar do Autor (Esquerda)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(20),
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
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        margin: const EdgeInsets.only(
                                          top: 4,
                                          right: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoftBg,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.borderProfile,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: authorAvatarUrl != null
                                              ? Image.network(
                                                  authorAvatarUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      const Icon(
                                                        LucideIcons.user,
                                                        size: 20,
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                )
                                              : const Icon(
                                                  LucideIcons.user,
                                                  size: 20,
                                                  color: AppColors.primaryDark,
                                                ),
                                        ),
                                      ),
                                    ),

                                    // Conteúdo (Direita)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Nome e Local
                                          Row(
                                            children: [
                                              Text(
                                                '@$author',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.fredoka(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textTitle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (location != null &&
                                                  location.isNotEmpty)
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        LucideIcons.mapPin,
                                                        size: 12,
                                                        color:
                                                            AppColors.textLight,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          location,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              GoogleFonts.nunito(
                                                                fontSize: 12,
                                                                color: AppColors
                                                                    .textLight,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),

                                          // Mensagem/Nota
                                          if (note.isNotEmpty ||
                                              catName != 'Gato')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Text.rich(
                                                TextSpan(
                                                  children: [
                                                    if (catName != 'Gato')
                                                      TextSpan(
                                                        text: '$catName ',
                                                        style:
                                                            GoogleFonts.fredoka(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: AppColors
                                                                  .textTitle,
                                                            ),
                                                      ),
                                                    TextSpan(
                                                      text: note,
                                                      style: GoogleFonts.nunito(
                                                        fontSize: 14,
                                                        color:
                                                            AppColors.textDark,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                          // Midia do Gato
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: _buildPostMedia(payload),
                                          ),
                                          const SizedBox(height: 8),

                                          // Ações
                                          Row(
                                            children: [
                                              // Comentar
                                              InkWell(
                                                onTap: () => _showCommentsModal(
                                                  itemId,
                                                  catName,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.pill,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        LucideIcons
                                                            .messageCircle,
                                                        size: 16,
                                                        color: AppColors
                                                            .textMedium,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '${commentsList.length}',
                                                        style:
                                                            GoogleFonts.nunito(
                                                              fontSize: 13,
                                                              color: AppColors
                                                                  .textMedium,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              // Curtir
                                              InkWell(
                                                onTap: () =>
                                                    _toggleLike(itemId),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.pill,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        hasLiked
                                                            ? Icons.pets
                                                            : Icons
                                                                  .pets_outlined,
                                                        size: 16,
                                                        color: hasLiked
                                                            ? AppColors.primary
                                                            : AppColors
                                                                  .textMedium,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '$likesCount',
                                                        style: GoogleFonts.nunito(
                                                          fontSize: 13,
                                                          fontWeight: hasLiked
                                                              ? FontWeight.w700
                                                              : FontWeight
                                                                    .normal,
                                                          color: hasLiked
                                                              ? AppColors
                                                                    .primary
                                                              : AppColors
                                                                    .textMedium,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              // Compartilhar
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  LucideIcons.share2,
                                                  size: 16,
                                                  color: AppColors.textLight,
                                                ),
                                                onPressed: () async {
                                                  final shared = await CatSharingService.sharePost(
                                                    author: author,
                                                    catName: catName,
                                                    note: note,
                                                    location: location,
                                                  );
                                                  if (shared) {
                                                    widget.catStore?.recordGamificationAction('share', contextId: itemId);
                                                    widget.catStore?.recordHabitatAction(
                                                      'share', targetType: 'post', targetId: itemId,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: _feed.length),
                        ),
                      ),
                  ],

                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
