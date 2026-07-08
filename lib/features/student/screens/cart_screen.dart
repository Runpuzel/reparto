import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
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

    return cart.when(
      loading: () => const SkeletonList(itemCount: 5, itemHeight: 92),
      error: (e, _) =>
          ErrorState(message: '$e', onRetry: () => ref.invalidate(cartProvider)),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart is empty',
            subtitle: 'Browse products and add them to your cart.',
            action: AppButton(
              label: 'Start shopping',
              icon: AppIcons.storefront,
              expand: false,
              onPressed: () => context.go('/student'),
            ),
          );
        }
        final itemCount = items.fold<int>(0, (s, i) => s + i.quantity);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm + 4, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                      style: AppTextStyles.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh cart',
                    onPressed: () => ref.invalidate(cartProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  TextButton.icon(
                    onPressed: () => _clearCart(context, ref, items),
                    icon: Icon(AppIcons.sweep, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm + 4, AppSpacing.sm, AppSpacing.sm + 4,
                    AppSpacing.sm + 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _CartTile(item: items[i])
                    .animate()
                    .fadeIn(delay: (18 * (i % 12)).ms, duration: 160.ms)
                    .slideX(begin: 0.04, end: 0),
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
    final snapshot = items
        .map((e) => (productId: e.productId, quantity: e.quantity))
        .toList();
    await Future.wait(
      items.map((item) => repo.removeFromCart(item.cartItemId)),
    );
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

class _CartTile extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  ConsumerState<_CartTile> createState() => _CartTileState();
}

class _CartTileState extends ConsumerState<_CartTile> {
  late int _quantity = widget.item.quantity;
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final repo = ref.read(studentRepositoryProvider);
    final p = item.product;
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.cartItemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: AppRadius.brLg,
        ),
        child: Icon(AppIcons.trash, color: Colors.white),
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
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.brMd,
              child: SizedBox(
                width: 64,
                height: 64,
                child: AppNetworkImage(
                    url: p?.imageUrl, fallbackIcon: AppIcons.image),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p?.productName ?? 'Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall
                          .copyWith(color: scheme.onSurface)),
                  if (p?.vendorName != null) ...[
                    const SizedBox(height: 2),
                    Text(p!.vendorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: scheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(Formatters.money((p?.price ?? 0) * _quantity),
                      style: AppTextStyles.titleSmall.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            _QtyStepper(
              quantity: _quantity,
              max: p?.quantityAvailable,
              busy: _updating,
              onChanged: (q) => _changeQuantity(repo, item, q),
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
    );
  }

  Future<void> _changeQuantity(
      dynamic repo, CartItem item, int quantity) async {
    if (_updating) return;
    final previous = _quantity;
    setState(() {
      _quantity = quantity;
      _updating = true;
    });
    try {
      await repo.updateCartQuantity(item.cartItemId, quantity);
      ref.invalidate(cartProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _quantity = previous);
        ConfirmActions.showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final int? max;
  final bool busy;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;
  const _QtyStepper({
    required this.quantity,
    required this.onChanged,
    required this.onRemove,
    this.busy = false,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final atMax = max != null && quantity >= max!;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(quantity > 1 ? AppIcons.minus : AppIcons.trash),
            color: quantity > 1 ? null : scheme.error,
            onPressed: busy
                ? null
                : () => quantity > 1
                    ? onChanged(quantity - 1)
                    : onRemove(),
          ),
          Text('$quantity', style: AppTextStyles.labelLarge),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: Icon(AppIcons.plus),
            onPressed:
                (atMax || busy) ? null : () => onChanged(quantity + 1),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.level2,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(Formatters.money(total),
                      style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800, color: scheme.primary)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: AppButton(
                  label: 'Checkout',
                  icon: AppIcons.bag,
                  onPressed: () => context.push('/student/checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
