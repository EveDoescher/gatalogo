import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../stores/cat_store.dart';
import '../theme/app_theme.dart';
import 'app_header_actions.dart';
import 'habitat_coin_badge.dart';
import 'quintal_production_widgets.dart';

class HabitatHud extends StatelessWidget {
  const HabitatHud({
    super.key,
    required this.store,
    required this.editing,
    required this.hasCats,
    required this.showOfflineDraft,
    required this.satisfaction,
    required this.balance,
    required this.onToggleEditing,
    required this.onHelp,
  });
  final CatStore store;
  final bool editing, hasCats, showOfflineDraft;
  final int satisfaction, balance;
  final VoidCallback onToggleEditing, onHelp;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 10, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            if (editing)
              InkWell(
                onTap: onToggleEditing,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.greenButton.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.pencil,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sair do modo edição',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            AppHeaderActions(store: store),
          ],
        ),
        const SizedBox(height: 9),
        if (hasCats && !editing)
          Tooltip(
            message: 'Conforto acessível, carinho e alimentação de hoje aumentam a satisfação e a chance de presentes.',
            child: Chip(
              avatar: const QuintalArtwork('cat_satisfaction', size: 32),
              label: Text('Satisfação $satisfaction%'),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HabitatCoinBadge(balance: balance),
            IconButton.filledTonal(
              tooltip: 'Ajuda do Quintal',
              onPressed: onHelp,
              icon: const Icon(LucideIcons.info, size: 18),
            ),
          ],
        ),
        if (showOfflineDraft)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Edições salvas neste aparelho',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textMedium,
              ),
            ),
          ),
      ],
    ),
  );
}
