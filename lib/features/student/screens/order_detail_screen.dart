import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';
import 'dispute_form_screen.dart';

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
    final scheme = Theme.of(context).colorScheme;
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
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Order #${o.orderId.substring(0, 8).toUpperCase()}',
                                style: AppTextStyles.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(Formatters.dateTime(o.createdAt),
                                style: AppTextStyles.bodySmall),
                            if (o.vendorName != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Row(children: [
                                Icon(AppIcons.storefront, size: 14),
                                const SizedBox(width: AppSpacing.xs),
                                Text(o.vendorName!,
                                    style: AppTextStyles.bodyMedium),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      StatusPill(
                          label: o.status.label,
                          color: orderStatusColor(o.status, context),
                          icon: orderStatusIcon(o.status)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Timeline (hidden when cancelled)
                if (o.status == OrderStatus.cancelled)
                  AppCard(
                    color: AppColors.errorContainer,
                    shadows: const [],
                    child: Row(
                      children: [
                        Icon(AppIcons.cancelFill, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm + 4),
                        Text('This order was cancelled',
                            style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.onErrorContainer)),
                      ],
                    ),
                  )
                else
                  _Timeline(order: o),

                const SizedBox(height: AppSpacing.md),
                Text('Items', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  child: Column(
                    children: [
                      ...o.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs + 2),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.brSm,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: AppNetworkImage(
                                    url: it.productImage,
                                    fallbackIcon: AppIcons.image,
                                    iconSize: 20),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(it.productName ?? 'Item',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleSmall),
                                  Text(
                                      '${it.quantity} × ${Formatters.money(it.unitPrice)}',
                                      style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                            Text(Formatters.money(it.lineTotal),
                                style: AppTextStyles.titleSmall),
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

                const SizedBox(height: AppSpacing.md),
                Text('Delivery & payment', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(context, AppIcons.mapPin, 'Address',
                          o.deliveryAddress ?? '—'),
                      _infoRow(context, AppIcons.phone, 'Phone',
                          o.contactPhone ?? '—'),
                      _paymentRow(context, o),
                      if (o.paymentMethod == 'momo' &&
                          o.vendorMomoNumber != null)
                        _infoRow(
                            context,
                            AppIcons.wallet,
                            'Paid to',
                            '${o.vendorMomoNumber}'
                                '${o.vendorMomoNetwork != null ? ' (${o.vendorMomoNetwork})' : ''}'),
                      if (o.note != null && o.note!.isNotEmpty)
                        _infoRow(context, AppIcons.note, 'Note', o.note!),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _BuyerActions(order: o),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm + 4),
          SizedBox(
              width: 70,
              child: Text(label, style: AppTextStyles.bodySmall)),
          Expanded(
              child: Text(value, style: AppTextStyles.titleSmall)),
        ],
      ),
    );
  }

  /// Payment row with a method label and a Paid/Pending pill.
  Widget _paymentRow(BuildContext context, AppOrder o) {
    final scheme = Theme.of(context).colorScheme;
    final isCod =
        o.paymentMethod == 'cash_on_delivery' || o.paymentMethod == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.wallet, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm + 4),
          SizedBox(
              width: 70,
              child: Text('Payment', style: AppTextStyles.bodySmall)),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(o.paymentMethodLabel, style: AppTextStyles.titleSmall),
                if (!isCod)
                  StatusPill(
                    label: o.isPaid ? 'Paid' : 'Pending',
                    color: o.isPaid ? AppColors.success : AppColors.warning,
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
      case OrderStatus.disputed:
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

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
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
          const SizedBox(width: AppSpacing.sm + 6),
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
                        style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Buyer escrow actions: Confirm Receipt (when delivered) and Raise a Dispute
/// (while the order is active or recently completed).
class _BuyerActions extends ConsumerWidget {
  final AppOrder order;
  const _BuyerActions({required this.order});

  bool get _canConfirm => order.status == OrderStatus.delivered;

  bool get _canDispute =>
      order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.dispatched ||
          order.status == OrderStatus.readyForPickup ||
          order.status == OrderStatus.delivered ||
          order.status == OrderStatus.completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_canConfirm && !_canDispute) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canConfirm)
          AppButton(
            label: 'Confirm Receipt',
            icon: AppIcons.checkFill,
            onPressed: () => _confirm(context, ref),
          ),
        if (_canConfirm && _canDispute) const SizedBox(height: AppSpacing.sm),
        if (_canDispute)
          AppButton(
            label: 'Raise a Dispute',
            icon: AppIcons.info,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DisputeFormScreen(orderId: order.orderId),
            )),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmActions.confirm(
      context,
      title: 'Confirm receipt?',
      message:
      'This releases your payment to the seller and completes the order. '
          'Only confirm once you have received the item.',
      confirmLabel: 'Confirm receipt',
      icon: Icons.check_circle_outline,
    );
    if (!ok) return;
    try {
      await ref
          .read(studentRepositoryProvider)
          .confirmReceipt(order.orderId);
      ref.invalidate(orderDetailProvider(order.orderId));
      ref.invalidate(myOrdersProvider);
      if (context.mounted) {
        ConfirmActions.toast(context, 'Payment released. Thank you!',
            success: true);
      }
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }
}
