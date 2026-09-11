import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'account_page.dart';
import 'cat_details_page.dart';
import 'journey_page.dart';
import 'location_page.dart';
import 'my_cats_page.dart';
import 'social_page.dart';

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

            return Stack(
              children: [
                // Forma orgânica curva rosada no topo esquerdo conforme Figma Tela 2
                Positioned(
                  top: -45,
                  left: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 250,
                      height: 180,
                      decoration: const BoxDecoration(
                        color: Color(0x3DF4D2DC),
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(170),
                        ),
                      ),
                    ),
                  ),
                ),
                ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                // Header: Logo e Botão de Conta (sem InboxButton conforme Figma)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/Logo.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _open(
                        context,
                        AccountPage(
                          sessionStore: sessionStore,
                          catStore: catStore,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE8D6DE),
                            width: 1.4,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.user,
                          size: 20,
                          color: Color(0xFF948C87),
                        ),
                      ),
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
                        fontWeight: FontWeight.w900,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Card Destaque: Sua Coleção (conforme Figma Tela 2)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF1EF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Raminho de folhas decorativas saindo do lado direito superior
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/images/Folha_2.png',
                            width: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Raminho verde saindo de baixo
                      Positioned(
                        right: 120,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/images/Folha_5.png',
                            width: 65,
                            fit: BoxFit.contain,
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
                                fontWeight: FontWeight.w900,
                                color: AppColors.textTitle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Número grande e rótulo
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$catCount',
                                      style: GoogleFonts.nunito(
                                        fontSize: 68,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFBA5372),
                                        height: 0.95,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Gatos catalogados',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFBA5372),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Gatinho dormindo
                                Image.asset(
                                  'assets/images/gato_2.png',
                                  height: 84,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Barra de progresso com borda e preenchimento verde conforme Figma Tela 2
                            Row(
                              children: [
                                const Spacer(),
                                SizedBox(
                                  width: 165,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFF5C504A),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.transparent,
                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF638354),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Próxima conquista: $nextMilestone gatos.',
                                        style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF5C504A),
                                        ),
                                      ),
                                    ],
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
                      color: const Color(0xFFFAF7F2),
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
                          onPressed: () => onNavigate(1),
                          icon: const Icon(LucideIcons.camera, size: 18),
                          label: const Text('Gatalogar primeiro gato'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 175,
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
                          Scaffold(
                            appBar: AppBar(
                              title: Text(
                                'Amigos',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              backgroundColor: AppColors.background,
                              elevation: 0,
                            ),
                            body: SocialPage(sessionStore: sessionStore),
                          ),
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
            ),
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
            color: const Color(0xFFF7E2E6),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto com cantos arredondados
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 98,
                width: double.infinity,
                child: CatPhotoView(cat.photoPath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 6),
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
                    LucideIcons.pawPrint,
                    size: 16,
                    color: Color(0xFFD4728C),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(width: 10),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: iconColor.withValues(alpha: 0.8),
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
