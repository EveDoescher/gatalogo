import 'botanical_scene.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/habitat_sprites.dart';
import '../models/cat.dart';
import '../services/habitat_service.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'habitat_sprite_preview.dart';

IconData challengeIcon(String id) {
  if (id.contains('color')) return Icons.palette_rounded;
  if (id.contains('day')) return Icons.wb_sunny_rounded;
  if (id.contains('angle') || id.contains('reference')) {
    return Icons.photo_library_rounded;
  }
  if (id.contains('first')) return Icons.auto_awesome_rounded;
  return Icons.pets_rounded;
}

/// Shared game materials. Photos, earned resources and Quintal objects stay real.
class GameStyle {
  static const paper = Color(0xFFFBF6E8);
  static const canvas = Color(0xFFF0F0DD);
  static const ink = Color(0xFF94724E);
  static const edge = Color(0xFFBCA381);
  static const gold = Color(0xFFF5CC66);
  static const greenPaper = Color(0xFFE7EEDC);
  static const pinkEdge = Color(0xFFB5647C);
  static TextStyle title(double size) => GoogleFonts.fredoka(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: AppColors.textTitle,
  );
}

class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.color = GameStyle.paper,
    this.edge = GameStyle.edge,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color color, edge;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: edge, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14927754),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

/// A bound paper surface, shared by the album and the game's home.
/// The binding is geometry; all botanical and character art uses existing assets.
class GameNotebook extends StatelessWidget {
  const GameNotebook({
    super.key,
    required this.child,
    this.spread = false,
    this.padding = const EdgeInsets.fromLTRB(26, 20, 16, 20),
  });
  final Widget child;
  final bool spread;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 3, 4, 7),
    decoration: BoxDecoration(
      color: const Color(0xFF7C985D),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: GameStyle.ink, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22927754),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Container(
      decoration: BoxDecoration(
        color: GameStyle.paper,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFDDCCAD)),
      ),
      child: Stack(
        children: [
          if (!spread)
            const Positioned(
              top: 5,
              bottom: 5,
              left: 15,
              width: 1,
              child: ColoredBox(color: Color(0xFFE3D1B3)),
            ),
          if (spread)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFFDDCAAA),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: spread ? Alignment.center : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: spread ? 0 : 2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 168),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        3,
                        (i) => Container(
                          width: 19,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7C89F),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: GameStyle.ink,
                              width: 1.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class GameTape extends StatelessWidget {
  const GameTape({
    super.key,
    this.color = const Color(0xCCDDC59D),
    this.width = 48,
  });
  final Color color;
  final double width;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Transform.rotate(
      angle: -.08,
      child: GatalogoArt.image(
        'ui/ui_tape_pink_polka_dot',
        width: width,
        height: 19,
      ),
    ),
  );
}

class GameNote extends StatelessWidget {
  const GameNote({
    super.key,
    required this.child,
    this.color = GameStyle.paper,
  });
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        GamePanel(
          color: color,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: child,
        ),
        const Positioned(top: -6, right: 18, child: GameTape()),
      ],
    ),
  );
}

class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.camera_alt_rounded,
    this.green = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool green;
  @override
  Widget build(BuildContext context) => BotanicalAction(
    label: label,
    onPressed: onPressed,
    icon: icon,
    green: green,
  );
}

class GameReward extends StatelessWidget {
  const GameReward({
    super.key,
    required this.value,
    this.coins = false,
    this.large = false,
  });
  final String value;
  final bool coins, large;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: large ? 14 : 9,
      vertical: large ? 10 : 5,
    ),
    decoration: BoxDecoration(
      color: coins ? const Color(0xFFFFE9A6) : const Color(0xFFE3EDD5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: coins ? const Color(0xFFDCB85B) : const Color(0xFFA3B58E),
        width: 1.2,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (coins)
          Image.asset(
            'assets/gatalogo_asset_library/rewards/reward_coin_paw_gold.png',
            width: large ? 28 : 21,
            height: large ? 28 : 21,
          )
        else
          GatalogoArt.image(
            'rewards/reward_star_gold',
            width: large ? 29 : 21,
            height: large ? 29 : 21,
          ),
        const SizedBox(width: 5),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: large ? 22 : 13,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
      ],
    ),
  );
}

