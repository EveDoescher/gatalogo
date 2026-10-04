import '../widgets/botanical_scene.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/cat.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import '../widgets/active_search_proximity_card.dart';
import '../widgets/app_widgets.dart';
import '../widgets/inbox_button.dart';
import '../widgets/illustrated_home_components.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HomeArt.background,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HomeArt.paper, HomeArt.background],
          stops: [0, .5],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: GatalogoArt.image(
                'backgrounds/background_garden_frame',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: AnimatedBuilder(
              animation: Listenable.merge([catStore, sessionStore]),
              builder: (context, _) => LayoutBuilder(
                builder: (context, viewport) {
                  final width = viewport.maxWidth.clamp(0.0, 560.0);
                  final scale = width / 390;
                  final progress = catStore.gamification;
                  final hasProgress = catStore.progress.summary.containsKey(
                    'xp',
                  );
                  final missions = catStore.progress.dailyMissions;
                  final mission =
                      missions
                          .where((m) => m['completed'] != true)
                          .firstOrNull ??
                      missions.firstOrNull;
                  final last = catStore.discoveries.firstOrNull;
                  return RefreshIndicator(
                    onRefresh: () async {
                      await catStore.syncCatalog(manual: true);
                      await catStore.refreshGamification();
                      await catStore.refreshNotifications();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Center(
                        child: SizedBox(
                          width: width,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              10 * scale,
                              7 * scale,
                              10 * scale,
                              22 * scale + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10 * scale,
                                  ),
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        'assets/gatalogo_asset_library/branding/brand_gatalogo_logo.png',
                                        width: 143 * scale,
                                        fit: BoxFit.contain,
                                      ),
                                      const Spacer(),
                                      InboxButton(
                                        store: catStore,
                                        size: 42 * scale,
                                        illustrated: true,
                                      ),
                                      SizedBox(width: 6 * scale),
                                      UserAvatarButton(
                                        sessionStore: sessionStore,
                                        catStore: catStore,
                                        size: 51 * scale,
                                        framed: true,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 3 * scale),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2 * scale,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 76 * scale,
                                        height: 58 * scale,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned.fill(
                                              child: HomeArt.image('Badge'),
                                            ),
                                            Transform.translate(
                                              offset: Offset(
                                                1 * scale,
                                                -3 * scale,
                                              ),
                                              child: Text(
                                                hasProgress
                                                    ? '${progress.level}'
                                                    : '—',
                                                style: HomeArt.title(26 * scale)
                                                    .copyWith(height: 1),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 3 * scale),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hasProgress
                                                  ? progress.levelTitle
                                                  : 'Sua jornada',
                                              style: HomeArt.title(17 * scale),
                                            ),
                                            SizedBox(height: 5 * scale),
                                            IllustratedProgress(
                                              current: hasProgress
                                                  ? progress.currentLevelXp
                                                  : 0,
                                              target:
                                                  progress.currentLevelTargetXp,
                                              label: hasProgress
                                                  ? '${progress.xp} / ${progress.targetXp} XP'
                                                  : 'XP indisponível',
                                              height: 18 * scale,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8 * scale),
                                      Semantics(
                                        button: true,
                                        label: 'Moedas do Habitat',
                                        child: InkWell(
                                          onTap: () => onNavigate(4),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4 * scale,
                                              vertical: 3 * scale,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF2D7),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              border: Border.all(
                                                color: const Color(0xFFCC994D),
                                                width: 1.4,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                HomeArt.image(
                                                  'Coin',
                                                  width: 25 * scale,
                                                  height: 25 * scale,
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6 * scale,
                                                  ),
                                                  child: Text(
                                                    '${catStore.progress.summary['balance'] ?? '—'}',
                                                    style: HomeArt.title(
                                                      17 * scale,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: HomeArt.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Icon(
                                                    Icons.add_rounded,
                                                    size: 20 * scale,
                                                    color: HomeArt.paper,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ActiveSearchProximityCard(
                                  sessionStore: sessionStore,
                                  catStore: catStore,
                                ),
                                SizedBox(height: 4 * scale),
                                _DailyBoard(
                                  mission: mission,
                                  scale: scale,
                                  signedIn: sessionStore.isSignedIn,
                                  onTap: () => _open(
                                    context,
                                    JourneyPage(store: catStore),
                                  ),
                                ),
                                _SectionHeading(
                                  title: 'Suas conquistas',
                                  action: 'Ver mural',
                                  icon: LucideIcons.sprout,
                                  scale: scale,
                                  onTap: () => _open(
                                    context,
                                    JourneyPage(store: catStore),
                                  ),
                                ),
                                SizedBox(height: 5 * scale),
                                _AchievementShelf(
                                  challenges: catStore.progress.challenges,
                                  scale: scale,
                                  onTap: () => _open(
                                    context,
                                    JourneyPage(store: catStore),
                                  ),
                                ),
                                SizedBox(height: 31 * scale),
                                IllustratedCaptureButton(
                                  onTap: () => onNavigate(2),
                                ),
                                SizedBox(height: 24 * scale),
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _IllustratedShortcut(
                                          title: 'Meus Gatos',
                                          art: 'Photo',
                                          scale: scale,
                                          description:
                                              'Ver e gerenciar meus gatos.',
                                          detail:
                                              '${catStore.pets.length} ${catStore.pets.length == 1 ? 'gato' : 'gatos'}',
                                          onTap: () => _open(
                                            context,
                                            MyCatsPage(store: catStore),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8 * scale),
                                      Expanded(
                                        child: _IllustratedShortcut(
                                          title: 'Meu Mapa',
                                          art: 'Map',
                                          scale: scale,
                                          description: 'Descobrir onde os gatos foram encontrados.',
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
                                ),
                                SizedBox(height: 17 * scale),
                                _SectionHeading(
                                  title: 'Última descoberta',
                                  action: 'Ver todas',
                                  icon: Icons.pets_rounded,
                                  scale: scale,
                                  pink: true,
                                  onTap: () => onNavigate(3),
                                ),
                                SizedBox(height: 7 * scale),
                                if (last != null)
                                  _LatestDiscovery(
                                    cat: last,
                                    scale: scale,
                                    onTap: () => _open(
                                      context,
                                      CatDetailsPage(
                                        cat: last,
                                        catStore: catStore,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: EdgeInsets.all(16 * scale),
                                    decoration: BoxDecoration(
                                      color: HomeArt.paper,
                                      border: Border.all(
                                        color: HomeArt.edge,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Row(
                                      children: [
                                        HomeArt.image(
                                          'Photo',
                                          width: 66 * scale,
                                        ),
                                        SizedBox(width: 14 * scale),
                                        Expanded(
                                          child: Text(
                                            'Sua primeira descoberta vai aparecer aqui.',
                                            style: HomeArt.title(17 * scale),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 42 * scale),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DailyBoard extends StatelessWidget {
  const _DailyBoard({
    required this.mission,
    required this.scale,
    required this.signedIn,
    required this.onTap,
  });
  final Map<String, dynamic>? mission;
  final double scale;
  final bool signedIn;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final done = mission?['completed'] == true;
    final title = mission?['title'] as String? ?? 'Missões indisponíveis';
    final description = mission == null
        ? (signedIn
              ? 'Sincronize para carregar a jornada de hoje.'
              : 'Entre na sua conta para ver suas missões.')
        : mission?['description'] as String? ??
              (done
                  ? 'Sua jornada de hoje está guardada.'
                  : 'Encontre e fotografe um gato no seu dia.');
    final reward = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Recompensas', style: HomeArt.title(11 * scale)),
        SizedBox(height: 5 * scale),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RewardToken(
              art: 'Star',
              label: mission == null
                  ? '— XP'
                  : '+${mission!['xp_reward'] ?? 0} XP',
              scale: scale,
            ),
            SizedBox(width: 5 * scale),
            _RewardToken(
              art: 'Coin',
              label: mission == null ? '—' : '+${mission!['coin_reward'] ?? 0}',
              scale: scale,
            ),
          ],
        ),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: HomeArt.title(12.5 * scale)),
        SizedBox(height: 4 * scale),
        Text(
          description,
          style: GoogleFonts.nunito(
            fontSize: 10.5 * scale,
            height: 1.12,
            color: HomeArt.ink,
          ),
        ),
        SizedBox(height: 4 * scale),
        if (mission != null)
          IllustratedProgress(
            current: mission?['progress'] as num? ?? 0,
            target: mission?['target'] as num? ?? 1,
            height: 15 * scale,
          ),
      ],
    );
    if (!enlarged) {
      return LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          // Supplied artwork: 1478 x 520. Content follows its open paper areas.
          return Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: w * 520 / 1478,
                child: Stack(
                  children: [
                    Positioned.fill(child: HomeArt.image('Card')),
                    Positioned(
                      left: w * .29,
                      top: w * .047,
                      width: w * .30,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Jornada de hoje',
                          style: HomeArt.title(15 * scale)
                              .copyWith(color: HomeArt.paper),
                        ),
                      ),
                    ),
                    Positioned(
                      left: w * .085,
                      top: w * .137,
                      width: w * .15,
                      height: w * .17,
                      child: HomeArt.image('Board'),
                    ),
                    Positioned(
                      left: w * .245,
                      top: w * .133,
                      width: w * .385,
                      bottom: w * .045,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: w * .385, child: content),
                      ),
                    ),
                    Positioned(
                      left: w * .675,
                      top: w * .133,
                      width: w * .25,
                      bottom: w * .045,
                      child: FittedBox(fit: BoxFit.scaleDown, child: reward),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(child: HomeArt.image('Card', fit: BoxFit.fill)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                29 * scale,
                19 * scale,
                27 * scale,
                20 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 67 * scale),
                    child: Text(
                      'Jornada de hoje',
                      style: HomeArt.title(17 * scale)
                          .copyWith(color: HomeArt.paper),
                    ),
                  ),
                  SizedBox(height: 21 * scale),
                  if (enlarged) ...[
                    content,
                    SizedBox(height: 12 * scale),
                    Align(alignment: Alignment.centerRight, child: reward),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HomeArt.image(
                          'Board',
                          width: 60 * scale,
                          height: 78 * scale,
                        ),
                        SizedBox(width: 6 * scale),
                        Expanded(child: content),
                        SizedBox(width: 22 * scale),
                        reward,
                      ],
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

class _RewardToken extends StatelessWidget {
  const _RewardToken({
    required this.art,
    required this.label,
    required this.scale,
  });
  final String art, label;
  final double scale;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 39 * scale,
        height: 40 * scale,
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE6CC),
          borderRadius: BorderRadius.circular(9),
        ),
        child: HomeArt.image(art),
      ),
      SizedBox(height: 4 * scale),
      Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 10 * scale,
          fontWeight: FontWeight.w900,
          color: HomeArt.ink,
        ),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.icon,
    required this.scale,
    required this.onTap,
    this.pink = false,
  });
  final String title, action;
  final IconData icon;
  final double scale;
  final VoidCallback onTap;
  final bool pink;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 19 * scale,
        color: pink ? const Color(0xFFE78DA1) : const Color(0xFF64894B),
      ),
      SizedBox(width: 6 * scale),
      Expanded(child: Text(title, style: HomeArt.title(16 * scale))),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action,
              style: GoogleFonts.nunito(
                fontSize: 12 * scale,
                fontWeight: FontWeight.w800,
                color: HomeArt.green,
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 17 * scale,
              color: HomeArt.green,
            ),
          ],
        ),
      ),
    ],
  );
}

class _AchievementShelf extends StatelessWidget {
  const _AchievementShelf({
    required this.challenges,
    required this.scale,
    required this.onTap,
  });
  final List<Map<String, dynamic>> challenges;
  final double scale;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (challenges.isEmpty)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14 * scale),
            child: Text(
              'Suas conquistas aparecem após sincronizar a conta.',
              style: GoogleFonts.nunito(
                fontSize: 12 * scale,
                color: HomeArt.ink,
              ),
            ),
          ),
        ),
      for (var i = 0; i < challenges.length && i < 5; i++)
        Expanded(
          child: Builder(
            builder: (context) {
              final goal = i < challenges.length ? challenges[i] : null;
              final earned = goal?['completed'] == true;
              final started = (goal?['progress'] as num? ?? 0) > 0;
              return Semantics(
                button: true,
                label: goal == null
                    ? 'Carregar conquistas'
                    : '${goal['title']}: ${goal['progress']} de ${goal['target']}',
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(40),
                  child: SizedBox(
                    height: 66 * scale,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: 58 * scale,
                          height: 58 * scale,
                          padding: EdgeInsets.all(5 * scale),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: earned || started
                                ? const Color(0xFFFFDFA2)
                                : const Color(0xFFE8D6B7),
                            border: Border.all(
                              color: earned || started
                                  ? const Color(0xFFAD7F45)
                                  : const Color(0xFFC7AA85),
                              width: 1.4,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0 && (earned || started)
                                  ? const Color(0xFFF8C8BD)
                                  : const Color(0xFFF0E8CE),
                              border: Border.all(
                                color: const Color(0xFFD6C6A5),
                                width: 1.4,
                              ),
                            ),
                            child: i == 0 && (earned || started)
                                ? Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: HomeArt.image('Cat'),
                                  )
                                : Icon(
                                    [
                                      Icons.pets_rounded,
                                      LucideIcons.sprout,
                                      LucideIcons.camera,
                                      Icons.favorite_rounded,
                                      LucideIcons.house,
                                    ][i],
                                    size: 28 * scale,
                                    color: earned
                                        ? HomeArt.green
                                        : const Color(0xFFAFA58B),
                                  ),
                          ),
                        ),
                        if (earned || started)
                          Positioned(
                            bottom: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale,
                                vertical: 2 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBD956C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${goal?['progress']} / ${goal?['target']}',
                                style: GoogleFonts.nunito(
                                  fontSize: 10 * scale,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            right: 1 * scale,
                            bottom: 1 * scale,
                            child: Container(
                              padding: EdgeInsets.all(2 * scale),
                              decoration: const BoxDecoration(
                                color: HomeArt.paper,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_rounded,
                                size: 15 * scale,
                                color: const Color(0xFF967A54),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );
}

class _IllustratedShortcut extends StatelessWidget {
  const _IllustratedShortcut({
    required this.title,
    required this.art,
    required this.description,
    required this.scale,
    required this.onTap,
    this.detail,
  });
  final String title, art, description;
  final String? detail;
  final double scale;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: HomeArt.paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: HomeArt.edge, width: 1.6),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          5 * scale,
          9 * scale,
          7 * scale,
          7 * scale,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 47, child: HomeArt.image(art, height: 82 * scale)),
            SizedBox(width: 3 * scale),
            Expanded(
              flex: 53,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HomeArt.title(14 * scale)),
                  SizedBox(height: 6 * scale),
                  Text(
                    description,
                    style: GoogleFonts.nunito(
                      fontSize: 9 * scale,
                      height: 1.2,
                      color: const Color(0xFF786551),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(height: 5 * scale),
                  Row(
                    children: [
                      if (detail != null)
                        Expanded(
                          child: Text(
                            detail!,
                            style: HomeArt.title(12 * scale),
                          ),
                        )
                      else
                        const Spacer(),
                      Container(
                        padding: EdgeInsets.all(3 * scale),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: HomeArt.edge),
                        ),
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 19 * scale,
                          color: HomeArt.ink,
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
  );
}

class _LatestDiscovery extends StatelessWidget {
  const _LatestDiscovery({
    required this.cat,
    required this.scale,
    required this.onTap,
  });
  final Cat cat;
  final double scale;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(cat.capturedAt).inDays;
    final when = days <= 0
        ? 'Hoje'
        : days == 1
        ? 'Ontem'
        : 'Há $days dias';
    return Material(
      color: HomeArt.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HomeArt.edge, width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: 4,
              bottom: -18,
              child: HomeArt.image('Flor', width: 70 * scale),
            ),
            Padding(
              padding: EdgeInsets.all(7 * scale),
              child: Row(
                children: [
                  SizedBox(
                    width: 114 * scale,
                    height: 59 * scale,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CatPhotoView(cat.photoPath, borderRadius: 8),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HomeArt.paper,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '#${cat.captureNumber.toString().padLeft(3, '0')}',
                              style: GoogleFonts.nunito(fontSize: 10 * scale),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 11 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name?.trim().isNotEmpty == true
                              ? cat.displayName
                              : 'Gato registrado',
                          style: HomeArt.title(15 * scale),
                        ),
                        SizedBox(height: 3 * scale),
                        Text(
                          '$when${cat.locationName == null ? '' : ' · ${cat.locationName}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 10 * scale,
                            color: const Color(0xFF86725E),
                          ),
                        ),
                        SizedBox(height: 5 * scale),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9 * scale,
                            vertical: 3 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD2DC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cat.status == 'completed' ? 'Descoberta' : 'Salvo',
                            style: GoogleFonts.nunito(
                              fontSize: 10 * scale,
                              color: const Color(0xFF8C4356),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.circleChevronRight,
                    color: HomeArt.edge,
                    size: 26 * scale,
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
