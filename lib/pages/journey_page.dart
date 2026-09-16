import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/cat_sharing_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gatalogo_components.dart';
import '../widgets/gatalogo_gamification.dart';

List<Map<String, dynamic>> localJourney(CatStore store) {
  final days = store.discoveries
      .map((cat) => displayDate(cat.capturedAt))
      .toSet()
      .length;
  final angles = store.cats.fold<int>(
    0,
    (best, cat) => store.referencePhotosFor(cat.id).length > best
        ? store.referencePhotosFor(cat.id).length
        : best,
  );
  return [
    {
      'id': 'first',
      'title': 'Primeira Descoberta',
      'description': 'Fotografe e catalogue seu primeiro gato em um passeio ao ar livre.',
      'target': 1,
      'progress': store.discoveries.isEmpty ? 0 : 1,
      'icon': Icons.pets,
      'rarity': RarityLevel.common,
    },
    {
      'id': 'collector_5',
      'title': 'Olhar Curioso',
      'description': 'Aviste e catalogue 5 gatos diferentes pelo seu bairro.',
      'target': 5,
      'progress': store.discoveries.length.clamp(0, 5),
      'icon': LucideIcons.search,
      'rarity': RarityLevel.common,
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
      'id': 'days',
      'title': 'Guardião dos Dias',
      'description': 'Mantenha o olhar atento registrando avistamentos em 3 dias diferentes.',
      'target': 3,
      'progress': days.clamp(0, 3),
      'icon': LucideIcons.calendar,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'helper',
      'title': 'Rede de Cuidado',
      'description': 'Contribua com uma pista para ajudar a reencontrar um gato desaparecido.',
      'target': 1,
      'progress': 0,
      'icon': LucideIcons.heartHandshake,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'master_collector',
      'title': 'Mestre do Gatálogo',
      'description': 'Reúna 20 gatos catalogados na sua coleção botânica.',
      'target': 20,
      'progress': store.discoveries.length.clamp(0, 20),
      'icon': LucideIcons.crown,
      'rarity': RarityLevel.legendary,
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
      case 'angles':
        return LucideIcons.camera;
      case 'days':
        return LucideIcons.calendar;
      case 'helper':
        return LucideIcons.heartHandshake;
      case 'master_collector':
        return LucideIcons.crown;
      default:
        return LucideIcons.trophy;
    }
  }

  RarityLevel _rarityForIndex(int index) {
    if (index == 0 || index == 1) return RarityLevel.common;
    if (index == 2) return RarityLevel.uncommon;
    if (index == 3 || index == 4) return RarityLevel.rare;
    return RarityLevel.legendary;
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
                final items = rawItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = Map<String, dynamic>.from(entry.value);
                  item['icon'] ??= _iconForId(item['id']?.toString() ?? '');
                  item['rarity'] ??= _rarityForIndex(idx);
                  return item;
                }).toList();

                final total = items.length;
                final completedCount = items.where((it) {
                  final target = (it['target'] as num?)?.toInt() ?? 1;
                  final progress = (it['progress'] as num?)?.toInt() ?? 0;
                  return it['unlocked_at'] != null || progress >= target;
                }).length;

                final overallProgress = total > 0 ? (completedCount / total) : 0.0;

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
                                          'Explorador Felino',
                                          style: GoogleFonts.fredoka(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                        Text(
                                          '$completedCount de $total marcos alcançados',
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
                              const SizedBox(height: AppSpacing.lg),
                              GatalogoProgressBar(
                                value: overallProgress,
                                fillColor: AppColors.achievement,
                                height: 10,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Complete metas para celebrar sua conexão com a comunidade e apoiar a busca de felinos perdidos.',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
                          'Coleção de Troféus',
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
                                    onTap: () {
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
                                    },
                                  ),
                                  if (isUnlocked && widget.store.sessionStore.isSignedIn)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, right: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
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
