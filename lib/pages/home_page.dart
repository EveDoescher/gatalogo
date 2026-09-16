import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/active_search_proximity_card.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_gamification.dart';
import '../widgets/inbox_button.dart';
import '../widgets/chat_icon_button.dart';
import 'cat_details_page.dart';
import 'friends_page.dart';
import 'journey_page.dart';
import 'location_page.dart';
import 'my_cats_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.sessionStore,
    required this.catStore,
    required this.onNavigate,
  });

  final SessionStore sessionStore;
  final CatStore catStore;
  final ValueChanged<int> onNavigate;

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: catStore,
          builder: (context, _) {
            final discoveries = catStore.discoveries;
            final catCount = discoveries.length;
            final nextMilestone = catCount < 10
                ? 10
                : ((catCount ~/ 10) + 1) * 10;
            final progress = (catCount / nextMilestone).clamp(0.0, 1.0);

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Header: Logo, Notificações e Botão de Perfil
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/Logo.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    InboxButton(store: catStore, size: 42),
                    const SizedBox(width: 8),
                    ChatIconButton(sessionStore: sessionStore, size: 42),
                    const SizedBox(width: 8),
                    UserAvatarButton(
                      sessionStore: sessionStore,
                      catStore: catStore,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Saudação
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bem-vindo de volta!',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bora explorar?',
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Card de Proximidade / Geofencing da Busca Ativa (Etapa 3.4)
                ActiveSearchProximityCard(
                  sessionStore: sessionStore,
                  catStore: catStore,
                ),

                const SizedBox(height: 14),

                // Card de Gamificação: Nível, XP, Streak & Escudo (Etapa 6.1 e 6.2)
                _HomeGamificationBanner(
                  catStore: catStore,
                  onTap: () => _open(
                    context,
                    JourneyPage(store: catStore),
                  ),
                ),

                const SizedBox(height: 18),

                // Card Destaque: Sua Coleção (conforme Figma Tela 2)
                GestureDetector(
                  onTap: () => onNavigate(3),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoftBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Raminho de folhas decorativas saindo do lado direito superior apontando para dentro
                        Positioned(
                          right: -10,
                          top: -6,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: 2.70,
                              child: Image.asset(
                                'assets/images/Folha_2.png',
                                width: 138,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        // Raminho verde saindo da base entre o texto e o gato
                        Positioned(
                          left: 122,
                          bottom: -12,
                          child: IgnorePointer(
                            child: Transform.flip(
                              flipX: true,
                              child: Transform.rotate(
                                angle: -0.05,
                                child: Image.asset(
                                  'assets/images/Folha_1.png',
                                  width: 90,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Conteúdo interno do Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sua Coleção',
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textTitle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Número grande e rótulo
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$catCount',
                                        style: GoogleFonts.nunito(
                                          fontSize: 68,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                          height: 0.95,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Gatos catalogados',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Gatinho dormindo
                                Image.asset(
                                  'assets/images/gato_2.png',
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Barra de progresso com borda e preenchimento verde conforme Figma Tela 2
                            Row(
                              children: [
                                const Spacer(),
                                Flexible(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 165),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 11,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(AppRadius.sm),
                                            border: Border.all(
                                              color: AppColors.textMedium,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.transparent,
                                              valueColor: const AlwaysStoppedAnimation<Color>(
                                                AppColors.greenProgress,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Próxima conquista: $nextMilestone gatos.',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunito(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                const SizedBox(height: 20),

                // Missões Diárias (Etapa 6.3)
                _HomeDailyMissionsCard(
                  catStore: catStore,
                ),

                const SizedBox(height: 24),

                // Seção: Descobertas Recentes (sem "Ver tudo" conforme Figma Tela 2)
                Text(
                  'Descobertas Recentes',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                // Lista Horizontal de Descobertas
                if (discoveries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Nenhum gato catalogado ainda.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => onNavigate(2),
                          icon: const Icon(LucideIcons.camera, size: 18),
                          label: const Text('Gatalogar primeiro gato'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 152,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: discoveries.take(6).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final cat = discoveries[index];
                        return _RecentCatCard(
                          cat: cat,
                          onTap: () => _open(
                            context,
                            CatDetailsPage(cat: cat, catStore: catStore),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 20),

                // Card de Destaque Social & Conquistas (incentivo à comunidade e progresso)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.achievementBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.achievement.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.trophy,
                          size: 24,
                          color: AppColors.achievementDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comunidade & Conquistas',
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.achievementText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Veja os gatos que seus amigos encontraram e seus marcos!',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => onNavigate(1),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.achievementDark.withValues(alpha: 0.15),
                          foregroundColor: AppColors.achievementText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          'Explorar',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Seção: Atalhos
                Text(
                  'Atalhos',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                // Grid 2x2 de Atalhos
                Row(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        backgroundColor: AppColors.shortcutGreenBg,
                        iconColor: AppColors.shortcutGreenIcon,
                        icon: Icons.pets,
                        title: 'Meus Gatos',
                        subtitle: 'Quem mora com você.',
                        onTap: () =>
                            _open(context, MyCatsPage(store: catStore)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ShortcutCard(
                        backgroundColor: AppColors.shortcutBlueBg,
                        iconColor: AppColors.shortcutBlueIcon,
                        icon: LucideIcons.users,
                        title: 'Amigos',
                        subtitle: 'Conversas e conquistas compartilhadas.',
                        onTap: () => _open(
                          context,
                          FriendsPage(sessionStore: sessionStore),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        backgroundColor: AppColors.shortcutYellowBg,
                        iconColor: AppColors.shortcutYellowIcon,
                        icon: LucideIcons.trophy,
                        title: 'Conquistas',
                        subtitle: 'Veja seus marcos e progresso.',
                        onTap: () =>
                            _open(context, JourneyPage(store: catStore)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ShortcutCard(
                        backgroundColor: AppColors.shortcutPinkBg,
                        iconColor: AppColors.shortcutPinkIcon,
                        icon: LucideIcons.mapPin,
                        title: 'Avistamentos',
                        subtitle: 'Veja onde você encontrou gatos.',
                        onTap: () => _open(
                          context,
                          LocationPage(
                            catStore: catStore,
                            readOnly: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecentCatCard extends StatelessWidget {
  const _RecentCatCard({required this.cat, required this.onTap});

  final Cat cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.borderLight,
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto com cantos arredondados
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: CatPhotoView(cat.photoPath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 4),
            // Rodapé com Nome e Patinha vazada rosa
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.pets,
                    size: 16,
                    color: AppColors.primary,
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

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w600,
                        color: iconColor.withValues(alpha: 0.85),
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGamificationBanner extends StatelessWidget {
  const _HomeGamificationBanner({
    required this.catStore,
    required this.onTap,
  });

  final CatStore catStore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gamification = catStore.gamification;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoftBg,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          gamification.levelTitle,
                          style: GoogleFonts.fredoka(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.flame, size: 14, color: Color(0xFFE65100)),
                            const SizedBox(width: 4),
                            Text(
                              '${gamification.streak}d',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE65100),
                              ),
                            ),
                            if (gamification.multiplier > 1.0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE65100),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${gamification.multiplier.toStringAsFixed(1)}x',
                                  style: GoogleFonts.nunito(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: const Color(0xFF4DB6AC).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF00796B)),
                            const SizedBox(width: 4),
                            Text(
                              '${gamification.freezeShields}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00796B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GatalogoXPBar(
                currentLevel: gamification.level,
                currentXP: gamification.xp,
                targetXP: gamification.targetXp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDailyMissionsCard extends StatelessWidget {
  const _HomeDailyMissionsCard({
    required this.catStore,
  });

  final CatStore catStore;

  @override
  Widget build(BuildContext context) {
    final missions = catStore.gamification.dailyMissions;
    final completedCount = missions.where((m) => m.completed).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            spacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoftBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.target, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Missões de Hoje',
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: completedCount == missions.length && missions.isNotEmpty
                      ? AppColors.greenLight
                      : AppColors.cardAltBackground,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: completedCount == missions.length && missions.isNotEmpty
                        ? AppColors.green.withValues(alpha: 0.3)
                        : AppColors.borderLight,
                  ),
                ),
                child: Text(
                  '$completedCount / ${missions.length}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: completedCount == missions.length && missions.isNotEmpty
                        ? AppColors.greenLink
                        : AppColors.textMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...missions.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: m.completed
                      ? AppColors.greenLight.withValues(alpha: 0.4)
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: m.completed
                        ? AppColors.greenProgress.withValues(alpha: 0.3)
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      m.completed ? LucideIcons.checkCircle2 : LucideIcons.circle,
                      size: 18,
                      color: m.completed ? AppColors.greenProgress : AppColors.textLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: m.completed ? AppColors.textMedium : AppColors.textDark,
                              decoration: m.completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (!m.completed && m.target > 1) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${m.progress} de ${m.target}',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: m.completed
                            ? AppColors.greenProgress.withValues(alpha: 0.15)
                            : AppColors.achievementBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.sparkles,
                            size: 11,
                            color: m.completed ? AppColors.greenProgress : AppColors.achievementDark,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '+${m.xpReward} XP',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: m.completed ? AppColors.greenProgress : AppColors.achievementDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
