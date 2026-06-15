import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';

/// Full order details with a visual status timeline:
/// Placed → Confirmed → Dispatched → Delivered.
class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _flow = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.dispatched,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: AsyncView<AppOrder?>(
        value: order,
        onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        data: (o) {
          if (o == null) {
            return const EmptyState(
                icon: Icons.receipt_long_outlined, title: 'Order not found');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderDetailProvider(orderId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order #${o.orderId.substring(0, 8).toUpperCase()}',
                                  style:
                                  Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(Formatters.dateTime(o.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (o.vendorName != null) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.storefront_outlined,
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Text(o.vendorName!),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        StatusPill(
                            label: o.status.label,
                            color: orderStatusColor(o.status, context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Timeline (hidden when cancelled)
                if (o.status == OrderStatus.cancelled)
                  Card(
                    color: Colors.red.withValues(alpha: 0.08),
                    child: const ListTile(
                      leading: Icon(Icons.cancel_outlined, color: Colors.red),
                      title: Text('This order was cancelled'),
                    ),
                  )
                else
                  _Timeline(order: o),

                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...o.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: it.productImage != null
                                      ? Image.network(it.productImage!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                      const Icon(
                                          Icons.image_outlined))
                                      : const Icon(Icons.fastfood_outlined),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(it.productName ?? 'Item',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${it.quantity} × ${Formatters.money(it.unitPrice)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                              ),
                              Text(Formatters.money(it.lineTotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                        const Divider(height: 20),
                        _kv(context, 'Items', '${o.itemCount}'),
                        _kv(context, 'Total', Formatters.money(o.totalAmount),
                            bold: true),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text('Delivery & payment',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(context, Icons.location_on_outlined,
                            'Address', o.deliveryAddress ?? '—'),
                        _infoRow(context, Icons.phone_outlined, 'Phone',
                            o.contactPhone ?? '—'),
                        _paymentRow(context, o),
                        if (o.note != null && o.note!.isNotEmpty)
                          _infoRow(context, Icons.sticky_note_2_outlined,
                              'Note', o.note!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                  color: bold ? Theme.of(context).colorScheme.primary : null)),
        ],
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
              width: 70,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  /// Payment row with a method label and a Paid/Pending pill.
  Widget _paymentRow(BuildContext context, AppOrder o) {
    final scheme = Theme.of(context).colorScheme;
    final isCod = o.paymentMethod == 'cash_on_delivery' || o.paymentMethod == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payment_outlined,
              size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
              width: 70,
              child:
              Text('Payment', style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(o.paymentMethodLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (!isCod)
                  StatusPill(
                    label: o.isPaid ? 'Paid' : 'Pending',
                    color: o.isPaid ? Colors.green : Colors.orange,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final AppOrder order;
  const _Timeline({required this.order});

  int get _activeIndex {
    switch (order.status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return 1;
      case OrderStatus.dispatched:
      case OrderStatus.readyForPickup:
        return 2;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return 3;
      case OrderStatus.cancelled:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      (OrderStatus.pending, 'Order Placed', order.createdAt),
      (OrderStatus.confirmed, 'Confirmed', order.confirmedAt),
      (OrderStatus.dispatched, 'Dispatched', order.dispatchedAt),
      (OrderStatus.delivered, 'Delivered', order.deliveredAt),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              _step(
                context,
                icon: orderStatusIcon(steps[i].$1),
                label: steps[i].$2,
                time: steps[i].$3,
                done: i <= _activeIndex,
                active: i == _activeIndex,
                isLast: i == steps.length - 1,
                scheme: scheme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _step(
      BuildContext context, {
        required IconData icon,
        required String label,
        required DateTime? time,
        required bool done,
        required bool active,
        required bool isLast,
        required ColorScheme scheme,
      }) {
    final color = done ? scheme.primary : scheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
                child: Icon(icon,
                    size: 18,
                    color: done ? Colors.white : scheme.onSurfaceVariant),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2.5, color: color),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight:
                          active ? FontWeight.w800 : FontWeight.w600,
                          color: done ? null : scheme.onSurfaceVariant)),
                  if (time != null)
                    Text(Formatters.dateTime(time),
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
