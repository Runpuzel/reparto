import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return AsyncView<List<CartItem>>(
      value: cart,
      onRetry: () => ref.invalidate(cartProvider),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart is empty',
            subtitle: 'Browse products and add them to your cart.',
            action: FilledButton.icon(
              onPressed: () => context.go('/student'),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Start shopping'),
            ),
          );
        }
        final itemCount = items.fold<int>(0, (s, i) => s + i.quantity);
        return Column(
          children: [
            // Header row with item count + clear cart.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _clearCart(context, ref, items),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CartTile(item: items[i]),
              ),
            ),
            _CheckoutBar(total: total),
          ],
        );
      },
    );
  }

  Future<void> _clearCart(
      BuildContext context, WidgetRef ref, List<CartItem> items) async {
    final ok = await ConfirmActions.confirm(
      context,
      title: 'Clear cart?',
      message: 'Remove all ${items.length} item(s) from your cart?',
      confirmLabel: 'Clear',
      icon: Icons.delete_sweep_outlined,
      destructive: true,
    );
    if (!ok) return;
    final repo = ref.read(studentRepositoryProvider);
    // Snapshot for undo.
    final snapshot = items
        .map((e) => (productId: e.productId, quantity: e.quantity))
        .toList();
    for (final item in items) {
      await repo.removeFromCart(item.cartItemId);
    }
    ref.invalidate(cartProvider);
    if (!context.mounted) return;
    final undone = await ConfirmActions.showUndo(
      context,
      message: 'Cart cleared',
      onUndo: () {},
    );
    if (undone) {
      for (final s in snapshot) {
        await repo.addToCart(s.productId, quantity: s.quantity);
      }
      ref.invalidate(cartProvider);
    }
  }
}

class _CartTile extends ConsumerWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(studentRepositoryProvider);
    final p = item.product;
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.cartItemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return ConfirmActions.confirm(
          context,
          title: 'Remove item?',
          message: 'Remove "${p?.productName ?? 'this item'}" from your cart?',
          confirmLabel: 'Remove',
          icon: Icons.remove_shopping_cart_outlined,
          destructive: true,
        );
      },
      onDismissed: (_) async {
        final snapshot = (productId: item.productId, quantity: item.quantity);
        await repo.removeFromCart(item.cartItemId);
        ref.invalidate(cartProvider);
        if (!context.mounted) return;
        final undone = await ConfirmActions.showUndo(
          context,
          message: '${p?.productName ?? 'Item'} removed',
          onUndo: () {},
        );
        if (undone) {
          await repo.addToCart(snapshot.productId, quantity: snapshot.quantity);
          ref.invalidate(cartProvider);
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  height: 64,
                  color: scheme.surfaceContainerHighest,
                  child: p?.imageUrl != null
                      ? Image.network(p!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_outlined))
                      : const Icon(Icons.fastfood_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p?.productName ?? 'Item',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    if (p?.vendorName != null) ...[
                      const SizedBox(height: 2),
                      Text(p!.vendorName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 6),
                    Text(Formatters.money(item.lineTotal),
                        style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
              ),
              _QtyStepper(
                quantity: item.quantity,
                max: p?.quantityAvailable,
                onChanged: (q) async {
                  await repo.updateCartQuantity(item.cartItemId, q);
                  ref.invalidate(cartProvider);
                },
                onRemove: () async {
                  final snapshot =
                  (productId: item.productId, quantity: item.quantity);
                  await repo.removeFromCart(item.cartItemId);
                  ref.invalidate(cartProvider);
                  if (!context.mounted) return;
                  final undone = await ConfirmActions.showUndo(
                    context,
                    message: '${p?.productName ?? 'Item'} removed',
                    onUndo: () {},
                  );
                  if (undone) {
                    await repo.addToCart(snapshot.productId,
                        quantity: snapshot.quantity);
                    ref.invalidate(cartProvider);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final int? max;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;
  const _QtyStepper({
    required this.quantity,
    required this.onChanged,
    required this.onRemove,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final atMax = max != null && quantity >= max!;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(quantity > 1
                ? Icons.remove
                : Icons.delete_outline),
            color: quantity > 1 ? null : scheme.error,
            onPressed: () => quantity > 1 ? onChanged(quantity - 1) : onRemove(),
          ),
          Text('$quantity',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(Icons.add),
            onPressed: atMax ? null : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  final double total;
  const _CheckoutBar({required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.bodySmall),
                  Text(Formatters.money(total),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 190,
                child: FilledButton.icon(
                  onPressed: () => context.push('/student/checkout'),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
