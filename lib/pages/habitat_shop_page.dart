import '../widgets/botanical_scene.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../services/product_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header_actions.dart';
import '../widgets/habitat_coin_badge.dart';
import '../widgets/habitat_sprite_preview.dart';

class HabitatShopPage extends StatefulWidget {
  const HabitatShopPage({
    super.key,
    required this.habitat,
    required this.sprites,
    required this.onClose,
  });

  final HabitatService habitat;
  final HabitatSprites sprites;
  final VoidCallback onClose;

  @override
  State<HabitatShopPage> createState() => _HabitatShopPageState();
}

class _HabitatShopPageState extends State<HabitatShopPage> {
  final Map<String, int> _quantities = {};
  String? _workingSku;
  String? _category;
  static const _categories = {
    'natureza': 'Natureza',
    'descanso': 'Descanso',
    'brincadeira': 'Brincadeira',
    'casinhas': 'Casinhas',
    'caminhos': 'Caminhos',
    'jardim': 'Jardim vivo',
    'terreno': 'Terreno',
  };

  @override
  void initState() {
    super.initState();
    widget.habitat.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.habitat.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _buy(HabitatShopItem item, int quantity) async {
    if (_workingSku != null) return;
    setState(() => _workingSku = item.sku);
    try {
      await widget.habitat.buy(item.sku, quantity: quantity);
    } on ProductApiException catch (error) {
      _error(error.message);
    } finally {
      if (mounted) setState(() => _workingSku = null);
    }
  }

  Future<void> _expand() async {
    if (_workingSku != null) return;
    setState(() => _workingSku = 'expansion');
    try {
      await widget.habitat.expand();
    } on HabitatConflictException {
      _error(
        'O quintal foi alterado em outro dispositivo. Atualize o Quintal e tente novamente.',
      );
    } on ProductApiException catch (error) {
      _error(error.message);
    } finally {
      if (mounted) setState(() => _workingSku = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitat = widget.habitat;
    final items = habitat.shop
        .where((item) => _category == null || item.category == _category)
        .toList();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 700
        ? 4
        : width >= 500
        ? 3
        : 2;
    return BotanicalScaffold(
      level: BotanicalLevel.secondary,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Voltar ao Quintal',
          onPressed: widget.onClose,
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: HabitatCoinBadge(balance: habitat.balance)),
          ),
          AppHeaderActions(store: habitat.catStore),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: const IllustratedSectionHeader(
                title: 'Loja do Quintal',
                description:
                    'Um cantinho para descansar, brincar e receber seus gatos.',
                art: 'environment/environment_shop_coral_awning',
                accent: 'environment/environment_grass_stones_flowers',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: _expansionCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                'Decorações e caminhos',
                style: GoogleFonts.fredoka(
                  fontSize: 21,
                  color: AppColors.textTitle,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in {null: 'Tudo', ..._categories}.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _category == entry.key,
                          onSelected: (_) =>
                              setState(() => _category = entry.key),
                          selectedColor: AppColors.primaryLight,
                          backgroundColor: AppColors.surface,
                          side: BorderSide.none,
                          labelStyle: TextStyle(color: AppColors.textTitle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverGrid.builder(
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 236,
              ),
              itemBuilder: (context, index) => _itemCard(items[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expansionCard() {
    final habitat = widget.habitat;
    final price = habitat.nextExpansionPrice;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expandir terreno',
            style: GoogleFonts.fredoka(
              fontSize: 24,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price == null
                ? 'Seu quintal já tem todo o espaço disponível.'
                : 'Mais espaço para decorações e mais um gato no Quintal.',
            style: GoogleFonts.nunito(color: AppColors.textMedium),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _YardPreview(
                  level: habitat.expansionLevel,
                  label: 'Atual',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  LucideIcons.arrowRight,
                  color: AppColors.textMedium,
                ),
              ),
              Expanded(
                child: _YardPreview(
                  level: (habitat.expansionLevel + 1).clamp(0, 3),
                  label: 'Próximo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: price == null || _workingSku != null ? null : _expand,
              icon: const Icon(LucideIcons.expand),
              label: Text(
                price == null
                    ? 'Terreno completo'
                    : price == 0
                    ? 'Expandir grátis para teste'
                    : 'Expandir por $price moedas',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(HabitatShopItem item) {
    final habitat = widget.habitat;
    final owned = habitat.items.where((entry) => entry.sku == item.sku).length;
    final quantity = _quantities[item.sku] ?? 1;
    final maxReached = owned >= item.maxOwned;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: HabitatSpritePreview(
                sprites: widget.sprites,
                keyName: widget.sprites.keyFor(item.sprite, 0),
                size: 91,
              ),
            ),
          ),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: AppColors.textTitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (owned > 0)
            Text(
              '$owned adquirido${owned == 1 ? '' : 's'}',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textMedium,
              ),
            ),
          const SizedBox(height: 5),
          if (item.isGround && !maxReached)
            SizedBox(
              height: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Menos trechos',
                    onPressed: quantity <= 1
                        ? null
                        : () => setState(
                            () => _quantities[item.sku] = quantity - 1,
                          ),
                    icon: const Icon(LucideIcons.minus, size: 16),
                  ),
                  Text('$quantity'),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Mais trechos',
                    onPressed:
                        quantity >= 20 || owned + quantity >= item.maxOwned
                        ? null
                        : () => setState(
                            () => _quantities[item.sku] = quantity + 1,
                          ),
                    icon: const Icon(LucideIcons.plus, size: 16),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed:
                  !item.canBuy ||
                      maxReached ||
                      _workingSku != null ||
                      owned + quantity > item.maxOwned
                  ? null
                  : () => _buy(item, quantity),
              child: Text(
                !item.canBuy
                    ? item.sku == 'friendship_garden'
                          ? (owned > 0 ? 'Desbloqueado' : '20 de afinidade')
                          : 'Inicial'
                    : maxReached
                    ? 'Adquirido'
                    : item.price == 0
                    ? 'Grátis para teste'
                    : '${item.price * quantity} moedas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YardPreview extends StatelessWidget {
  const _YardPreview({required this.level, required this.label});
  final int level;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 74,
        width: double.infinity,
        child: CustomPaint(
          painter: _YardPainter(HabitatService.yardCells(level)),
        ),
      ),
      Text(
        label,
        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMedium),
      ),
    ],
  );
}

class _YardPainter extends CustomPainter {
  const _YardPainter(this.cells);
  final Set<(int, int)> cells;

  @override
  void paint(Canvas canvas, Size size) {
    final projected = [
      for (final cell in cells)
        ((cell.$1 - cell.$2).toDouble(), (cell.$1 + cell.$2).toDouble()),
    ];
    final minX = projected
        .map((point) => point.$1)
        .reduce((a, b) => a < b ? a : b);
    final maxX = projected
        .map((point) => point.$1)
        .reduce((a, b) => a > b ? a : b);
    final minY = projected
        .map((point) => point.$2)
        .reduce((a, b) => a < b ? a : b);
    final maxY = projected
        .map((point) => point.$2)
        .reduce((a, b) => a > b ? a : b);
    final scale = (size.width - 10) / (maxX - minX + 2);
    final vertical = (size.height - 8) / (maxY - minY + 2);
    for (final point in projected) {
      final x = 5 + (point.$1 - minX + 1) * scale;
      final y = 4 + (point.$2 - minY + 1) * vertical;
      final diamond = Path()
        ..moveTo(x, y - vertical / 2)
        ..lineTo(x + scale / 2, y)
        ..lineTo(x, y + vertical / 2)
        ..lineTo(x - scale / 2, y)
        ..close();
      canvas.drawPath(diamond, Paint()..color = AppColors.green);
    }
  }

  @override
  bool shouldRepaint(covariant _YardPainter oldDelegate) =>
      oldDelegate.cells != cells;
}
