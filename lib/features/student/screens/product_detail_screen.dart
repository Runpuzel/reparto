import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
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
      // Undo: subtract the quantity we just added (or remove the line).
      await ref
          .read(studentRepositoryProvider)
          .decrementCartItem(p.productId, _qty);
      ref.invalidate(cartProvider);
    }
  }

  Future<void> _buyNow(Product p) async {
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
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          FavoriteButton(productId: widget.productId),
          const SizedBox(width: 4),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Product not found'));
          }
          final gallery = p.gallery;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _Gallery(
                      images: gallery,
                      controller: _pageController,
                      currentIndex: _imageIndex,
                      onChanged: (i) => setState(() => _imageIndex = i),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.categoryName != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(p.categoryName!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSecondaryContainer)),
                            ),
                          Text(p.productName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall),
                          const SizedBox(height: 10),
                          // Price + stock pill row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(Formatters.money(p.price),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (p.quantityAvailable > 0
                                      ? Colors.green
                                      : Colors.red)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      p.quantityAvailable > 0
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 15,
                                      color: p.quantityAvailable > 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      p.quantityAvailable > 0
                                          ? '${p.quantityAvailable} in stock'
                                          : 'Out of stock',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: p.quantityAvailable > 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Visit shop card
                          if (p.vendorName != null)
                            Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                onTap: () => context
                                    .push('/student/shop/${p.vendorId}'),
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  child: Icon(Icons.storefront,
                                      color: scheme.onPrimaryContainer,
                                      size: 20),
                                ),
                                title: Text(p.vendorName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: const Text('Visit shop'),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text('Description',
                              style:
                              Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                              (p.description != null &&
                                  p.description!.isNotEmpty)
                                  ? p.description!
                                  : 'No description provided.',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.5)),
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
          child: Icon(Icons.fastfood_outlined,
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
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                    child: Image.network(images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.image_outlined,
                            size: 60,
                            color: scheme.onSurfaceVariant)),
                  ),
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
              padding: const EdgeInsets.all(8),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => controller.animateToPage(i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == currentIndex
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: i == currentIndex ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_outlined)),
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
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black54),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Quantity stepper.
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : onDec,
                            icon: const Icon(Icons.remove)),
                        Text('$qty',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : onInc,
                            icon: const Icon(Icons.add)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAdd,
                      icon: busy
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                          CircularProgressIndicator(strokeWidth: 2.2))
                          : const Icon(Icons.add_shopping_cart, size: 18),
                      label: Text(
                          product.isAvailable ? 'Add to Cart' : 'Out of Stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onBuyNow,
                  icon: const Icon(Icons.flash_on),
                  label: Text(product.isAvailable ? 'Buy Now' : 'Unavailable'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
