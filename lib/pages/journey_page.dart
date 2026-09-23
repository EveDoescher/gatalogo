import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../services/cat_sharing_service.dart';
import '../services/product_api_service.dart';
import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/app_header_actions.dart';
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
    return t.contains('laranja') ||
        t.contains('ruivo') ||
        t.contains('amarelo') ||
        t.contains('orange');
  }).length;

  final calicoCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('calico') ||
        t.contains('cálico') ||
        t.contains('tricolor') ||
        t.contains('casco');
  }).length;

  final siameseCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('siamês') ||
        t.contains('siames') ||
        t.contains('colorpoint');
  }).length;

  final bicolorCats = discoveries.where((c) {
    final t = catSearchText(c);
    return t.contains('bicolor') ||
        t.contains('frajola') ||
        t.contains('preto e branco');
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

  final detailedNotes = discoveries
      .where(
        (c) =>
            (c.name != null && c.name!.length >= 3) ||
            (c.distinguishingMarks != null &&
                c.distinguishingMarks!.isNotEmpty),
      )
      .length;

  final streak = store.gamification.streak > store.gamification.longestStreak
      ? store.gamification.streak
      : store.gamification.longestStreak;

  final helperProgress =
      (store.gamification.dailyMissions.any(
            (m) => m.id == 'daily_care' && m.completed,
          ) ||
          discoveries.any((c) => c.collar != null || c.microchip != null))
      ? 1
      : 0;

  final bonusCompleted = store.gamification.bonusMission?.completed == true
      ? 1
      : 0;
  const socialLikes = 0;
  const socialComments = 0;

  return [
    {
      'id': 'first',
      'title': 'Primeira Descoberta',
      'description':
          'Fotografe e catalogue seu primeiro gato em um passeio ao ar livre.',
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
      'description':
          'Catalogue 10 gatos diferentes em sua jornada de exploração.',
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
      'description':
          'Registre gatos em pelo menos 3 locais ou bairros diferentes.',
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
      'description':
          'Catalogue um gato nas primeiras horas da manhã (antes das 08h).',
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
      'description':
          'Adicione ângulos e fotos complementares ao perfil de um gato.',
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
      'description':
          'Contribua com uma pista ou cuidado para ajudar felinos da região.',
      'target': 1,
      'progress': helperProgress.clamp(0, 1),
      'icon': LucideIcons.heartHandshake,
      'rarity': RarityLevel.rare,
    },
    {
      'id': 'guardian_shield',
      'title': 'Vigilante do Bairro',
      'description':
          'Consulte alertas de busca ativa para proteger a comunidade.',
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
  String _filter = 'Todas';

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

  bool _unlocked(Map<String, dynamic> item) =>
      item['unlocked_at'] != null ||
      ((item['progress'] as num?) ?? 0) >= ((item['target'] as num?) ?? 1);

  Future<void> _share(Map<String, dynamic> item, bool community) async {
    setState(() => _busy = true);
    try {
      if (community) {
        await ProductApiService(widget.store.sessionStore)
            .post('/app/journey/${item['id']}/share');
      } else {
        await CatSharingService.shareAchievement(
          title: item['title'].toString(),
          description: item['description']?.toString(),
        );
      }
      if (mounted && community) {
        showMessage(context, 'Conquista compartilhada na comunidade.');
      }
    } catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Conquistas'),
      actions: [AppHeaderActions(store: widget.store)],
    ),
    body: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final items = _remote ?? localJourney(widget.store);
        final unlocked = items.where(_unlocked).length;
        final visible = items
            .where(
              (item) =>
                  _filter == 'Todas' ||
                  (_filter == 'Conquistadas'
                      ? _unlocked(item)
                      : !_unlocked(item)),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '$unlocked de ${items.length} conquistas',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cada descoberta conta uma parte da sua história com os gatos.',
                style: TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in [
                    'Todas',
                    'Conquistadas',
                    'Em progresso',
                  ])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    'Suas próximas conquistas começam com uma nova descoberta.',
                  ),
                ),
              for (final item in visible) _achievement(item),
            ],
          ),
        );
      },
    ),
  );

  Widget _achievement(Map<String, dynamic> item) {
    final unlocked = _unlocked(item);
    final target = ((item['target'] as num?)?.toInt() ?? 1).clamp(1, 1000000);
    final progress = ((item['progress'] as num?)?.toInt() ?? 0).clamp(
      0,
      target,
    );
    final id = item['id']?.toString() ?? '';
    final rarity = _rarityForId(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.achievementBg : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 14),
            child: Icon(
              _iconForId(id),
              size: 28,
              color: unlocked
                  ? AppColors.achievementText
                  : AppColors.textMedium,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? 'Conquista',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['description']?.toString() ?? '',
                  style: const TextStyle(color: AppColors.textMedium),
                ),
                const SizedBox(height: 12),
                if (!unlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / target,
                      minHeight: 6,
                      color: AppColors.greenProgress,
                      backgroundColor: AppColors.greenLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  unlocked
                      ? 'Conquistada · ${rarity.label}'
                      : '$progress de $target',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenLink,
                  ),
                ),
                if (unlocked)
                  Wrap(
                    spacing: 8,
                    children: [
                      if (widget.store.sessionStore.isSignedIn)
                        TextButton(
                          onPressed: _busy ? null : () => _share(item, true),
                          child: const Text('Compartilhar na comunidade'),
                        ),
                      TextButton(
                        onPressed: _busy ? null : () => _share(item, false),
                        child: const Text('Outros apps'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
