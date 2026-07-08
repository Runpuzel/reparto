import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';
import 'favorite_button.dart';

/// Reusable product grid card used on Browse, Favorites and Shop pages.
class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final bool showVendor;
  const ProductCard({super.key, required this.product, this.showVendor = true});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final cover = product.gallery.isNotEmpty ? product.gallery.first : null;
    final hasMany = product.gallery.length > 1;
    final currentVendor = ref.watch(currentVendorProvider).valueOrNull;
    final isOwnProduct = currentVendor?.vendorId == product.vendorId;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/student/product/${product.productId}'),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: AppRadius.brLg,
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: AppShadows.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'product-image-${product.productId}',
                        child: AppNetworkImage(
                          url: cover,
                          fallbackIcon: AppIcons.image,
                        ),
                      ),
                      // Multi-photo indicator.
                      if (hasMany)
                        Positioned(
                          left: AppSpacing.sm,
                          top: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: AppRadius.brFull,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.images,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 3),
                                Text('${product.gallery.length}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      // Favorite heart.
                      if (!isOwnProduct)
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
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: Material(
                          color: scheme.primary,
                          borderRadius: AppRadius.brMd,
                          elevation: 2,
                          shadowColor: scheme.primary.withValues(alpha: 0.4),
                          child: InkWell(
                            borderRadius: AppRadius.brMd,
                            onTap: () => _addToCart(context, ref),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Icon(AppIcons.addToCart,
                                  size: 19, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm + 4, 10, AppSpacing.sm + 4, AppSpacing.sm + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1)),
                      if (widget.showVendor && product.vendorName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(AppIcons.storefront,
                                size: 12, color: scheme.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(product.vendorName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(Formatters.money(product.price),
                          style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: scheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    if (ref.read(isGuestProvider)) {
      await SignInPrompt.show(context, action: 'use your cart');
      return;
    }
    final product = widget.product;
    if (ref.read(currentVendorProvider).valueOrNull?.vendorId ==
        product.vendorId) {
      ConfirmActions.showError(context, 'You cannot buy your own product.');
      return;
    }
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
}
