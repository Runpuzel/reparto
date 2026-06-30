import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/student_providers.dart';
import '../widgets/product_card.dart';

/// The student's saved products for quick access.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(favoritesProvider);
        ref.invalidate(favoriteIdsProvider);
      },
      child: favorites.when(
        loading: () => const SkeletonGrid(itemCount: 6),
        error: (e, _) => ErrorState(
            message: '$e', onRetry: () => ref.invalidate(favoritesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyState(
                icon: Icons.favorite_border,
                title: 'No favorites yet',
                subtitle: 'Tap the heart on a product to save it here.',
              ),
            ]);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: AppSpacing.sm + 4,
              crossAxisSpacing: AppSpacing.sm + 4,
              childAspectRatio: 0.66,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => ProductCard(product: list[i])
                .animate()
                .fadeIn(delay: (40 * (i % 8)).ms, duration: 300.ms)
                .slideY(begin: 0.06, end: 0),
          );
        },
      ),
    );
  }
}
