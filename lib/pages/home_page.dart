import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/active_search_proximity_card.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_gamification.dart';
import '../widgets/inbox_button.dart';
import 'cat_details_page.dart';
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

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([catStore, sessionStore]),
          builder: (context, _) {
            final discoveries = catStore.discoveries;
            final catCount = discoveries.length;
            final nextMilestone = catCount < 10
                ? 10
                : ((catCount ~/ 10) + 1) * 10;
            final progress = (catCount / nextMilestone).clamp(0.0, 1.0);
            final greeting = _getTimeBasedGreeting();
            final name =
                sessionStore.session?.email.split('@').first ?? 'Explorador';

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await catStore.syncCatalog(manual: true);
                await catStore.refreshNotifications();
                await catStore.refreshGamification();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                      const SizedBox(width: 10),
                      UserAvatarButton(
                        sessionStore: sessionStore,
                        catStore: catStore,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Saudação Personalizada
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, $name!',
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

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ShortcutCard(
                        backgroundColor: AppColors.shortcutGreenBg,
                        iconColor: AppColors.shortcutGreenIcon,
                        icon: Icons.pets,
                        title: 'Meus Gatos',
                        subtitle: 'Quem mora com você e registros especiais.',
                        onTap: () =>
                            _open(context, MyCatsPage(store: catStore)),
                      ),
                      const SizedBox(height: 12),
                      _ShortcutCard(
                        backgroundColor: AppColors.shortcutPinkBg,
                        iconColor: AppColors.shortcutPinkIcon,
                        icon: LucideIcons.mapPin,
                        title: 'Avistamentos',
                        subtitle: 'Veja onde você e outros encontraram gatos.',
                        onTap: () => _open(
                          context,
                          LocationPage(catStore: catStore, readOnly: true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Card de Proximidade / Geofencing da Busca Ativa (Etapa 3.4)
                  ActiveSearchProximityCard(
                    sessionStore: sessionStore,
                    catStore: catStore,
                  ),

                  const SizedBox(height: 14),

                  // Card de Gamificação: Nível, XP, Streak & Escudo (Etapa 6.1 e 6.2)
                  GatalogoGamificationCard(
                    gamification: catStore.gamification,
                    onTapJourney: () =>
                        _open(context, JourneyPage(store: catStore)),
                  ),

                  const SizedBox(height: 14),

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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$catCount',
                                            style: GoogleFonts.nunito(
                                              fontSize: 44,
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
                                        constraints: const BoxConstraints(
                                          maxWidth: 165,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              height: 11,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.sm,
                                                    ),
                                                border: Border.all(
                                                  color: AppColors.textMedium,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                        Color
                                                      >(
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
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
                            analysis: catStore.analysisFor(cat.id),
                            onTap: () => _open(
                              context,
                              CatDetailsPage(cat: cat, catStore: catStore),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecentCatCard extends StatelessWidget {
  const _RecentCatCard({required this.cat, this.analysis, required this.onTap});

  final Cat cat;
  final CatAnalysis? analysis;
  final VoidCallback onTap;

  RarityLevel _determineRarity() {
    if (analysis == null) return RarityLevel.common;
    if (analysis!.colors.length >= 3) return RarityLevel.legendary;
    final coat = (analysis!.coatType ?? '').toLowerCase();
    if (coat.contains('carey') ||
        coat.contains('calico') ||
        coat.contains('quimera')) {
      return RarityLevel.legendary;
    }
    if (analysis!.colors.length == 2 ||
        coat.contains('bicolor') ||
        coat.contains('point')) {
      return RarityLevel.rare;
    }
    if (coat.contains('tabby') || coat.contains('tigrado')) {
      return RarityLevel.uncommon;
    }
    return RarityLevel.common;
  }

  @override
  Widget build(BuildContext context) {
    final rarity = _determineRarity();
    final isSpecial = rarity != RarityLevel.common;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSpecial ? rarity.color : AppColors.borderLight,
            width: isSpecial ? 2.0 : 1.2,
          ),
          boxShadow: isSpecial
              ? [
                  BoxShadow(
                    color: rarity.color.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: CatPhotoView(cat.photoPath, fit: BoxFit.cover),
                  ),
                ),
                if (isSpecial)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: rarity.backgroundColor.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: rarity.color, width: 0.8),
                      ),
                      child: Text(
                        rarity.label,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: rarity.color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
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
                  Icon(
                    LucideIcons.pawPrint,
                    size: 15,
                    color: isSpecial ? rarity.color : AppColors.primary,
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
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                        fontSize: 17,
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
                        fontSize: 13,
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
