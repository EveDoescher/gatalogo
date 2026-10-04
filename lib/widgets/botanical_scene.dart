import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// User-supplied artwork, always displayed at its original aspect ratio.
class GatalogoArt {
  static const root = 'assets/gatalogo_asset_library/';
  static Widget image(
    String asset, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) => Image.asset(
    '$root$asset.png',
    width: width,
    height: height,
    fit: fit,
    excludeFromSemantics: true,
  );
}

enum BotanicalMood { garden, album, community, care, quiet }

/// Visual depth follows navigation, rather than the subject of a page.
enum BotanicalLevel { primary, secondary, tertiary, authentication }

class BotanicalLevelScope extends InheritedWidget {
  const BotanicalLevelScope({
    super.key,
    required this.level,
    required super.child,
  });
  final BotanicalLevel level;
  static BotanicalLevel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BotanicalLevelScope>()?.level;
  @override
  bool updateShouldNotify(BotanicalLevelScope oldWidget) =>
      level != oldWidget.level;
}

class IllustratedProfileIdentity extends StatelessWidget {
  const IllustratedProfileIdentity({
    super.key,
    required this.portrait,
    required this.name,
  });
  final Widget portrait, name;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      IllustratedGardenStage(
        height: 162,
        child: SizedBox(width: 116, height: 116, child: portrait),
      ),
      const SizedBox(height: 10),
      name,
    ],
  );
}

class IllustratedSectionTitle extends StatelessWidget {
  const IllustratedSectionTitle({
    super.key,
    required this.title,
    required this.art,
  });
  final String title, art;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      GatalogoArt.image(art, width: 42, height: 46),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
}

/// One purposeful illustrated object beside readable page context.
class IllustratedPaperHeading extends StatelessWidget {
  const IllustratedPaperHeading({
    super.key,
    required this.title,
    required this.description,
    required this.art,
  });
  final String title, description, art;

  @override
  Widget build(BuildContext context) => BotanicalPaper(
    foliage: false,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GatalogoArt.image(art, width: 76, height: 88),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

/// An illustrated garden still life that can host a portrait, object or mascot.
class IllustratedGardenStage extends StatelessWidget {
  const IllustratedGardenStage({
    super.key,
    required this.child,
    this.height = 170,
  });
  final Widget child;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: height,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 10,
          right: 10,
          bottom: 0,
          child: IgnorePointer(
            child: GatalogoArt.image(
              'environment/environment_grass_stones_flowers',
              height: 76,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 22), child: child),
      ],
    ),
  );
}

/// A collectible-looking label whose value is supplied by the account.
class IllustratedStatTile extends StatelessWidget {
  const IllustratedStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.art,
  });
  final String value, label, art;
  @override
  Widget build(BuildContext context) => BotanicalPaper(
    foliage: false,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Column(
      children: [
        GatalogoArt.image(art, width: 46, height: 42),
        const SizedBox(height: 7),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}

/// Map artwork frames the actual sighting photo; location stays on the marker.
class IllustratedPhotoPin extends StatelessWidget {
  const IllustratedPhotoPin({
    super.key,
    required this.photo,
    this.selected = false,
  });
  final Widget photo;
  final bool selected;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: GatalogoArt.image(
          selected
              ? 'environment/environment_map_pin_cat_coral_grass'
              : 'environment/environment_map_pin_cat_gold',
        ),
      ),
      Align(
        alignment: const Alignment(0, -.42),
        child: FractionallySizedBox(
          widthFactor: .5,
          heightFactor: .42,
          child: ClipOval(child: photo),
        ),
      ),
    ],
  );
}

/// A small still life beside live page content, without baking text into art.
class IllustratedSectionHeader extends StatelessWidget {
  const IllustratedSectionHeader({
    super.key,
    required this.title,
    required this.description,
    required this.art,
    this.accent = 'flora/flora_leaves_pair_outline',
  });
  final String title, description, art, accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: MediaQuery.sizeOf(context).width < 350 ? 72 : 96,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: 0,
              bottom: 4,
              child: GatalogoArt.image(accent, width: 54, height: 38),
            ),
            Positioned.fill(bottom: 10, child: GatalogoArt.image(art)),
          ],
        ),
      ),
    ],
  );
}

