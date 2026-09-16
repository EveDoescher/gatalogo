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
import 'conversation_page.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.username,
    required this.sessionStore,
  });

  final String username;
  final SessionStore sessionStore;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  late final SocialApiService _socialApi;
  late final ProductApiService _productApi;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _socialApi = SocialApiService(widget.sessionStore);
    _productApi = ProductApiService(widget.sessionStore);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _socialApi.getPublicProfile(widget.username);
      if (mounted) {
        setState(() {
          _profile = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleFriendAction() async {
    if (_profile == null) return;
    final status = _profile!['friendship_status'] as String? ?? 'none';
    final targetId = _profile!['id'] as String;

    setState(() => _busy = true);
    try {
      if (status == 'friends') {
        final conv = await _productApi.post('/app/friends/$targetId/conversation');
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
      } else if (status == 'none') {
        await _socialApi.invite(widget.username);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Convite enviado para @${widget.username}!')),
          );
          _loadProfile();
        }
      } else if (status == 'pending_sent') {
        final invites = await _socialApi.invites();
        final match = invites.firstWhere(
          (inv) =>
              inv['direction'] == 'sent' &&
              ((inv['to_user_id'] == targetId) ||
                  (inv['username']?.toString().toLowerCase() == widget.username.toLowerCase())),
          orElse: () => <String, dynamic>{},
        );
        if (match['id'] != null) {
          await _socialApi.cancelInvite(match['id'] as String);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Convite cancelado.')),
            );
            _loadProfile();
          }
        }
      } else if (status == 'pending_received') {
        final invites = await _socialApi.invites();
        final match = invites.firstWhere(
          (inv) =>
              inv['direction'] == 'received' &&
              ((inv['from_user_id'] == targetId) ||
                  (inv['username']?.toString().toLowerCase() == widget.username.toLowerCase())),
          orElse: () => <String, dynamic>{},
        );
        if (match['id'] != null) {
          await _socialApi.acceptInvite(match['id'] as String);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Agora você e @${widget.username} são amigos!')),
            );
            _loadProfile();
          }
        }
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Não foi possível completar a ação: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareProfile() {
    final url = 'https://gatalogo.app/u/${widget.username}';
    SharePlus.instance.share(
      ShareParams(
        text: 'Veja o perfil de @${widget.username} no Gatálogo! Conheça suas descobertas felinas e conquistas: $url',
        subject: 'Perfil de @${widget.username} no Gatálogo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          '@${widget.username}',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textTitle,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartilhar perfil',
            icon: const Icon(LucideIcons.share2, size: 20, color: AppColors.textMedium),
            onPressed: _shareProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Perfil não encontrado',
                          style: GoogleFonts.fredoka(fontSize: 18, color: AppColors.textTitle),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMedium),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final p = _profile!;
    final username = p['username'] as String? ?? widget.username;
    final bio = p['bio'] as String? ?? '';
    final avatarUrl = p['avatar_url'] as String?;
    final level = p['level'] as int? ?? 1;
    final levelTitle = p['level_title'] as String? ?? 'Curioso';
    final xp = p['xp'] as int? ?? 0;
    final streak = p['streak'] as int? ?? 0;
    final catsCount = p['cats_count'] as int? ?? 0;
    final mutualCount = p['mutual_friends_count'] as int? ?? 0;
    final friendshipStatus = p['friendship_status'] as String? ?? 'none';
    final achievements = (p['achievements'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final publicCats = (p['public_cats'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    final isSelf = friendshipStatus == 'self';

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Cabeçalho de Perfil: Avatar + Nome + Bio
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight, width: 1.2),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySoftBg,
                      border: Border.all(color: AppColors.borderProfile, width: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null
                        ? Image.network(
                            avatarUrl.startsWith('http') ? avatarUrl : '${ApiConfig.baseUrl}$avatarUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              LucideIcons.user,
                              size: 44,
                              color: AppColors.primaryDark,
                            ),
                          )
                        : const Icon(
                            LucideIcons.user,
                            size: 44,
                            color: AppColors.primaryDark,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '@$username',
                  style: GoogleFonts.fredoka(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                if (mutualCount > 0 && !isSelf) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardAltBackground,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.users, size: 13, color: AppColors.textMedium),
                        const SizedBox(width: 5),
                        Text(
                          '$mutualCount amigo(s) em comum',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Botão de Ação Social Contextual
                if (!isSelf)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: friendshipStatus == 'friends'
                            ? AppColors.primary
                            : friendshipStatus == 'pending_sent'
                                ? AppColors.cardAltBackground
                                : friendshipStatus == 'pending_received'
                                    ? AppColors.greenLink
                                    : AppColors.primary,
                        foregroundColor: friendshipStatus == 'pending_sent'
                            ? AppColors.textDark
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          side: friendshipStatus == 'pending_sent'
                              ? const BorderSide(color: AppColors.border)
                              : BorderSide.none,
                        ),
                      ),
                      onPressed: _busy ? null : _handleFriendAction,
                      icon: Icon(
                        friendshipStatus == 'friends'
                            ? LucideIcons.messageCircle
                            : friendshipStatus == 'pending_sent'
                                ? LucideIcons.clock
                                : friendshipStatus == 'pending_received'
                                    ? LucideIcons.check
                                    : LucideIcons.userPlus,
                        size: 18,
                      ),
                      label: Text(
                        friendshipStatus == 'friends'
                            ? 'Conversar'
                            : friendshipStatus == 'pending_sent'
                                ? 'Convite Enviado (Cancelar)'
                                : friendshipStatus == 'pending_received'
                                    ? 'Aceitar Convite'
                                    : 'Adicionar Conexão',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Nível e Status de Gamificação
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoftBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$level',
                      style: GoogleFonts.fredoka(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nível $level — $levelTitle',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$xp Pontos de Experiência (XP)',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.achievementBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.flame, size: 14, color: AppColors.amberDark),
                      const SizedBox(width: 4),
                      Text(
                        '$streak dias',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.amberDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Grid de Estatísticas
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: LucideIcons.pawPrint,
                  iconColor: AppColors.primary,
                  title: 'Gatos',
                  value: '$catsCount',
                  subtitle: 'catalogados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: LucideIcons.trophy,
                  iconColor: AppColors.amberDark,
                  title: 'Troféus',
                  value: '${achievements.length}',
                  subtitle: 'desbloqueados',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Seção de Conquistas Desbloqueadas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conquistas (${achievements.length})',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (achievements.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Center(
                child: Text(
                  'Nenhuma conquista pública ainda.',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
                ),
              ),
            )
          else
            ...achievements.map((ach) {
              final title = ach['title']?.toString() ?? 'Conquista';
              final desc = ach['description']?.toString() ?? '';
              final xpReward = ach['xp_reward'] as int? ?? 50;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.achievementBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.amberBorder),
                        ),
                        child: const Icon(
                          LucideIcons.award,
                          size: 18,
                          color: AppColors.amberDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.fredoka(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTitle,
                              ),
                            ),
                            Text(
                              desc,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoftBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$xpReward XP',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 20),

          // 5. Galeria Pública de Gatos Catalogados
          if (publicCats.isNotEmpty) ...[
            Text(
              'Galeria Pública (${publicCats.length})',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: publicCats.length,
              itemBuilder: (context, index) {
                final cat = publicCats[index];
                final catName = cat['name']?.toString() ?? 'Gato';
                final coatType = cat['coat_type']?.toString() ?? 'curto';
                final primaryColor = cat['primary_color']?.toString() ?? 'indefinida';
                final photoUrl = cat['photo_url']?.toString();

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: photoUrl != null
                            ? Image.network(
                                photoUrl.startsWith('http') ? photoUrl : '${ApiConfig.baseUrl}$photoUrl',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppColors.cardAltBackground,
                                  child: const Center(
                                    child: Icon(LucideIcons.pawPrint, color: AppColors.textLight, size: 28),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.cardAltBackground,
                                child: const Center(
                                  child: Icon(LucideIcons.pawPrint, color: AppColors.textLight, size: 28),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              catName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fredoka(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTitle,
                              ),
                            ),
                            Text(
                              '$primaryColor • $coatType',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
          Text(
            '$title $subtitle',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