class GameProgress extends StatelessWidget {
  const GameProgress({
    super.key,
    required this.current,
    required this.target,
    this.label,
    this.gold = false,
  });
  final num current, target;
  final String? label;
  final bool gold;
  @override
  Widget build(BuildContext context) => Semantics(
    value: '$current de $target',
    child: Container(
      height: 24,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE5DECC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6BB9F), width: 1.3),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: target > 0 ? (current / target).clamp(0.0, 1.0) : 0,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: gold ? GameStyle.gold : const Color(0xFFAEC58C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.fromLTRB(5, 3, 5, 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              label ?? '${current.toInt()} / ${target.toInt()}',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class GameSeal extends StatelessWidget {
  const GameSeal({
    super.key,
    this.icon = Icons.pets_rounded,
    this.size = 52,
    this.done = false,
    this.label,
  });
  final IconData icon;
  final double size;
  final bool done;
  final String? label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size + 7,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: GatalogoArt.image('ui/ui_seal_cream_green_blank'),
        ),
        if (label != null)
          Text(label!, style: GameStyle.title(size * .38))
        else
          Icon(
            done ? Icons.check_rounded : icon,
            size: size * .48,
            color: done ? AppColors.greenButton : AppColors.achievementText,
          ),
      ],
    ),
  );
}

/// Paper mounting for a real local, protected or remote photograph.
class GamePhotoMount extends StatelessWidget {
  const GamePhotoMount({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: GameStyle.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GameStyle.ink, width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: child,
          ),
        ),
        const Positioned(top: -5, right: 22, child: GameTape()),
      ],
    ),
  );
}

class GamePhotoCard extends StatelessWidget {
  const GamePhotoCard({
    super.key,
    required this.cat,
    this.onTap,
    this.height = 150,
    this.showName = true,
  });
  final Cat cat;
  final VoidCallback? onTap;
  final double height;
  final bool showName;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: GameStyle.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: const BorderSide(color: GameStyle.ink, width: 1.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      CatPhotoView(
                        cat.photoPath,
                        height: height,
                        fit: BoxFit.cover,
                        borderRadius: 4,
                      ),
                      Positioned(
                        left: 5,
                        top: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: GameStyle.paper,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${cat.captureNumber.toString().padLeft(3, '0')}',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showName)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                      child: Text(
                        cat.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameStyle.title(17),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: GameTape()),
        ),
      ],
    ),
  );
}

class GameSprite extends StatelessWidget {
  const GameSprite(this.sprite, {super.key, this.size = 82});
  final String sprite;
  final double size;
  static final sprites = HabitatSprites();
  @override
  Widget build(BuildContext context) =>
      HabitatSpritePreview(sprites: sprites, keyName: sprite, size: size);
}

class GameItemArt extends StatelessWidget {
  const GameItemArt(this.sku, {super.key, this.size = 64});
  final String sku;
  final double size;
  @override
  Widget build(BuildContext context) {
    final item = HabitatService.catalogItem(sku);
    if (item == null) return Icon(Icons.inventory_2_outlined, size: size * .6);
    return GameSprite(GameSprite.sprites.keyFor(item.sprite, 0), size: size);
  }
}

/// A small illustrated doorway to Quintal, using the same licensed game assets.
/// It deliberately does not pretend to be the player's saved layout.
class HabitatVignette extends StatelessWidget {
  const HabitatVignette({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 126,
    child: LayoutBuilder(
      builder: (context, box) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 6,
            child: Transform.rotate(
              angle: -.08,
              child: Container(
                width: box.maxWidth * .9,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFC5D6A3),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF9BAF7D), width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: box.maxWidth * .02,
            top: 3,
            child: const GameSprite('tree_default_NE', size: 77),
          ),
          Positioned(
            right: box.maxWidth * .02,
            bottom: 16,
            child: const GameSprite('building-type-a', size: 88),
          ),
          Positioned(
            left: box.maxWidth * .31,
            bottom: 1,
            child: const GameSprite('animal-cat', size: 46),
          ),
          Positioned(
            left: box.maxWidth * .04,
            bottom: 0,
            child: const GameSprite('flower_redA_NE', size: 40),
          ),
        ],
      ),
    ),
  );
}
