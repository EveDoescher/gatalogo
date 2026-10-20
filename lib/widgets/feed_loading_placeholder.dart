import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FeedLoadingPlaceholder extends StatelessWidget {
  const FeedLoadingPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando mais itens',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            color: AppColors.cardBackground,
                          ),
                          const SizedBox(height: 10),
                          FractionallySizedBox(
                            widthFactor: .65,
                            child: Container(
                              height: 10,
                              color: AppColors.cardBackground,
                            ),
                          ),
                        ],
                      ),
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
