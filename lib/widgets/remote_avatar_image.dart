import 'package:flutter/material.dart';

import '../config/api_config.dart';

/// Shared remote portrait loading; callers keep their own frames and fallbacks.
class RemoteAvatarImage extends StatelessWidget {
  const RemoteAvatarImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.centerFallback = false,
  });

  final String? url;
  final Widget fallback;
  final double? width, height;
  final bool centerFallback;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) {
      return centerFallback ? Center(child: fallback) : fallback;
    }
    return Image.network(
      source.startsWith('http') ? source : '${ApiConfig.baseUrl}$source',
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
