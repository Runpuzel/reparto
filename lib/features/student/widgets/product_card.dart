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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stockColor = isDark
        ? Color.lerp(scheme.primary, Colors.white, 0.34)!
        : const Color(0xFF1B873F);
    final cover = product.gallery.isNotEmpty ? product.gallery.first : null;
    final hasMany = product.gallery.length > 1;
    final currentVendor = ref.watch(currentVendorProvider).valueOrNull;
    final isOwnProduct = currentVendor?.vendorId == product.vendorId;

    return AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: AppRadius.brLg,
          boxShadow: _pressed ? AppShadows.level2 : AppShadows.level1,
        ),
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
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.82),
                ),
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
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(
                                    alpha: isDark ? 0.28 : 0.34,
                                  ),
                                ],
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Multi-photo indicator.
                        if (hasMany)
                          Positioned(
                            left: AppSpacing.sm,
                            top: AppSpacing.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: AppRadius.brFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.images,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${product.gallery.length}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Favorite heart.
                        if (!isOwnProduct)
                          Positioned(
                            right: AppSpacing.xs,
                            top: AppSpacing.xs,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.38),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: FavoriteButton(
                                productId: product.productId,
                                size: 18,
                                inactiveColor: Colors.white,
                              ),
                            ),
                          ),
                        // Add-to-cart button.
                        Positioned(
                          right: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: Tooltip(
                            message: 'Add to cart',
                            child: Material(
                              color: scheme.primary,
                              borderRadius: AppRadius.brFull,
                              elevation: 2,
                              shadowColor: scheme.primary.withValues(
                                alpha: 0.4,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius: AppRadius.brFull,
                                onTap: () => _addToCart(context, ref),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    AppIcons.addToCart,
                                    size: 19,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm + 4,
                      AppSpacing.sm + 4,
                      AppSpacing.sm + 4,
                      AppSpacing.sm + 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1.25,
                          ),
                        ),
                        if (widget.showVendor &&
                            product.vendorName != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                AppIcons.storefront,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  product.vendorName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm + 2),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.money(product.price),
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: product.isAvailable
                                    ? stockColor
                                    : scheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
