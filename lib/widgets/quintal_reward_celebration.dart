import 'dart:async';

import 'package:flutter/material.dart';

import '../game/habitat_sprites.dart';
import '../services/habitat_service.dart';
import '../services/product_api_service.dart';
import '../theme/app_theme.dart';
import 'habitat_sprite_preview.dart';
import 'quintal_production_widgets.dart';

/// Only durable server receipts can enter this queue; no credits are made here.
class QuintalRewardCelebrations extends StatelessWidget {
  const QuintalRewardCelebrations({
    super.key,
    required this.habitat,
    required this.sprites,
    required this.onInventory,
  });
  final HabitatService habitat;
  final HabitatSprites sprites;
  final VoidCallback onInventory;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: habitat,
    builder: (context, _) {
      final rewards = habitat.pendingProductionRewards;
      if (rewards.isEmpty) return const SizedBox.shrink();
      final receipt = rewards.first;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _RewardCard(
              key: ValueKey(
                '${habitat.session.session?.userId}:${receipt['id']}',
              ),
              habitat: habitat,
              sprites: sprites,
              receipt: receipt,
              remaining: rewards.length,
              onInventory: onInventory,
            ),
          ),
        ),
      );
    },
  );
}

class _RewardCard extends StatefulWidget {
  const _RewardCard({
    super.key,
    required this.habitat,
    required this.sprites,
    required this.receipt,
    required this.remaining,
    required this.onInventory,
  });
  final HabitatService habitat;
  final HabitatSprites sprites;
  final Map<String, dynamic> receipt;
  final int remaining;
  final VoidCallback onInventory;
  @override
  State<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<_RewardCard> {
  Timer? _delay;
  bool _visible = false, _sending = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    // Let the confirmed action finish its short effect before showing the prize.
    _delay = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  Future<void> _acknowledge({bool inventory = false}) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final openInventory = widget.onInventory;
    final habitat = widget.habitat;
    final owner = habitat.session.session?.userId;
    try {
      await habitat.acknowledgeProductionReward(
        widget.receipt['id'].toString(),
      );
      // The successful response removes this card from the queue.
      if (inventory && owner == habitat.session.session?.userId) {
        openInventory();
      }
    } on ProductApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final receipt = widget.receipt;
    final bonuses = receipt['bonuses'] as List? ?? const [];
    final items = receipt['items'] as List? ?? const [];
    final catName = widget.habitat.cats
        .where((c) => c.id == receipt['cat_id'])
        .firstOrNull
        ?.name;
    final connected =
        widget.habitat.session.isSignedIn && !widget.habitat.offline;
    final enabled =
        connected &&
        !_sending &&
        !widget.habitat.productionBusy &&
        !widget.habitat.caring;
    return Semantics(
      liveRegion: true,
      container: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 352,
          maxHeight: MediaQuery.sizeOf(context).height * .68,
        ),
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFC6AE8E), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: QuintalArtwork('ready', size: 48)),
                      Text(
                        receipt['title']?.toString() ?? 'Conquista no Quintal',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textTitle,
                        ),
                      ),
                      if (receipt['kind'] == 'bond')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${catName ?? 'Seu gato'} · ${receipt['threshold']} pontos de vínculo',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      for (final bonus in bonuses) ...[
                        const SizedBox(height: 14),
                        Text(
                          bonus['type'] == 'achievement'
                              ? 'Medalha conquistada'
                              : 'Missão concluída',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMedium,
                          ),
                        ),
                        Text(
                          bonus['title'].toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            if ((bonus['xp'] as num? ?? 0) > 0)
                              Text(
                                '+${bonus['xp']} XP',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if ((bonus['coins'] as num? ?? 0) > 0)
                              Text(
                                '+${bonus['coins']} moedas',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ],
                      for (final item in items) ...[
                        const SizedBox(height: 12),
                        _item(item as Map),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        items.isEmpty
                            ? 'Recompensas já adicionadas à sua conta.'
                            : 'Itens recebidos em Inventário · Decorações.',
                        textAlign: TextAlign.center,
                      ),
                      if (widget.remaining > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${widget.remaining - 1} ${widget.remaining == 2 ? 'outra conquista' : 'outras conquistas'} para ver',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!connected)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Conecte-se para confirmar a leitura. Seus prêmios já foram recebidos.',
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.textTitle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: enabled ? () => _acknowledge() : null,
                      child: Text(
                        _sending
                            ? 'Confirmando…'
                            : _error == null
                            ? 'Continuar'
                            : 'Tentar novamente',
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: enabled
                            ? () => _acknowledge(inventory: true)
                            : null,
                        child: const Text('Ver no inventário'),
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

  Widget _item(Map item) {
    final definition = HabitatService.catalogItem(
      item['sku']?.toString() ?? '',
    );
    return Row(
      children: [
        if (definition != null) ...[
          HabitatSpritePreview(
            sprites: widget.sprites,
            keyName: widget.sprites.keyFor(definition.displaySprite, 0),
            size: 64,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            '${item['quantity'] ?? 1} × ${item['name'] ?? definition?.name ?? 'Decoração'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
