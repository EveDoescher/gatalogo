import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class CatCoatColorItem extends StatelessWidget {
  const CatCoatColorItem({
    super.key,
    required this.label,
    required this.percentage,
  });

  final String label;
  final String percentage;

  Color _resolveColor(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.contains('pret') || normalized.contains('black')) {
      return const Color(0xFF242424);
    }
    if (normalized.contains('branc') || normalized.contains('white')) {
      return const Color(0xFFFAF9F6);
    }
    if (normalized.contains('laranj') ||
        normalized.contains('orange') ||
        normalized.contains('ruiv') ||
        normalized.contains('red') ||
        normalized.contains('vermelh')) {
      return const Color(0xFFE27238);
    }
    if (normalized.contains('cinz') ||
        normalized.contains('gray') ||
        normalized.contains('grey') ||
        normalized.contains('azul') ||
        normalized.contains('blue')) {
      return const Color(0xFF8A939E);
    }
    if (normalized.contains('crem') ||
        normalized.contains('cream') ||
        normalized.contains('beg') ||
        normalized.contains('beige')) {
      return const Color(0xFFF3E7D3);
    }
    if (normalized.contains('marr') ||
        normalized.contains('brown') ||
        normalized.contains('chocolat')) {
      return const Color(0xFF6E4A35);
    }
    if (normalized.contains('canel') || normalized.contains('cinnamon')) {
      return const Color(0xFF9E5B32);
    }
    if (normalized.contains('fawn') || normalized.contains('fulv')) {
      return const Color(0xFFCCA98A);
    }
    if (normalized.contains('lil') ||
        normalized.contains('lilac') ||
        normalized.contains('lavend')) {
      return const Color(0xFFB5A8B2);
    }
    if (normalized.contains('dourad') ||
        normalized.contains('gold') ||
        normalized.contains('amarel') ||
        normalized.contains('yellow')) {
      return const Color(0xFFE5B548);
    }
    return const Color(0xFFB0A89F);
  }

  @override
  Widget build(BuildContext context) {
    final circleColor = _resolveColor(label);
    final isVeryLight = circleColor.computeLuminance() > 0.72;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isVeryLight
                    ? const Color(0xFFD5CDC3)
                    : Colors.black.withAlpha(20),
                width: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            percentage,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
