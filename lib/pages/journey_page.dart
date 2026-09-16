import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/cat_sharing_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_gamification.dart';

List<Map<String, dynamic>> localJourney(CatStore store) {
  final discoveries = store.discoveries;
  final days = discoveries
      .map((cat) => displayDate(cat.capturedAt))
      .toSet()
      .length;
  final angles = store.cats.fold<int>(
    0,
    (best, cat) => store.referencePhotosFor(cat.id).length > best
        ? store.referencePhotosFor(cat.id).length
        : best,
  );

  String catSearchText(Cat cat) {
    final analysis = store.analysisFor(cat.id);
    return '${cat.name ?? ''} ${cat.locationName ?? ''} ${analysis?.primaryColor ?? ''} ${analysis?.coatType ?? ''}'
        .toLowerCase();
  }

  final blackCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('preto') || t.contains('black') || t.contains('pantera');
  }).length;

  final orangeCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('laranja') || t.contains('ruivo') || t.contains('amarelo') || t.contains('orange');
  }).length;

  final calicoCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('calico') || t.contains('cálico') || t.contains('tricolor') || t.contains('casco');
  }).length;

  final siameseCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('siamês') || t.contains('siames') || t.contains('colorpoint');
  }).length;

  final bicolorCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('bicolor') || t.contains('frajola') || t.contains('preto e branco');
  }).length;

  final locations = discoveries
      .map((c) => c.locationName?.trim())
      .where((loc) => loc != null && loc.isNotEmpty)
      .toSet()
      .length;

  final nightCats = discoveries.where((c) {
    final h = c.capturedAt.hour;
    return h >= 19 || h < 5;
  }).length;

  final morningCats = discoveries.where((c) {
    final h = c.capturedAt.hour;
    return h >= 5 && h < 8;
  }).length;

  final detailedNotes = discoveries.where((c) => (c.name != null && c.name!.length >= 3) || (c.distinguishingMarks != null && c.distinguishingMarks!.isNotEmpty)).length;

  final streak = store.gamification.streak > store.gamification.longestStreak
      ? store.gamification.streak
      : store.gamification.longestStreak;

  final helperProgress = (store.gamification.dailyMissions.any((m) => m.id == 'daily_care' && m.completed) || discoveries.any((c) => c.collar != null || c.microchip != null)) ? 1 : 0;

  final bonusCompleted = store.gamification.bonusMission?.completed == true ? 1 : 0;
  final socialLikes = (store.gamification.xp ~/ 10).clamp(0, 5);
  final socialComments = (store.gamification.xp ~/ 15).clamp(0, 3);

  return [
    {
      'id': 'first',
      'title': 'Primeira Descoberta',
      'description': 'Fotografe e catalogue seu primeiro gato em um passeio ao ar livre.',
      'target': 1,
      'progress': discoveries.isEmpty ? 0 : 1,
      'icon': Icons.pets,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'collector_5',
      'title': 'Olhar Curioso',
      'description': 'Aviste e catalogue 5 gatos diferentes pelo seu bairro.',
      'target': 5,
      'progress': discoveries.length.clamp(0, 5),
      'icon': LucideIcons.search,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'collector_10',
      'title': 'Rastreador de Pegadas',
      'description': 'Catalogue 10 gatos diferentes em sua jornada de exploração.',
      'target': 10,
      'progress': discoveries.length.clamp(0, 10),
      'icon': LucideIcons.footprints,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'master_collector',
      'title': 'Mestre do Gatálogo',
      'description': 'Reúna 20 gatos catalogados na sua coleção botânica.',
      'target': 20,
      'progress': discoveries.length.clamp(0, 20),
      'icon': LucideIcons.crown,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'legend_collector',
      'title': 'Enciclopédia Felina',
      'description': 'Alcance a incrível marca de 50 gatos catalogados.',
      'target': 50,
      'progress': discoveries.length.clamp(0, 50),
      'icon': LucideIcons.sparkles,
      'rarity': RarityLevel.legendary,
    },
    {
      'id': 'black_cat',
      'title': 'Pantera Urbana',
      'description': 'Catalogue um gato com pelagem predominantemente preta.',
      'target': 1,
      'progress': blackCats.clamp(0, 1),
      'icon': LucideIcons.moon,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'orange_tabby',
      'title': 'Sol Alaranjado',
      'description': 'Catalogue um gato com pelagem ruiva ou laranja.',
      'target': 1,
      'progress': orangeCats.clamp(0, 1),
      'icon': LucideIcons.sun,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'calico',
      'title': 'Mosaico da Sorte',
      'description': 'Catalogue um gato com pelagem tricolor ou cálico.',
      'target': 1,
      'progress': calicoCats.clamp(0, 1),
      'icon': LucideIcons.palette,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'siamese_pattern',
      'title': 'Olhar Royal',
      'description': 'Catalogue um gato com padrão siamês ou colorpoint.',
      'target': 1,
      'progress': siameseCats.clamp(0, 1),
      'icon': LucideIcons.gem,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'bicolor',
      'title': 'Frajola Elegante',
      'description': 'Catalogue um gato bicolor ou frajola.',
      'target': 1,
      'progress': bicolorCats.clamp(0, 1),
      'icon': LucideIcons.sparkle,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'neighborhood_3',
      'title': 'Explorador de Quarteirões',
      'description': 'Registre gatos em pelo menos 3 locais ou bairros diferentes.',
      'target': 3,
      'progress': locations.clamp(0, 3),
      'icon': LucideIcons.mapPin,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'city_wanderer',
      'title': 'Andarilho Urbano',
      'description': 'Registre gatos em 5 locais diferentes pela cidade.',
      'target': 5,
      'progress': locations.clamp(0, 5),
      'icon': LucideIcons.navigation,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'night_owl',
      'title': 'Observador Noturno',
      'description': 'Catalogue um gato no período noturno (após às 19h).',
      'target': 1,
      'progress': nightCats.clamp(0, 1),
      'icon': LucideIcons.cloudMoon,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'early_bird',
      'title': 'Madrugador',
      'description': 'Catalogue um gato nas primeiras horas da manhã (antes das 08h).',
      'target': 1,
      'progress': morningCats.clamp(0, 1),
      'icon': LucideIcons.sunrise,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'days',
      'title': 'Olhar Atento',
      'description': 'Mantenha o olhar atento registrando avistamentos em 3 dias diferentes.',
      'target': 3,
      'progress': days.clamp(0, 3),
      'icon': LucideIcons.calendar,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'streak_3',
      'title': 'Ritmo Felino',
      'description': 'Mantenha uma sequência de 3 dias seguidos de atividade.',
      'target': 3,
      'progress': streak.clamp(0, 3),
      'icon': LucideIcons.flame,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'streak_7',
      'title': 'Semana Guardiã',
      'description': 'Mantenha uma sequência de 7 dias seguidos de atividade.',
      'target': 7,
      'progress': streak.clamp(0, 7),
      'icon': LucideIcons.shieldCheck,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'streak_30',
      'title': 'Devoção Felina',
      'description': 'Mantenha uma sequência lendária de 30 dias de atividade.',
      'target': 30,
      'progress': streak.clamp(0, 30),
      'icon': LucideIcons.award,
      'rarity': RarityLevel.legendary,
    },
    {
      'id': 'angles',
      'title': 'Fotógrafo Felino',
      'description': 'Adicione ângulos e fotos complementares ao perfil de um gato.',
      'target': 2,
      'progress': angles.clamp(0, 2),
      'icon': LucideIcons.camera,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'portrait',
      'title': 'Retrato Detalhado',
      'description': 'Adicione marcas e características detalhadas a 3 gatos.',
      'target': 3,
      'progress': detailedNotes.clamp(0, 3),
      'icon': LucideIcons.fileText,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'angles_master',
      'title': 'Galeria Completa',
      'description': 'Reúna 4 ou mais fotos no perfil de um mesmo gato.',
      'target': 4,
      'progress': angles.clamp(0, 4),
      'icon': LucideIcons.images,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'helper',
      'title': 'Rede de Cuidado',
      'description': 'Contribua com uma pista ou cuidado para ajudar felinos da região.',
      'target': 1,
      'progress': helperProgress.clamp(0, 1),
      'icon': LucideIcons.heartHandshake,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'guardian_shield',
      'title': 'Vigilante do Bairro',
      'description': 'Consulte alertas de busca ativa para proteger a comunidade.',
      'target': 1,
      'progress': helperProgress.clamp(0, 1),
      'icon': LucideIcons.shield,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'poster_share',
      'title': 'Voz da Esperança',
      'description': 'Compartilhe um cartaz de busca para mobilizar o resgate.',
      'target': 1,
      'progress': bonusCompleted.clamp(0, 1),
      'icon': LucideIcons.megaphone,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'social_heart',
      'title': 'Coração Comunitário',
      'description': 'Curta 5 publicações no feed da comunidade.',
      'target': 5,
      'progress': socialLikes.clamp(0, 5),
      'icon': LucideIcons.heart,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'commentator',
      'title': 'Conversa Afiada',
      'description': 'Participe com comentários em 3 publicações do feed.',
      'target': 3,
      'progress': socialComments.clamp(0, 3),
      'icon': LucideIcons.messageCircle,
      'rarity': RarityLevel.uncommon,
    },
    {
      'id': 'first_share',
      'title': 'Espalhando Carinho',
      'description': 'Compartilhe uma descoberta felina com seus amigos.',
      'target': 1,
      'progress': bonusCompleted.clamp(0, 1),
      'icon': LucideIcons.share2,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'owned_pet',
      'title': 'Meu Companheiro',
      'description': 'Cadastre um gato sob seus cuidados como pet próprio.',
      'target': 1,
      'progress': store.pets.length.clamp(0, 1),
      'icon': LucideIcons.home,
      'rarity': RarityLevel.common,
    },
  ];
}

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key, required this.store});
  final CatStore store;
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  List<Map<String, dynamic>>? _remote;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.store.sessionStore.isSignedIn) return;
    try {
      await widget.store.syncCatalog();
      final data = await ProductApiService(widget.store.sessionStore)
          .list('/app/journey');
      await widget.store.refreshGamification();
      if (mounted) setState(() => _remote = data);
    } catch (_) {
      /* Local collection progress remains available offline. */
    }
  }

  IconData _iconForId(String id) {
    switch (id) {
      case 'first':
        return Icons.pets;
      case 'collector_5':
        return LucideIcons.search;
      case 'collector_10':
        return LucideIcons.footprints;
      case 'master_collector':
        return LucideIcons.crown;
      case 'legend_collector':
        return LucideIcons.sparkles;
      case 'black_cat':
        return LucideIcons.moon;
      case 'orange_tabby':
        return LucideIcons.sun;
      case 'calico':
        return LucideIcons.palette;
      case 'siamese_pattern':
        return LucideIcons.gem;
      case 'bicolor':
        return LucideIcons.sparkle;
      case 'neighborhood_3':
        return LucideIcons.mapPin;
      case 'city_wanderer':
        return LucideIcons.navigation;
      case 'night_owl':
        return LucideIcons.cloudMoon;
      case 'early_bird':
        return LucideIcons.sunrise;
      case 'days':
        return LucideIcons.calendar;
      case 'streak_3':
        return LucideIcons.flame;
      case 'streak_7':
        return LucideIcons.shieldCheck;
      case 'streak_30':
        return LucideIcons.award;
      case 'angles':
        return LucideIcons.camera;
      case 'portrait':
        return LucideIcons.fileText;
      case 'angles_master':
        return LucideIcons.images;
      case 'helper':
        return LucideIcons.heartHandshake;
      case 'guardian_shield':
        return LucideIcons.shield;
      case 'poster_share':
        return LucideIcons.megaphone;
      case 'social_heart':
        return LucideIcons.heart;
      case 'commentator':
        return LucideIcons.messageCircle;
      case 'first_share':
        return LucideIcons.share2;
      case 'owned_pet':
        return LucideIcons.home;
      default:
        return LucideIcons.trophy;
    }
  }

  RarityLevel _rarityForId(String id) {
    switch (id) {
      case 'legend_collector':
      case 'streak_30':
        return RarityLevel.legendary;
      case 'master_collector':
      case 'city_wanderer':
      case 'streak_7':
      case 'angles_master':
      case 'helper':
        return RarityLevel.rare;
      case 'collector_10':
      case 'calico':
      case 'siamese_pattern':
      case 'neighborhood_3':
      case 'night_owl':
      case 'early_bird':
      case 'streak_3':
      case 'angles':
      case 'portrait':
      case 'poster_share':
      case 'commentator':
        return RarityLevel.uncommon;
      default:
        return RarityLevel.common;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Folhagens decorativas botânicas
            Positioned(
              top: -15,
              left: -20,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: 0.35,
                  child: Image.asset(
                    'assets/images/Folha_2.png',
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: -10,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/Folha_6.png',
                  width: 110,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Conteúdo
            AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) {
                final rawItems = _remote ?? localJourney(widget.store);
                final items = rawItems.map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id']?.toString() ?? '';
                  item['icon'] ??= _iconForId(id);
                  item['rarity'] ??= _rarityForId(id);
                  return item;
                }).toList();

                final total = items.length;
                final completedCount = items.where((it) {
                  final target = (it['target'] as num?)?.toInt() ?? 1;
                  final progress = (it['progress'] as num?)?.toInt() ?? 0;
                  return it['unlocked_at'] != null || progress >= target;
                }).length;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Cabeçalho
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textDark),
                              tooltip: 'Voltar',
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Conquistas & Jornada',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.fredoka(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Card Hero de Resumo / Nível
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.achievementBg, AppColors.cardBackground],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.achievement.withValues(alpha: 0.5), width: 1.4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.achievement.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.trophy,
                                      size: 26,
                                      color: AppColors.achievementText,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nível ${widget.store.gamification.level} — ${widget.store.gamification.levelTitle}',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                        Text(
                                          '$completedCount de $total marcos alcançados · ${widget.store.gamification.xp} XP',
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.achievementText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 6,
                                spacing: 8,
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
                                          '${widget.store.gamification.streak}d',
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFE65100),
                                          ),
                                        ),
                                        if (widget.store.gamification.multiplier > 1.0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '${widget.store.gamification.multiplier.toStringAsFixed(1)}x',
                                            style: GoogleFonts.nunito(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFE65100),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
                                          '${widget.store.gamification.freezeShields} escudo${widget.store.gamification.freezeShields == 1 ? '' : 's'}',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF00796B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              GatalogoXPBar(
                                currentLevel: widget.store.gamification.level,
                                currentXP: widget.store.gamification.currentLevelXp,
                                targetXP: widget.store.gamification.currentLevelTargetXp,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Recompensa do nível: ${widget.store.gamification.levelReward}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Título de Seção
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                        child: Text(
                          'Coleção de Troféus ($completedCount/$total)',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ),

                    // Lista de Conquistas
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxxl),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = items[index];
                            final target = (item['target'] as num?)?.toInt() ?? 1;
                            final progress = (item['progress'] as num?)?.toInt() ?? 0;
                            final isUnlocked = item['unlocked_at'] != null || progress >= target;

                            final state = isUnlocked
                                ? AchievementState.completed
                                : (progress > 0 ? AchievementState.inProgress : AchievementState.locked);

                            final rarity = (item['rarity'] as RarityLevel?) ?? RarityLevel.common;
                            final icon = (item['icon'] as IconData?) ?? LucideIcons.trophy;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Column(
                                children: [
                                  GatalogoAchievementCard(
                                    title: item['title']?.toString() ?? '',
                                    description: item['description']?.toString() ?? '',
                                    icon: icon,
                                    progress: (progress / target).clamp(0.0, 1.0),
                                    currentCount: progress,
                                    targetCount: target,
                                    state: state,
                                    themeColor: rarity.color,
                                    unlockedAt: item['unlocked_at']?.toString(),
                                    onTap: () {
                                      if (isUnlocked) {
                                        showAchievementCelebrationDialog(
                                          context,
                                          title: item['title']?.toString() ?? '',
                                          description: item['description']?.toString() ?? '',
                                          icon: icon,
                                          rarity: rarity,
                                          onShare: () {
                                            CatSharingService.shareAchievement(
                                              title: item['title']?.toString() ?? '',
                                              description: item['description']?.toString(),
                                              rarity: rarity.label,
                                            );
                                            widget.store.recordGamificationAction('share');
                                          },
                                        );
                                      } else {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppColors.background,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.dialog),
                                            ),
                                            title: Row(
                                              children: [
                                                Icon(icon, color: rarity.color),
                                                const SizedBox(width: AppSpacing.sm),
                                                Expanded(
                                                  child: Text(
                                                    item['title']?.toString() ?? '',
                                                    style: GoogleFonts.fredoka(
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textTitle,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['description']?.toString() ?? '',
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 14,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: AppSpacing.md),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: rarity.backgroundColor,
                                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                                  ),
                                                  child: Text(
                                                    'Raridade: ${rarity.label} · Progresso: $progress/$target',
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: rarity.color,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: Text(
                                                  'Fechar',
                                                  style: GoogleFonts.nunito(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  if (isUnlocked && widget.store.sessionStore.isSignedIn)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, right: 8),
                                      child: Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              final title = item['title']?.toString() ?? 'Nova Conquista';
                                              final description = item['description']?.toString();
                                              final rarity = item['rarity']?.toString();
                                              CatSharingService.shareAchievement(
                                                title: title,
                                                description: description,
                                                rarity: rarity,
                                              );
                                              widget.store.recordGamificationAction('share');
                                            },
                                            icon: const Icon(LucideIcons.share, size: 14, color: AppColors.primary),
                                            label: Text(
                                              'Redes',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          TextButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    setState(() => _busy = true);
                                                    try {
                                                      await ProductApiService(
                                                        widget.store.sessionStore,
                                                      ).post('/app/journey/${item['id']}/share');
                                                      if (context.mounted) {
                                                        showMessage(
                                                          context,
                                                          'Conquista compartilhada com seus amigos.',
                                                        );
                                                      }
                                                    } catch (error) {
                                                      if (context.mounted) {
                                                        showMessage(context, error);
                                                      }
                                                    } finally {
                                                      if (mounted) setState(() => _busy = false);
                                                    }
                                                  },
                                            icon: const Icon(LucideIcons.share2, size: 14, color: AppColors.greenLink),
                                            label: Text(
                                              'No feed',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.greenLink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
