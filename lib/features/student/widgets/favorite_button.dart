import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// A heart toggle that reflects and updates the student's favorites.
class FavoriteButton extends ConsumerWidget {
  final String productId;
  final double size;
  final Color? inactiveColor;
  const FavoriteButton({
    super.key,
    required this.productId,
    this.size = 22,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoriteIdsProvider).valueOrNull ?? {};
    final isFav = favIds.contains(productId);

    return IconButton(
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
      visualDensity: VisualDensity.compact,
      iconSize: size,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          isFav ? AppIcons.heartFill : AppIcons.heart,
          key: ValueKey(isFav),
          color: isFav
              ? AppColors.error
              : (inactiveColor ??
              Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
      onPressed: () async {
        if (ref.read(isGuestProvider)) {
          await SignInPrompt.show(context, action: 'save listings');
          return;
        }
        await ref
            .read(studentRepositoryProvider)
            .toggleFavorite(productId, !isFav);
        ref.invalidate(favoriteIdsProvider);
        ref.invalidate(favoritesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
            Text(isFav ? 'Removed from favorites' : 'Added to favorites'),
            duration: const Duration(seconds: 1),
          ));
        }
      },
    );
  }
}
