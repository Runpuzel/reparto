import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'app_skeleton.dart';

/// Cached network image with a shimmer placeholder and a graceful icon
/// fallback. Used for product photos, shop logos and order thumbnails so image
/// loading looks consistent everywhere.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallbackIcon,
    this.iconSize = 40,
  });

  final String? url;
  final BoxFit fit;
  final IconData? fallbackIcon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = fallbackIcon ?? AppIcons.image;

    if (url == null || url!.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: scheme.onSurfaceVariant),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      placeholder: (_, __) => const AppShimmer(
        child: SizedBox.expand(child: SkeletonBox(radius: 0)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
