import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';
import 'favorite_button.dart';

/// Reusable product grid card used on Browse and Shop pages.
class ProductCard extends ConsumerWidget {
  final Product product;
  final bool showVendor;
  const ProductCard({super.key, required this.product, this.showVendor = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cover = product.gallery.isNotEmpty ? product.gallery.first : null;
    final hasMany = product.gallery.length > 1;

    return Card(
      child: InkWell(
        onTap: () => context.push('/student/product/${product.productId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: scheme.surfaceContainerHighest,
                    child: cover != null
                        ? Image.network(cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(scheme))
                        : _placeholder(scheme),
                  ),
                  // Multi-photo indicator.
                  if (hasMany)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.collections,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('${product.gallery.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  // Favorite heart.
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: FavoriteButton(
                          productId: product.productId,
                          size: 18,
                          inactiveColor: Colors.white),
                    ),
                  ),
                  // Add-to-cart button.
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _addToCart(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.add_shopping_cart,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (showVendor && product.vendorName != null) ...[
                    const SizedBox(height: 2),
                    Text(product.vendorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 8),
                  Text(Formatters.money(product.price),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: scheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(studentRepositoryProvider);
    await repo.addToCart(product.productId);
    ref.invalidate(cartProvider);
    if (!context.mounted) return;
    final undone = await ConfirmActions.showUndo(
      context,
      message: '${product.productName} added to cart',
      onUndo: () {},
    );
    if (undone) {
      await repo.decrementCartItem(product.productId, 1);
      ref.invalidate(cartProvider);
    }
  }

  Widget _placeholder(ColorScheme scheme) => Center(
    child: Icon(Icons.image_outlined,
        size: 40, color: scheme.onSurfaceVariant),
  );
}
