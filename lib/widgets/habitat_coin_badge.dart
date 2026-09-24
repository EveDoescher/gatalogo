import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class HabitatCoinBadge extends StatelessWidget {
  const HabitatCoinBadge({super.key, required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.achievementBg,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/3d_assets/kenney_mini-dungeon/Previews/coin.png',
          width: 20,
          height: 20,
        ),
        const SizedBox(width: 6),
        Text(
          '$balance',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AppColors.achievementText,
          ),
        ),
      ],
    ),
  );
}
