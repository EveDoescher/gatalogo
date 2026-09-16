import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../services/product_api_service.dart';
import '../services/social_api_service.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import '../widgets/profile_qr_dialog.dart';
import 'conversation_page.dart';
import 'public_profile_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.sessionStore});

  final SessionStore sessionStore;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with SingleTickerProviderStateMixin {
  late final SocialApiService _api;
  late final ProductApiService _product;
  late final TabController _tabController;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = false;
  bool _searching = false;
  bool _busy = false;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _invites = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _nearbySuggestions = [];
  List<Map<String, dynamic>> _leaderboard = [];

  bool _nearbyOptIn = false;
  StreamSubscription? _wsSub;

  String get _currentUsername => widget.sessionStore.session?.username ?? 'explorador';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _api = SocialApiService(widget.sessionStore);
    _product = ProductApiService(widget.sessionStore);
    _loadAll();
    _wsSub = widget.sessionStore.webSocket.onNotification.listen((_) => _loadAll());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!widget.sessionStore.isSignedIn) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.friends(),
        _api.invites(),
        _api.getSuggestions(nearby: false),
        _api.getWeeklyLeaderboard(),
      ]);
      if (mounted) {
        setState(() {
          _friends = results[0];
          _invites = results[1];
          _suggestions = results[2];
          _leaderboard = results[3];
        });
      }
      if (_nearbyOptIn) {
        final nearby = await _api.getSuggestions(nearby: true);
        if (mounted) setState(() => _nearbySuggestions = nearby);
      }
    } catch (_) {
      // Offline fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _api.searchUsers(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _sendInvite(String username) async {
    setState(() => _busy = true);
    try {
      await _api.invite(username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Convite enviado para @$username!')),
        );
        _searchController.clear();
        _searchResults.clear();
      }
      await _loadAll();
    } catch (e) {
      if (mounted) showMessage(context, 'Não foi possível enviar convite: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decideInvite(String inviteId, bool accept) async {
    final inviteIdx = _invites.indexWhere((i) => i['id'] == inviteId);
    if (inviteIdx == -1) return;
    final invite = _invites[inviteIdx];
    final sender = (invite['sender'] as Map?) != null
        ? Map<String, dynamic>.from(invite['sender'] as Map)
        : null;

    setState(() {
      _invites.removeAt(inviteIdx);
      if (accept && sender != null) {
        _friends.add(sender);
      }
    });

    try {
      await _api.decideInvite(inviteId, accept);
      _loadAll();
    } catch (e) {
      if (mounted) {
        setState(() {
          _invites.insert(inviteIdx, invite);
          if (accept && sender != null) {
            _friends.removeWhere((f) => f['id'] == sender['id']);
          }
        });
        showMessage(context, 'Não foi possível responder ao convite: $e');
      }
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    setState(() => _busy = true);
    try {
      await _api.cancelInvite(inviteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite cancelado com sucesso.')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) showMessage(context, 'Não foi possível cancelar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    final confirmed = await confirmAction(
      context,
      'Remover amigo?',
      'Deseja remover @$friendName da sua lista de conexões?',
      'Remover',
    );
    if (!confirmed) return;

    final idx = _friends.indexWhere((f) => f['id']?.toString() == friendId);
    if (idx == -1) return;
    final removed = _friends[idx];

    setState(() => _friends.removeAt(idx));

    try {
      await _api.removeFriend(friendId);
      _loadAll();
    } catch (e) {
      if (mounted) {
        setState(() => _friends.insert(idx, removed));
        showMessage(context, 'Não foi possível remover amigo: $e');
      }
    }
  }

  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(
          username: username,
          sessionStore: widget.sessionStore,
        ),
      ),
    );
  }

  void _openConversation(String friendId) async {
    setState(() => _busy = true);
    try {
      final conv = await _product.post('/app/friends/$friendId/conversation');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationPage(
              sessionStore: widget.sessionStore,
              conversationId: conv['id'] as String,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Erro ao abrir conversa: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showQrCode() {
    showDialog(
      context: context,
      builder: (_) => ProfileQrDialog(username: _currentUsername),
    );
  }

  void _shareProfileLink() {
    final url = 'https://gatalogo.app/u/$_currentUsername';
    SharePlus.instance.share(
      ShareParams(
        text: 'Vamos nos conectar no Gatálogo! Veja minhas descobertas de gatos: $url',
        subject: 'Convite de amizade no Gatálogo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.sessionStore.session?.userId;
    final receivedInvites = _invites.where(
      (item) =>
          item['status'] == 'pending' &&
          (item['recipient'] as Map?)?['id'] == currentUserId,
    ).toList();
    final sentInvites = _invites.where(
      (item) =>
          item['status'] == 'pending' &&
          (item['sender'] as Map?)?['id'] == currentUserId,
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Comunidade & Amigos',
          style: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Meu QR Code',
            icon: const Icon(LucideIcons.qrCode, color: AppColors.primary, size: 20),
            onPressed: _showQrCode,
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.textMedium, size: 18),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMedium,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Amigos (${_friends.length})'),
            const Tab(text: 'Descobrir'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Convites'),
                  if (receivedInvites.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${receivedInvites.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Ranking'),
          ],
        ),
      ),
      body: _loading && _friends.isEmpty && _suggestions.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildDiscoverTab(),
                _buildInvitesTab(receivedInvites, sentInvites),
                _buildLeaderboardTab(),
              ],
            ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: Amigos
  // -------------------------------------------------------------
  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/gato_2.png', width: 90),
              const SizedBox(height: 14),
              Text(
                'Nenhum amigo conectado ainda',
                style: GoogleFonts.fredoka(fontSize: 18, color: AppColors.textTitle),
              ),
              const SizedBox(height: 6),
              Text(
                'Descubra exploradores na aba Descobrir ou compartilhe seu QR Code para conectar-se com outros gateiros!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(LucideIcons.userPlus, size: 16),
                label: const Text('Descobrir Pessoas'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final friendName = friend['username']?.toString() ?? 'amigo';
          final friendBio = friend['bio']?.toString() ?? '';
          final avatarUrl = friend['avatar_url']?.toString();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GatalogoCard(
              backgroundColor: AppColors.surface,
              onTap: () => _openProfile(friendName),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoftBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderProfile, width: 1.4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl.startsWith('http') ? avatarUrl : '${ApiConfig.baseUrl}$avatarUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              LucideIcons.user,
                              color: AppColors.primaryDark,
                              size: 22,
                            ),
                          )
                        : const Icon(
                            LucideIcons.user,
                            color: AppColors.primaryDark,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@$friendName',
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                        ),
                        Text(
                          friendBio.isNotEmpty ? friendBio : 'Toque para ver o perfil completo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Conversar',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.greenLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.messageCircle,
                        size: 16,
                        color: AppColors.greenLink,
                      ),
                    ),
                    onPressed: _busy ? null : () => _openConversation(friend['id'] as String),
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.textLight),
                    onPressed: () => _removeFriend(friend['id'] as String, friendName),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Descobrir Amigos
  // -------------------------------------------------------------
  Widget _buildDiscoverTab() {
    final queryActive = _searchController.text.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // Ações Rápidas de Conexão (QR Code + Compartilhar Link)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.borderProfile, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _showQrCode,
                  icon: const Icon(LucideIcons.qrCode, size: 16),
                  label: const Text('Meu QR Code'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _shareProfileLink,
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const Text('Convidar Amigo'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Campo de Busca com Autocomplete Instantâneo
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Buscar exploradores por @nome...',
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMedium),
                suffixIcon: queryActive
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textMedium),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Se estiver pesquisando
          if (queryActive) ...[
            Text(
              'Resultados da Busca',
              style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textTitle),
            ),
            const SizedBox(height: 8),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhum explorador encontrado para essa busca.',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                  ),
                ),
              )
            else
              ..._searchResults.map((user) => _buildUserSearchCard(user)),
          ] else ...[
            // Sugestões de Amigos
            if (_suggestions.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Sugestões para Você',
                    style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textTitle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._suggestions.map((sugg) => _buildSuggestionCard(sugg)),
              const SizedBox(height: 16),
            ],

            // Exploradores Perto de Você (Opt-in)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoftBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exploradores Perto de Você',
                              style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textTitle),
                            ),
                            Text(
                              'Descoberta de gateiros regionais de forma anônima e segura',
                              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMedium),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _nearbyOptIn,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          setState(() => _nearbyOptIn = val);
                          if (val) {
                            final nearby = await _api.getSuggestions(nearby: true);
                            if (mounted) setState(() => _nearbySuggestions = nearby);
                          }
                        },
                      ),
                    ],
                  ),
                  if (_nearbyOptIn) ...[
                    const SizedBox(height: 12),
                    if (_nearbySuggestions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nenhum outro explorador regional ativo no momento.',
                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
                        ),
                      )
                    else
                      ..._nearbySuggestions.map((sugg) => _buildSuggestionCard(sugg)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserSearchCard(Map<String, dynamic> user) {
    final username = user['username']?.toString() ?? 'explorador';
    final bio = user['bio']?.toString() ?? '';
    final avatarUrl = user['avatar_url']?.toString();
    final status = user['friendship_status']?.toString() ?? 'none';
    final mutual = user['mutual_friends_count'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GatalogoCard(
        backgroundColor: AppColors.surface,
        onTap: () => _openProfile(username),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoftBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderProfile),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl.startsWith('http') ? avatarUrl : '${ApiConfig.baseUrl}$avatarUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
                    )
                  : const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textTitle),
                  ),
                  if (mutual > 0)
                    Text(
                      '$mutual amigo(s) em comum',
                      style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                    )
                  else if (bio.isNotEmpty)
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMedium),
                    ),
                ],
              ),
            ),
            if (status == 'none')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _busy ? null : () => _sendInvite(username),
                child: Text('Conectar', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12)),
              )
            else if (status == 'friends')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('Amigos', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.greenLink)),
              )
            else if (status == 'pending_sent')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardAltBackground,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('Enviado', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMedium)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> sugg) {
    final username = sugg['username']?.toString() ?? 'explorador';
    final reason = sugg['reason']?.toString() ?? 'Explorador ativo';
    final avatarUrl = sugg['avatar_url']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GatalogoCard(
        backgroundColor: AppColors.surface,
        onTap: () => _openProfile(username),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoftBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderProfile),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl.startsWith('http') ? avatarUrl : '${ApiConfig.baseUrl}$avatarUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
                    )
                  : const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textTitle),
                  ),
                  Text(
                    reason,
                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _busy ? null : () => _sendInvite(username),
              child: Text('Conectar', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: Convites (Recebidos & Enviados)
  // -------------------------------------------------------------
  Widget _buildInvitesTab(List<Map<String, dynamic>> received, List<Map<String, dynamic>> sent) {
    if (received.isEmpty && sent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.mailCheck, size: 48, color: AppColors.textLight),
              const SizedBox(height: 12),
              Text(
                'Nenhum convite pendente',
                style: GoogleFonts.fredoka(fontSize: 18, color: AppColors.textTitle),
              ),
              const SizedBox(height: 6),
              Text(
                'Quando alguém te convidar ou você enviar um convite de amizade, eles aparecerão aqui.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // Convites Recebidos
          if (received.isNotEmpty) ...[
            Text(
              'Convites Recebidos (${received.length})',
              style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textTitle),
            ),
            const SizedBox(height: 8),
            ...received.map((invite) {
              final sender = invite['sender'] as Map? ?? {};
              final senderName = sender['username']?.toString() ?? 'explorador';
              final inviteId = invite['id'] as String;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GatalogoCard(
                  backgroundColor: AppColors.primarySoftBg,
                  onTap: () => _openProfile(senderName),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.mail, size: 20, color: AppColors.primaryDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@$senderName quer ser seu amigo!',
                          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Aceitar',
                        icon: const Icon(LucideIcons.check, color: AppColors.greenLink),
                        onPressed: () => _decideInvite(inviteId, true),
                      ),
                      IconButton(
                        tooltip: 'Recusar',
                        icon: const Icon(LucideIcons.x, color: AppColors.error),
                        onPressed: () => _decideInvite(inviteId, false),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Convites Enviados
          if (sent.isNotEmpty) ...[
            Text(
              'Convites Enviados (${sent.length})',
              style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textTitle),
            ),
            const SizedBox(height: 8),
            ...sent.map((invite) {
              final recipient = invite['recipient'] as Map? ?? {};
              final recipientName = recipient['username']?.toString() ?? 'explorador';
              final inviteId = invite['id'] as String;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GatalogoCard(
                  backgroundColor: AppColors.surface,
                  onTap: () => _openProfile(recipientName),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 18, color: AppColors.textLight),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$recipientName',
                              style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTitle),
                            ),
                            Text(
                              'Aguardando resposta do amigo',
                              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMedium),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: _busy ? null : () => _cancelInvite(inviteId),
                        icon: const Icon(LucideIcons.xCircle, size: 15),
                        label: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: Ranking Semanal (Leaderboard)
  // -------------------------------------------------------------
  Widget _buildLeaderboardTab() {
    if (_leaderboard.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.trophy, size: 48, color: AppColors.amberDark),
              const SizedBox(height: 12),
              Text(
                'Sem ranking semanal ainda',
                style: GoogleFonts.fredoka(fontSize: 18, color: AppColors.textTitle),
              ),
              const SizedBox(height: 6),
              Text(
                'Adicione amigos para disputar quem ganha mais XP e mantém as maiores sequências no Gatálogo!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) {
          final entry = _leaderboard[index];
          final rank = entry['rank'] as int? ?? (index + 1);
          final username = entry['username']?.toString() ?? 'explorador';
          final xp = entry['xp'] as int? ?? 0;
          final level = entry['level'] as int? ?? 1;
          final streak = entry['streak'] as int? ?? 0;
          final isSelf = entry['is_self'] == true;
          final avatarUrl = entry['avatar_url']?.toString();

          Color rankColor = AppColors.textMedium;
          IconData? rankIcon;
          if (rank == 1) {
            rankColor = AppColors.amberDark;
            rankIcon = LucideIcons.trophy;
          } else if (rank == 2) {
            rankColor = const Color(0xFF9E9E9E);
            rankIcon = LucideIcons.medal;
          } else if (rank == 3) {
            rankColor = const Color(0xFFCD7F32);
            rankIcon = LucideIcons.award;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelf ? AppColors.primarySoftBg : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelf ? AppColors.primary : AppColors.borderLight,
                  width: isSelf ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: rankIcon != null
                          ? Icon(rankIcon, size: 20, color: rankColor)
                          : Text(
                              '$rankº',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: rankColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderProfile),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl.startsWith('http') ? avatarUrl : '${ApiConfig.baseUrl}$avatarUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
                          )
                        : const Icon(LucideIcons.user, size: 20, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@$username',
                              style: GoogleFonts.fredoka(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTitle,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Você',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Nível $level',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMedium,
                              ),
                            ),
                            if (streak > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.flame, size: 12, color: AppColors.amberDark),
                              const SizedBox(width: 2),
                              Text(
                                '$streak d',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.amberDark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.achievementBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$xp XP',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.amberDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
