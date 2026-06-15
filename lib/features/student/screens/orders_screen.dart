import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';

/// Student order history with All / Active / Delivered filtering.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<AppOrder> _filter(List<AppOrder> all, int tab) {
    switch (tab) {
      case 1:
        return all.where((o) => o.status.isActive).toList();
      case 2:
        return all.where((o) => o.status.isFulfilled).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(myOrdersProvider);
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Delivered'),
          ],
        ),
        Expanded(
          child: AsyncView<List<AppOrder>>(
            value: orders,
            onRetry: () => ref.invalidate(myOrdersProvider),
            data: (list) => TabBarView(
              controller: _tabs,
              children: List.generate(3, (tab) {
                final filtered = _filter(list, tab);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myOrdersProvider),
                  child: filtered.isEmpty
                      ? ListView(children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No orders here',
                      subtitle: 'Your orders will appear in this list.',
                    ),
                  ])
                      : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final AppOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = orderStatusColor(order.status, context);
    final scheme = Theme.of(context).colorScheme;
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/student/order/${order.orderId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: scheme.surfaceContainerHighest,
                      child: firstItem?.productImage != null
                          ? Image.network(firstItem!.productImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.storefront_outlined))
                          : const Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.vendorName ?? 'Shop',
                            style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            '${order.itemCount} item(s) · ${Formatters.dateTime(order.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  StatusPill(label: order.status.label, color: color),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Formatters.money(order.totalAmount),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: scheme.primary)),
                  Row(
                    children: [
                      if (order.status == OrderStatus.pending)
                        TextButton(
                          onPressed: () => _cancel(context, ref),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      if (order.status.isFulfilled)
                        TextButton.icon(
                          onPressed: () => _reviewDialog(context, ref),
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: const Text('Rate'),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Cancel order?',
      message: 'This will cancel your order. This cannot be undone.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep',
      icon: Icons.cancel_outlined,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(studentRepositoryProvider).cancelOwnOrder(order.orderId);
      ref.invalidate(myOrdersProvider);
      if (context.mounted) {
        ConfirmActions.toast(context, 'Order cancelled');
      }
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }

  Future<void> _reviewDialog(BuildContext context, WidgetRef ref) async {
    int rating = 5;
    bool submitting = false;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rate Shop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stars: use a FittedBox so 5 tappable stars never overflow on
                // narrow dialogs.
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                            (i) => IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32),
                          onPressed: () => setState(() => rating = i + 1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed:
                submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                setState(() => submitting = true);
                try {
                  await ref.read(studentRepositoryProvider).submitReview(
                    vendorId: order.vendorId,
                    rating: rating,
                    comment: commentCtrl.text.trim().isEmpty
                        ? null
                        : commentCtrl.text.trim(),
                    orderId: order.orderId,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ConfirmActions.toast(
                        context, 'Thanks for your review!',
                        success: true);
                  }
                } catch (e) {
                  setState(() => submitting = false);
                  if (ctx.mounted) ConfirmActions.showError(ctx, e);
                }
              },
              child: submitting
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2))
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
