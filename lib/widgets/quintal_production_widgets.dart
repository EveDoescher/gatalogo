import 'dart:async';

import 'package:flutter/material.dart';

import '../services/habitat_service.dart';
import '../theme/app_theme.dart';
import 'botanical_scene.dart';

class QuintalArtwork extends StatelessWidget {
  const QuintalArtwork(this.asset, {super.key, this.size = 92});
  final String asset;
  final double size;
  static String pathFor(String asset) {
    if (asset == 'coin') {
      return 'assets/gatalogo_asset_library/rewards/reward_coin_paw_gold.png';
    }
    final illustrated = switch (asset) {
      'crops_cornStageD' => 'corn',
      'crops_wheatStageB' => 'wheat',
      'crop_carrot' => 'carrot',
      'crop_pumpkin' => 'pumpkin',
      'crop_turnip' => 'turnip',
      'crop_melon' => 'melon',
      'carton' => 'milk',
      'turkey' => 'chicken',
      'meat-raw' || 'beef' => 'meat',
      'pot-stew' => 'action_cook_pot',
      'crops_leafsStageA' => 'action_plant_seedling',
      'corn' ||
      'wheat' ||
      'carrot' ||
      'pumpkin' ||
      'milk' ||
      'chicken' ||
      'meat' ||
      'fish' ||
      'egg' ||
      'apple' ||
      'pear' ||
      'melon' ||
      'turnip' ||
      'mice' ||
      'cat_satisfaction' ||
      'icon_app' ||
      'ready' => asset,
      _ =>
        asset.startsWith('action_') || asset.startsWith('racao_')
            ? asset
            : null,
    };
    return 'assets/quintal/${illustrated == null ? 'production/$asset' : 'ui/$illustrated'}.png';
  }

  // Recipe IDs stay authoritative. Missing artwork does not invent a recipe.
  static String recipe(String id) => switch (id) {
    'basic' => 'racao_basica',
    'garden' => 'racao_planta',
    'fish' => 'racao_peixe',
    'chicken' => 'racao_frango',
    'beef' => 'racao_carne',
    'apple' => 'fruit_recipe_apple',
    'pear' => 'fruit_recipe_pear',
    _ => 'action_cook_pot',
  };
  @override
  Widget build(BuildContext context) => asset.startsWith('fruit_recipe_')
      ? SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              QuintalArtwork('racao_planta', size: size),
              Positioned(
                right: 0,
                bottom: 0,
                child: QuintalArtwork(
                  asset.substring('fruit_recipe_'.length),
                  size: size * .48,
                ),
              ),
            ],
          ),
        )
      : Image.asset(
          pathFor(asset),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(256, 512),
        );
}

class QuintalCountdown extends StatefulWidget {
  const QuintalCountdown({
    super.key,
    required this.habitat,
    required this.readyAt,
    this.prefix = '',
  });
  final HabitatService habitat;
  final String? readyAt;
  final String prefix;
  @override
  State<QuintalCountdown> createState() => _QuintalCountdownState();
}

class _QuintalCountdownState extends State<QuintalCountdown> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(widget.readyAt ?? '');
    final seconds = end == null
        ? 0
        : end.difference(widget.habitat.serverNow).inSeconds.clamp(0, 99999999);
    final time =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(
      seconds == 0 ? 'Pronto para coletar' : '${widget.prefix}$time',
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.greenLink,
      ),
    );
  }
}

class QuintalProductionPanel extends StatelessWidget {
  const QuintalProductionPanel({
    super.key,
    required this.title,
    required this.child,
    this.artwork,
    this.subtitle,
  });
  final String title;
  final String? artwork, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: BotanicalPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (artwork != null) QuintalArtwork(artwork!, size: 82),
              if (artwork != null) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) Text(subtitle!),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class QuintalPrice extends StatelessWidget {
  const QuintalPrice(this.definition, {super.key});
  final Map<String, dynamic> definition;
  @override
  Widget build(BuildContext context) {
    final base = (definition['base_price'] as num?)?.toInt() ?? 0;
    final price = (definition['price'] as num?)?.toInt() ?? 0;
    final seconds = (definition['seconds'] as num?)?.toInt() ?? 0;
    return Text(
      '${base > 0 && price == 0 ? 'Grátis para testes · preço base $base moedas' : '$price moedas'}${seconds == 0 ? ' · imediato' : ' · ${seconds ~/ 60} min'}',
      style: const TextStyle(color: AppColors.textMedium),
    );
  }
}
