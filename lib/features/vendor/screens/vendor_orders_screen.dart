import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/product_image_viewer.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/vendor_providers.dart';

/// Allowed forward transitions per the UjustBUY delivery lifecycle:
///   Placed → Confirmed → Dispatched → Delivered  (cancel while early)
const _nextStatuses = <OrderStatus, List<OrderStatus>>{
  OrderStatus.pending: [OrderStatus.confirmed, OrderStatus.cancelled],
  OrderStatus.confirmed: [OrderStatus.dispatched, OrderStatus.cancelled],
  OrderStatus.dispatched: [OrderStatus.delivered],
  // legacy support
  OrderStatus.accepted: [OrderStatus.dispatched, OrderStatus.cancelled],
  OrderStatus.preparing: [OrderStatus.dispatched],
  OrderStatus.readyForPickup: [OrderStatus.delivered],
};

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  static const _filters = [
    ('All', null),
    ('Pending', OrderStatus.pending),
    ('Confirmed', OrderStatus.confirmed),
    ('Dispatched', OrderStatus.dispatched),
    ('Delivered', OrderStatus.delivered),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<AppOrder> _filter(List<AppOrder> all, OrderStatus? status) {
    if (status == null) return all;
    if (status == OrderStatus.delivered) {
      return all.where((o) => o.status.isFulfilled).toList();
    }
    return all.where((o) => o.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(vendorOrdersProvider);
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _filters.map((f) => Tab(text: f.$1)).toList(),
        ),
        Expanded(
          child: orders.when(
            loading: () => const SkeletonList(itemCount: 5, itemHeight: 96),
            error: (e, _) => ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(vendorOrdersProvider)),
            data: (list) => TabBarView(
              controller: _tabs,
              children: _filters.map((f) {
                final filtered = _filter(list, f.$2);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(vendorOrdersProvider),
                  child: filtered.isEmpty
                      ? ListView(children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No orders here',
                      subtitle: 'Incoming orders will appear here.',
                    ),
                  ])
                      : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) =>
                        _VendorOrderCard(order: filtered[i])
                            .animate()
                            .fadeIn(
                            delay: (40 * (i % 12)).ms,
                            duration: 280.ms)
                            .slideY(begin: 0.05, end: 0),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _VendorOrderCard extends ConsumerWidget {
  final AppOrder order;
  const _VendorOrderCard({required this.order});

  String get _shortId => order.orderId.length >= 8
      ? order.orderId.substring(0, 8).toUpperCase()
      : order.orderId.toUpperCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = orderStatusColor(order.status, context);
    final next = (_nextStatuses[order.status] ?? [])
        .where((status) =>
            status != OrderStatus.cancelled ||
            !(order.isPaid && order.paymentMethod != 'cash_on_delivery'))
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final feeRate = ref.watch(vendorPlatformSettingsProvider).valueOrNull
            ?.platformFeeSellerPercent ??
        5.0;
    final marketplaceFee = order.totalAmount * feeRate / 100;
    final sellerPayout = order.totalAmount - marketplaceFee;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(orderStatusIcon(order.status), color: color, size: 20),
          ),
          title: Text(order.studentName ?? 'Customer',
              style: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface)),
          subtitle: Text(
              '#$_shortId · ${order.itemCount} item(s) · ${Formatters.dateTime(order.createdAt)}',
              style: AppTextStyles.bodySmall),
          trailing: StatusPill(label: order.status.label, color: color),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 4),
          children: [
            // ---- WHAT to prepare ------------------------------------------
            _sectionLabel(context, 'Items to prepare'),
            ...order.items.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  OrderProductThumbnail(
                    imageUrl: it.productImage,
                    productName: it.productName ?? 'Item',
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text('×${it.quantity}',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: scheme.primary)),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                      child: Text(it.productName ?? 'Item',
                          style: AppTextStyles.bodyMedium)),
                  Text(Formatters.money(it.lineTotal),
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            )),

            const Divider(height: 22),

            // ---- WHO + WHERE ----------------------------------------------
            _sectionLabel(context, 'Customer & delivery'),
            _detailRow(
              context,
              icon: AppIcons.user,
              label: 'Name',
              value: order.studentName ?? 'Customer',
            ),
            if (_has(order.contactPhone))
              _detailRow(
                context,
                icon: AppIcons.phone,
                label: 'Phone',
                value: order.contactPhone!,
                actions: [
                  _MiniAction(
                    icon: AppIcons.call,
                    tooltip: 'Call',
                    onTap: () => _launch(context, 'tel:${order.contactPhone}'),
                  ),
                  _MiniAction(
                    icon: AppIcons.sms,
                    tooltip: 'Text',
                    onTap: () => _launch(context, 'sms:${order.contactPhone}'),
                  ),
                  _MiniAction(
                    icon: AppIcons.copy,
                    tooltip: 'Copy',
                    onTap: () => _copy(context, order.contactPhone!, 'Phone'),
                  ),
                ],
              ),
            if (_has(order.deliveryAddress))
              _detailRow(
                context,
                icon: AppIcons.mapPin,
                label: 'Address',
                value: order.deliveryAddress!,
                actions: [
                  _MiniAction(
                    icon: AppIcons.map,
                    tooltip: 'Open in Maps',
                    onTap: () => _launch(
                      context,
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order.deliveryAddress!)}',
                    ),
                  ),
                  _MiniAction(
                    icon: AppIcons.copy,
                    tooltip: 'Copy',
                    onTap: () =>
                        _copy(context, order.deliveryAddress!, 'Address'),
                  ),
                ],
              ),
            if (_has(order.note))
              _detailRow(
                context,
                icon: AppIcons.note,
                label: 'Note',
                value: order.note!,
                highlight: true,
              ),

            const Divider(height: 22),

            // ---- HOW they pay ---------------------------------------------
            _sectionLabel(context, 'Payment'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(AppIcons.wallet,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(order.paymentMethodLabel,
                        style: AppTextStyles.titleSmall),
                  ),
                  _PaymentBadge(order: order),
                ],
              ),
            ),
            if (order.paymentMethod == 'momo' && order.vendorMomoNumber != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(
                  'Paid to your MoMo: ${order.vendorMomoNumber}'
                      '${order.vendorMomoNetwork != null ? ' (${order.vendorMomoNetwork})' : ''}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order total', style: AppTextStyles.titleSmall),
                Text(Formatters.money(order.totalAmount),
                    style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800, color: scheme.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _moneyRow('Marketplace fee (${feeRate.toStringAsFixed(1)}%)',
                marketplaceFee),
            _moneyRow('Expected seller payout', sellerPayout, strong: true),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/order/${order.orderId}/chat'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Message buyer'),
              ),
            ),

            // ---- Actions --------------------------------------------------
            if (next.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: next.map((s) {
                  final isCancel = s == OrderStatus.cancelled;
                  return isCancel
                      ? OutlinedButton(
                    onPressed: () => _update(context, ref, s),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 44)),
                    child: const Text('Cancel'),
                  )
                      : FilledButton.icon(
                    onPressed: () => _update(context, ref, s),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    icon: Icon(orderStatusIcon(s), size: 18),
                    label: Text('Mark ${s.label}'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _has(String? v) => v != null && v.trim().isNotEmpty;

  Widget _moneyRow(String label, double amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(Formatters.money(amount),
            style: strong ? AppTextStyles.titleSmall : AppTextStyles.bodySmall),
      ]),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2, top: 2),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        List<Widget> actions = const [],
        bool highlight = false,
      }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 1),
                Container(
                  decoration: highlight
                      ? BoxDecoration(
                    color:
                    scheme.tertiaryContainer.withValues(alpha: 0.4),
                    borderRadius: AppRadius.brSm,
                  )
                      : null,
                  padding: highlight
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                      : EdgeInsets.zero,
                  child: Text(value,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600, height: 1.3)),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs + 2),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ConfirmActions.showError(context, 'Could not open this on your device.');
      }
    } catch (_) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open this on your device.');
      }
    }
  }

  Future<void> _copy(BuildContext context, String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) ConfirmActions.toast(context, '$what copied');
  }

  Future<void> _update(
      BuildContext context, WidgetRef ref, OrderStatus status) async {
    final isCancel = status == OrderStatus.cancelled;
    final confirmed = await ConfirmActions.confirm(
      context,
      title: isCancel ? 'Cancel this order?' : 'Mark as ${status.label}?',
      message: isCancel
          ? 'The customer will be notified that their order was cancelled.'
          : 'Update this order to "${status.label}"? The customer will be notified.',
      confirmLabel: isCancel ? 'Cancel order' : 'Mark ${status.label}',
      cancelLabel: isCancel ? 'Keep order' : 'Cancel',
      icon: orderStatusIcon(status),
      destructive: isCancel,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(vendorRepositoryProvider)
          .updateOrderStatus(order.orderId, status);
      ref.invalidate(vendorOrdersProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(productStatsProvider);
      if (context.mounted) {
        ConfirmActions.toast(context, 'Order marked ${status.label}',
            success: true);
      }
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }
}

/// Small circular icon button for inline row actions (call / map / copy).
class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniAction(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          color: scheme.primary,
          icon: Icon(icon),
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// Paid / Pending / COD badge.
class _PaymentBadge extends StatelessWidget {
  final AppOrder order;
  const _PaymentBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCod =
        order.paymentMethod == 'cash_on_delivery' || order.paymentMethod == null;
    if (isCod) {
      return StatusPill(label: 'Collect on delivery', color: AppColors.warning);
    }
    return StatusPill(
      label: order.isPaid ? 'Paid' : 'Awaiting payment',
      color: order.isPaid ? AppColors.success : AppColors.warning,
    );
  }
}
