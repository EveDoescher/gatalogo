import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One result hierarchy for both activities, populated only after confirmation.
class QuintalActivityResult extends StatelessWidget {
  const QuintalActivityResult({
    super.key,
    required this.success,
    required this.title,
    required this.description,
    required this.artwork,
    required this.onClose,
  });
  final bool success;
  final String title, description;
  final Widget artwork;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(child: SizedBox(width: 160, height: 160, child: artwork)),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: success
                  ? const Color(0xffedf3cf)
                  : const Color(0xfff4e5cb),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: success ? AppColors.greenLink : const Color(0xff926b46),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onClose,
          child: const Text('Voltar ao Quintal'),
        ),
      ],
    ),
  );
}
