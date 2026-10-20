import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'quintal_production_widgets.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({
    super.key,
    this.message = 'Preparando seu Gatálogo…',
    this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuintalArtwork('icon_app', size: 120),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (onRetry == null)
                const SizedBox(width: 200, child: LinearProgressIndicator())
              else
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
