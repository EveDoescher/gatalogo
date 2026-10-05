import '../services/habitat_navigation.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/api_config.dart';
import 'botanical_scene.dart';

class HomeArt {
  static const paper = Color(0xFFFBF6E8);
  static const background = Color(0xFFF0F0DD);
  static const ink = Color(0xFF4B281B);
  static const green = Color(0xFF426538);
  static const edge = Color(0xFF94724E);
  static const library = 'assets/gatalogo_asset_library/';
  static const artwork = {
    'Board': 'ui/ui_clipboard_checklist',
    'Board_2': 'ui/ui_clipboard_paw',
    'Flor': 'flora/flora_flower_white_leaf_cluster_01',
    'Flor_2': 'flora/flora_flower_white_two_leaves_small',
    'Flor_3': 'flora/flora_flower_white_two_leaves_tiny',
    'Badge': 'rewards/reward_badge_cat_gold_blank',
    'Bar': 'ui/ui_bar_foliage_dark_green',
    'Button': 'ui/ui_button_green_foliage',
    'Card': 'ui/ui_card_notebook_floral',
    'Photo': 'ui/ui_cat_photos_stack',
    'Map': 'environment/environment_cat_map',
    'Cat': 'cats/cat_calico_face',
    'Coin': 'rewards/reward_coin_paw_gold',
    'Star': 'rewards/reward_star_gold',
    'moldura': 'ui/ui_avatar_frame_floral_round',
    'bapinho_moldura': 'avatars/avatar_boy_floral_frame',
    'bapinha_moldura': 'avatars/avatar_girl_floral_frame',
  };
  static TextStyle title(double size) => GoogleFonts.fredoka(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: ink,
    height: 1.08,
  );
  static Widget image(
    String name, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) => Image.asset(
    '$library${artwork[name]!}.png',
    width: width,
    height: height,
    fit: fit,
    excludeFromSemantics: true,
  );
}

/// The frame and characters are supplied artwork. Uploaded portraits occupy the
/// circular inner opening; they never replace or stretch the botanical frame.
class FramedUserAvatar extends StatelessWidget {
  const FramedUserAvatar({super.key, this.url, this.localPath, this.size = 52});
  final String? url, localPath;
  final double size;
  static const presets = ['bapinho', 'bapinha'];
  static String? presetFor(String? url) {
    for (final preset in presets) {
      if (url == '/app/account/avatar/preset/$preset') return preset;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final preset = localPath == null ? presetFor(url) : null;
    if (preset != null) {
      return HomeArt.image('${preset}_moldura', width: size, height: size);
    }
    final fullUrl = url == null
        ? null
        : url!.startsWith('http')
        ? url!
        : '${ApiConfig.baseUrl}$url';
    final placeholder = Icon(
      LucideIcons.userRound,
      color: HomeArt.green,
      size: size * .4,
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(child: HomeArt.image('moldura')),
          Positioned(
            left: size * .115,
            top: size * .13,
            width: size * .755,
            height: size * .755,
            child: ClipOval(
              child: localPath != null
                  ? Image.file(
                      File(localPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    )
                  : fullUrl != null && url!.isNotEmpty
                  ? Image.network(
                      fullUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    )
                  : Center(child: placeholder),
            ),
          ),
        ],
      ),
    );
  }
}

class IllustratedProgress extends StatelessWidget {
  const IllustratedProgress({
    super.key,
    required this.current,
    required this.target,
    this.label,
    this.height = 18,
  });
  final num current, target;
  final String? label;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height:
        height.clamp(20.0, double.infinity) *
        MediaQuery.textScalerOf(context).scale(1),
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: const Color(0xFFF4EBD9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFC6AE8E), width: 1.4),
    ),
    child: Stack(
      children: [
        FractionallySizedBox(
          widthFactor: target > 0 ? (current / target).clamp(0.0, 1.0) : 0,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF8EB35C),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Center(
          child: Text(
            label ?? '${current.toInt()} / ${target.toInt()}',
            style: GoogleFonts.nunito(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              color: HomeArt.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class IllustratedCaptureButton extends StatelessWidget {
  const IllustratedCaptureButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Gatalogar',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: LayoutBuilder(
          builder: (context, box) {
            final artScale = (box.maxWidth / 370).clamp(.8, 1.5);
            return SizedBox(
              height:
                  (box.maxWidth * .19).clamp(62.0, 95.0) *
                  MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.3),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: HomeArt.image('Button')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: HomeArt.paper,
                          size: 29 * artScale,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Gatalogar',
                            style: HomeArt.title(23 * artScale)
                                .copyWith(color: HomeArt.paper),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          LucideIcons.chevronRight,
                          color: HomeArt.paper,
                          size: 22 * artScale,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Keeps each tab's background behind the menu down to the screen edge.
class IllustratedNavigationScaffold extends StatelessWidget {
  const IllustratedNavigationScaffold({
    super.key,
    required this.body,
    required this.index,
    required this.onSelect,
    this.unread = 0,
  });
  final Widget body;
  final int index, unread;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: BotanicalLevelScope(level: BotanicalLevel.primary, child: body),
    bottomNavigationBar: IllustratedNavigationBar(
      index: index,
      unread: unread,
      onSelect: onSelect,
    ),
  );
}

class IllustratedNavigationBar extends StatelessWidget {
  const IllustratedNavigationBar({
    super.key,
    required this.index,
    required this.onSelect,
    this.unread = 0,
  });
  final int index, unread;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(),
    child: Stack(
      children: [
        Positioned.fill(child: HomeArt.image('Bar', fit: BoxFit.cover)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final entry in const [
                  (LucideIcons.house, 'Início'),
                  (LucideIcons.usersRound, 'Social'),
                  (LucideIcons.camera, 'Gatalogar'),
                  (LucideIcons.bookOpen, 'Coleção'),
                  (LucideIcons.map, 'Quintal'),
                ].indexed)
                  Expanded(
                    child: Semantics(
                      selected: index == entry.$1,
                      button: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelect(entry.$1),
                          borderRadius: BorderRadius.circular(17),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 1,
                            ),
                            decoration: BoxDecoration(
                              color: index == entry.$1
                                  ? const Color(0xFFEDF3C9)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                              border: index == entry.$1
                                  ? Border.all(
                                      color: const Color(0xFF38512B),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<bool>(
                                  valueListenable: HabitatNavigation.hasGift,
                                  builder: (_, gift, _) => Badge(
                                    isLabelVisible:
                                        (entry.$1 == 1 && unread > 0) ||
                                        (entry.$1 == 4 && gift),
                                    child: Icon(
                                      entry.$2.$1,
                                      size: 22,
                                      color: index == entry.$1
                                          ? HomeArt.green
                                          : const Color(0xFFE3E9C7),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  entry.$2.$2,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: index == entry.$1
                                        ? HomeArt.green
                                        : const Color(0xFFF4F5DD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
