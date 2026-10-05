import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'botanical_scene.dart';
import 'illustrated_home_components.dart';

/// Feed presentation has no API or optimistic-state logic.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.author,
    required this.when,
    required this.note,
    required this.media,
    required this.liked,
    required this.likes,
    required this.comments,
    required this.onAuthor,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.avatarUrl,
    this.location,
    this.contextualAction,
  });
  final String author, when, note;
  final String? avatarUrl, location;
  final Widget media;
  final Widget? contextualAction;
  final bool liked;
  final int likes, comments;
  final VoidCallback onAuthor, onLike, onComment, onShare;
  @override
  Widget build(BuildContext context) => BotanicalPaper(
    padding: const EdgeInsets.fromLTRB(10, 10, 16, 9),
    child: LayoutBuilder(
      builder: (context, box) {
        final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final header = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onAuthor,
              borderRadius: BorderRadius.circular(28),
              child: FramedUserAvatar(url: avatarUrl, size: 48),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author,
                    style: HomeArt.title(16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      when,
                      if (location?.isNotEmpty == true) location!,
                    ].where((v) => v.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções da publicação',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz, color: AppColors.textMedium),
              onSelected: (value) =>
                  value == 'profile' ? onAuthor() : onShare(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('Ver perfil')),
                PopupMenuItem(value: 'share', child: Text('Compartilhar')),
              ],
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Padding(
              padding: EdgeInsets.only(left: large ? 0 : 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?contextualAction,
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        note,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(height: 1.35, fontSize: 15),
                      ),
                    ),
                  media,
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PostAction(
                        label: liked ? 'Descurtir' : 'Curtir',
                        count: likes,
                        onTap: onLike,
                        icon: liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: const Color(0xFFF17886),
                      ),
                      _PostAction(
                        label: 'Comentar',
                        count: comments,
                        onTap: onComment,
                        icon: LucideIcons.messageCircle,
                      ),
                      IconButton(
                        tooltip: 'Compartilhar',
                        onPressed: onShare,
                        icon: const Icon(
                          LucideIcons.share2,
                          color: AppColors.textMedium,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.label,
    required this.count,
    required this.onTap,
    required this.icon,
    this.color = AppColors.textMedium,
  });
  final String label;
  final int count;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $count',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 5),
            Text('$count', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    ),
  );
}