/// Background decoration never occupies the task's layout or hit regions.
class BotanicalScene extends StatelessWidget {
  const BotanicalScene({
    super.key,
    required this.child,
    this.mood = BotanicalMood.quiet,
    this.color = AppColors.background,
  });
  final Widget child;
  final BotanicalMood mood;
  final Color color;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child:
                  mood == BotanicalMood.garden ||
                      mood == BotanicalMood.community
                  ? GatalogoArt.image(
                      'backgrounds/background_garden_frame',
                      fit: BoxFit.cover,
                    )
                  : Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          right: -14,
                          top: 18,
                          child: Opacity(
                            opacity: .35,
                            child: Transform.rotate(
                              angle: 3.141592653589793,
                              child: GatalogoArt.image(
                                'flora/flora_branch_pale_diagonal_01',
                                width: 78,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -16,
                          bottom: -18,
                          child: Opacity(
                            opacity: .48,
                            child: GatalogoArt.image(
                              'flora/flora_branch_pale_long_02',
                              width: 112,
                            ),
                          ),
                        ),
                        if (mood != BotanicalMood.quiet)
                          Positioned(
                            right: -5,
                            bottom: 0,
                            child: GatalogoArt.image(
                              mood == BotanicalMood.care
                                  ? 'flora/flora_grass_pink_flowers_pair'
                                  : 'flora/flora_corner_white_flower_dense_01',
                              width: 72,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        Material(type: MaterialType.transparency, child: child),
      ],
    ),
  );
}

/// Common paper and botanical setting; each route keeps its own composition.
class BotanicalScaffold extends StatelessWidget {
  const BotanicalScaffold({
    super.key,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.mood = BotanicalMood.quiet,
    this.level,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body,
      floatingActionButton,
      bottomNavigationBar,
      bottomSheet,
      drawer,
      endDrawer;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody, extendBodyBehindAppBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? persistentFooterButtons;
  final BotanicalMood mood;
  final BotanicalLevel? level;
  @override
  Widget build(BuildContext context) {
    final depth =
        level ??
        BotanicalLevelScope.maybeOf(context) ??
        BotanicalLevel.secondary;
    final requestedColor = backgroundColor ?? AppColors.background;
    final photographic =
        requestedColor == Colors.black ||
        requestedColor == AppColors.textDark ||
        requestedColor == Colors.transparent;
    final legacy = photographic || depth == BotanicalLevel.authentication;
    final color = legacy
        ? requestedColor
        : depth == BotanicalLevel.tertiary
        ? AppColors.surface
        : AppColors.background;
    final sceneMood = legacy
        ? mood
        : depth == BotanicalLevel.primary
        ? BotanicalMood.garden
        : BotanicalMood.quiet;
    return Scaffold(
      appBar: appBar,
      backgroundColor: color,
      body: body == null || photographic
          ? body
          : BotanicalScene(mood: sceneMood, color: color, child: body!),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      persistentFooterButtons: persistentFooterButtons,
      drawer: drawer,
      endDrawer: endDrawer,
    );
  }
}

class BotanicalPaper extends StatelessWidget {
  const BotanicalPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.foliage = true,
    this.color = AppColors.surface,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool foliage;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border, width: 1.2),
    ),
    child: Stack(
      children: [
        if (foliage) ...[
          Positioned(
            left: -3,
            bottom: -3,
            child: IgnorePointer(
              child: GatalogoArt.image(
                'flora/flora_leaves_pair_outline',
                width: 34,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: IgnorePointer(
              child: GatalogoArt.image(
                'flora/flora_leaf_cluster_flat_dark_01',
                width: 40,
              ),
            ),
          ),
        ],
        Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ],
    ),
  );
}

class BotanicalEmpty extends StatelessWidget {
  const BotanicalEmpty({
    super.key,
    required this.title,
    required this.description,
    this.art = 'cats/cat_orange_sleeping',
    this.action,
    this.illustration,
  });
  final String title, description, art;
  final Widget? action;
  final Widget? illustration;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        illustration ?? GatalogoArt.image(art, width: 110, height: 90),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

/// One accessible primary-control implementation across capture, forms and game.
class BotanicalAction extends StatelessWidget {
  const BotanicalAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.fullWidth = true,
    this.green = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy, fullWidth, green;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: fullWidth ? double.infinity : null,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        backgroundColor: green
            ? AppColors.greenButton
            : const Color(0xFFEBA7B9),
        foregroundColor: green ? AppColors.surface : AppColors.textDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: green ? const Color(0xFF39582B) : const Color(0xFFB77976),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 23),
          if (busy || icon != null) const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: green ? AppColors.surface : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
