import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'quintal_production_widgets.dart';

/// A single visible entry point to the existing composer in either feed.
class SocialPublishButton extends StatelessWidget {
  const SocialPublishButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    tooltip: 'Criar publicação',
    onPressed: onPressed,
    backgroundColor: AppColors.greenButton,
    foregroundColor: const Color(0xFFFFFAE9),
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Color(0xFFC9DEA1), width: 2),
    ),
    icon: const QuintalArtwork('action_rename', size: 28),
    label: const Text(
      'Publicar',
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}
