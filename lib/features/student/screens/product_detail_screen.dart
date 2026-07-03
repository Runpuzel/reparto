import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/commission.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/student_providers.dart';
import '../widgets/favorite_button.dart';

final _productProvider =
FutureProvider.family<Product?, String>((ref, id) async {
  final data = await supabase
      .from('products')
      .select(
      '*, vendors(business_name), categories(category_name), product_images(image_url, position)')
      .eq('product_id', id)
      .maybeSingle();
  return data == null ? null : Product.fromMap(Map<String, dynamic>.from(data));
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _qty = 1;
  int _imageIndex = 0;
  bool _busy = false;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addToCart(Product p) async {
    if (ref.read(isGuestProvider)) {
      await SignInPrompt.show(context, action: 'use your cart');
      return;
    }
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Add to cart?',
      message: 'Add $_qty × ${p.productName} to your cart?',
      confirmLabel: 'Add',
      icon: Icons.add_shopping_cart,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(studentRepositoryProvider)
          .addToCart(p.productId, quantity: _qty);
      ref.invalidate(cartProvider);
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final undone = await ConfirmActions.showUndo(
      context,
      message: 'Added $_qty × ${p.productName} to cart',
      onUndo: () {},
    );
    if (undone) {
      await ref
          .read(studentRepositoryProvider)
          .decrementCartItem(p.productId, _qty);
      ref.invalidate(cartProvider);
    }
  }

  Future<void> _buyNow(Product p) async {
    if (ref.read(isGuestProvider)) {
      await SignInPrompt.show(context, action: 'buy items');
      return;
    }
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Buy now?',
      message:
      'Proceed to checkout with $_qty × ${p.productName}? This adds it to your cart.',
      confirmLabel: 'Continue',
      icon: Icons.flash_on,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(studentRepositoryProvider)
          .addToCart(p.productId, quantity: _qty);
      ref.invalidate(cartProvider);
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    context.push('/student/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_productProvider(widget.productId));
    final scheme = Theme.of(context).colorScheme;
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          IconButton(
            tooltip: 'View cart',
            onPressed: () => context.push('/student/checkout'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: Icon(AppIcons.cart),
            ),
          ),
          FavoriteButton(productId: widget.productId),
          const SizedBox(width: 4),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_productProvider(widget.productId)),
        ),
        data: (p) {
          if (p == null) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Product not found',
            );
          }
          final gallery = p.gallery;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Hero(
                      tag: 'product-image-${p.productId}',
                      child: _Gallery(
                        images: gallery,
                        controller: _pageController,
                        currentIndex: _imageIndex,
                        onChanged: (i) => setState(() => _imageIndex = i),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.categoryName != null)
                            Container(
                              margin: const EdgeInsets.only(
                                  bottom: AppSpacing.sm + 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: AppRadius.brFull,
                              ),
                              child: Text(p.categoryName!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 12,
                                      color: scheme.onSecondaryContainer)),
                            ),
                          Text(p.productName,
                              style: AppTextStyles.headlineSmall
                                  .copyWith(color: scheme.onSurface)),
                          const SizedBox(height: AppSpacing.sm + 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(Formatters.money(p.price),
                                  style: AppTextStyles.headlineMedium.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800)),
                              const Spacer(),
                              _StockPill(
                                  inStock: p.quantityAvailable > 0,
                                  quantity: p.quantityAvailable),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (p.vendorName != null)
                            AppCard(
                              onTap: () =>
                                  context.push('/student/shop/${p.vendorId}'),
                              padding: const EdgeInsets.all(AppSpacing.sm + 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: scheme.primaryContainer,
                                    child: Icon(AppIcons.storefrontFill,
                                        color: scheme.onPrimaryContainer,
                                        size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(p.vendorName!,
                                            style: AppTextStyles.titleSmall
                                                .copyWith(
                                                color: scheme.onSurface)),
                                        Text('Visit shop',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                color: scheme
                                                    .onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  Icon(AppIcons.caretRight,
                                      size: 18,
                                      color: scheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Description',
                              style: AppTextStyles.titleMedium
                                  .copyWith(color: scheme.onSurface)),
                          const SizedBox(height: AppSpacing.xs + 2),
                          Text(
                              (p.description != null &&
                                  p.description!.isNotEmpty)
                                  ? p.description!
                                  : 'No description provided.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: scheme.onSurfaceVariant)),
                          const SizedBox(height: AppSpacing.lg),
                          _PlatformFee(pricePesewas: p.pricePesewas),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _AddBar(
                product: p,
                qty: _qty,
                busy: _busy,
                onDec: _qty > 1 ? () => setState(() => _qty--) : null,
                onInc: _qty < p.quantityAvailable
                    ? () => setState(() => _qty++)
                    : null,
                onAdd: (p.isAvailable && !_busy) ? () => _addToCart(p) : null,
                onBuyNow: (p.isAvailable && !_busy) ? () => _buyNow(p) : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  final bool inStock;
  final int quantity;
  const _StockPill({required this.inStock, required this.quantity});

  @override
  Widget build(BuildContext context) {
    final container =
    inStock ? AppColors.successContainer : AppColors.errorContainer;
    final fg = inStock ? AppColors.onSuccessContainer : AppColors.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: container,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(inStock ? AppIcons.checkFill : AppIcons.cancelFill,
              size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            inStock ? '$quantity in stock' : 'Out of stock',
            style: AppTextStyles.labelSmall
                .copyWith(fontSize: 12.5, color: fg),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  const _Gallery({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(AppIcons.image,
              size: 60, color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: images.length,
                onPageChanged: onChanged,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openFullscreen(context, images, i),
                  child: AppNetworkImage(
                      url: images[i], fallbackIcon: AppIcons.image),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == currentIndex ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == currentIndex
                              ? scheme.primary
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => controller.animateToPage(i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.brSm,
                    border: Border.all(
                      color: i == currentIndex
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: i == currentIndex ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppNetworkImage(
                      url: images[i], fallbackIcon: AppIcons.image),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openFullscreen(BuildContext context, List<String> imgs, int start) {
    showDialog(
      context: context,
      builder: (ctx) {
        final pc = PageController(initialPage: start);
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: pc,
                itemCount: imgs.length,
                itemBuilder: (_, i) => InteractiveViewer(
                  child: Center(
                    child: Image.network(imgs[i],
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white)),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddBar extends StatelessWidget {
  final Product product;
  final int qty;
  final bool busy;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final VoidCallback? onAdd;
  final VoidCallback? onBuyNow;
  const _AddBar({
    required this.product,
    required this.qty,
    required this.busy,
    required this.onDec,
    required this.onInc,
    required this.onAdd,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      const SizedBox(width: 10),
                      Text('Adding to cart, please wait…',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: AppRadius.brMd,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : onDec,
                            icon: Icon(AppIcons.minus)),
                        Text('$qty',
                            style: AppTextStyles.titleMedium),
                        IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : onInc,
                            icon: Icon(AppIcons.plus)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: AppButton(
                      label:
                      product.isAvailable ? 'Add to Cart' : 'Out of Stock',
                      icon: AppIcons.addToCart,
                      variant: AppButtonVariant.secondary,
                      loading: busy,
                      onPressed: onAdd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              AppButton(
                label: product.isAvailable ? 'Buy Now' : 'Unavailable',
                icon: AppIcons.flash,
                onPressed: onBuyNow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Transparent platform-fee row shown on the product detail (spec C1).
class _PlatformFee extends ConsumerWidget {
  final int pricePesewas;
  const _PlatformFee({required this.pricePesewas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tiers =
        ref.watch(commissionTiersProvider).valueOrNull ?? Commission.defaults;
    final campusId = ref.watch(currentUserProvider).valueOrNull?.campusId;
    final fee =
    Commission.forPrice(pricePesewas, campusId: campusId, tiers: tiers);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.info, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text('Platform fee',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: scheme.onSurface)),
              const Spacer(),
              Text(Money.format(fee),
                  style: AppTextStyles.titleSmall
                      .copyWith(color: scheme.onSurface)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This fee is included in the total and goes toward running the '
                'marketplace.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
