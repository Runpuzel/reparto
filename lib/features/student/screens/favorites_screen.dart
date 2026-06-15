import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
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
      child: AsyncView<List<Product>>(
        value: favorites,
        onRetry: () => ref.invalidate(favoritesProvider),
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
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => ProductCard(product: list[i]),
          );
        },
      ),
    );
  }
}
