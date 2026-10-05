import '../widgets/illustrated_home_components.dart';
import '../widgets/botanical_scene.dart';
import '../widgets/game_components.dart';
import '../widgets/milestone_widgets.dart';
import '../widgets/app_header_actions.dart';

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
    this.viewAsFriend = false,
  });

  final String username;
  final bool viewAsFriend;
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
      final data = widget.viewAsFriend
          ? await _productApi.get(
              '/social/profiles/${Uri.encodeComponent(widget.username)}?view_as_friend=true',
            )
          : await _socialApi.getPublicProfile(widget.username);
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
        final conv = await _productApi.post(
          '/app/friends/$targetId/conversation',
        );
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
            SnackBar(
              content: Text('Convite enviado para @${widget.username}!'),
            ),
          );
          _loadProfile();
        }
      } else if (status == 'pending_sent') {
        final invites = await _socialApi.invites();
        final match = invites.firstWhere(
          (inv) =>
              inv['direction'] == 'sent' &&
              ((inv['to_user_id'] == targetId) ||
                  (inv['username']?.toString().toLowerCase() ==
                      widget.username.toLowerCase())),
          orElse: () => <String, dynamic>{},
        );
        if (match['id'] != null) {
          await _socialApi.cancelInvite(match['id'] as String);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Convite cancelado.')));
            _loadProfile();
          }
        }
      } else if (status == 'pending_received') {
        final invites = await _socialApi.invites();
        final match = invites.firstWhere(
          (inv) =>
              inv['direction'] == 'received' &&
              ((inv['from_user_id'] == targetId) ||
                  (inv['username']?.toString().toLowerCase() ==
                      widget.username.toLowerCase())),
          orElse: () => <String, dynamic>{},
        );
        if (match['id'] != null) {
          await _socialApi.acceptInvite(match['id'] as String);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Agora você e @${widget.username} são amigos!'),
              ),
            );
            _loadProfile();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Não foi possível completar a ação: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareProfile() {
    final url = 'https://gatalogo.app/u/${widget.username}';
    SharePlus.instance.share(
      ShareParams(
        text:
            'Veja o perfil de @${widget.username} no Gatálogo! Conheça suas descobertas felinas e conquistas: $url',
        subject: 'Perfil de @${widget.username} no Gatálogo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BotanicalScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          const AppHeaderActions(),
          IconButton(
            tooltip: 'Compartilhar perfil',
            icon: const Icon(
              LucideIcons.share2,
              size: 20,
              color: AppColors.textMedium,
            ),
            onPressed: _shareProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Perfil não encontrado',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
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
    final achievements =
        (p['achievements'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final publicCats =
        (p['public_cats'] as List?)
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
          if (widget.viewAsFriend)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Prévia: como seus amigos veem seu perfil'),
            ),
          if (p['habitat_preview'] is Map)
            Card(
              child: ListTile(
                leading: const Icon(Icons.yard_outlined),
                title: const Text('Quintal'),
                subtitle: Text(
                  '${p['habitat_preview']['cats_count']} gato(s) no quintal · expansão ${p['habitat_preview']['expansion_level']}',
                ),
              ),
            ),
          // 1. Cabeçalho de Perfil: Avatar + Nome + Bio
          Column(
            children: [
              IllustratedProfileIdentity(
                portrait: FramedUserAvatar(url: avatarUrl, size: 116),
                name: Text(
                  '@$username',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (mutualCount > 0 && !isSelf) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardAltBackground,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.users,
                        size: 13,
                        color: AppColors.textMedium,
                      ),
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
              const SizedBox(height: 16),
              // Botão de Ação Social Contextual
              if (!isSelf)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    minHeight: 50,
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
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

          const SizedBox(height: 16),

          // 2. Nível e Status de Gamificação
          GameNotebook(
            child: Row(
              children: [
                GameSeal(size: 60, label: '$level'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        levelTitle,
                        style: GoogleFonts.fredoka(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nível $level · $xp XP',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.achievementBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        size: 14,
                        color: AppColors.amberDark,
                      ),
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

          if (bio.isNotEmpty) ...[
            GameNote(
              child: Row(
                children: [
                  GatalogoArt.image('ui/ui_note_pinned', width: 40, height: 44),
                  const SizedBox(width: 12),
                  Expanded(child: Text(bio)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 3. Grid de Estatísticas
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  art: 'ui/ui_cat_photos_stack',
                  title: 'Gatos',
                  value: '$catsCount',
                  subtitle: 'catalogados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  art: 'rewards/reward_medal_paw_gold',
                  title: 'Conquistas',
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
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
            )
          else
            ...achievements.map((ach) {
              final title = ach['title']?.toString() ?? 'Conquista';
              final desc = ach['description']?.toString() ?? '';
              final xpReward =
                  (ach['xp_received'] as num? ?? ach['xp_reward'] as num? ?? 0)
                      .toInt();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => showAchievement(context, ach),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        AchievementMedal(
                          goal: ach,
                          size: 48,
                          onTap: () => showAchievement(context, ach),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoftBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ach['legacy_reward_unknown'] == true ||
                                    xpReward == 0
                                ? 'Obtida'
                                : '+$xpReward XP',
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
                final primaryColor =
                    cat['primary_color']?.toString() ?? 'indefinida';
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
                                photoUrl.startsWith('http')
                                    ? photoUrl
                                    : '${ApiConfig.baseUrl}$photoUrl',
                                headers: {
                                  'Authorization':
                                      'Bearer ${widget.sessionStore.session?.accessToken ?? ''}',
                                },
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.cardAltBackground,
                                      child: const Center(
                                        child: Icon(
                                          LucideIcons.pawPrint,
                                          color: AppColors.textLight,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                              )
                            : Container(
                                color: AppColors.cardAltBackground,
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.pawPrint,
                                    color: AppColors.textLight,
                                    size: 28,
                                  ),
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
    required String art,
    required String title,
    required String value,
    required String subtitle,
  }) => IllustratedStatTile(value: value, label: '$title $subtitle', art: art);
}
