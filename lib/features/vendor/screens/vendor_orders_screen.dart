import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/vendor_providers.dart';

/// Allowed forward transitions per the Reparto delivery lifecycle:
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
          child: AsyncView<List<AppOrder>>(
            value: orders,
            onRetry: () => ref.invalidate(vendorOrdersProvider),
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
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _VendorOrderCard(order: filtered[i]),
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

  String get _shortId => order.orderId.substring(0, 8).toUpperCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = orderStatusColor(order.status, context);
    final next = _nextStatuses[order.status] ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(orderStatusIcon(order.status), color: color, size: 20),
        ),
        title: Text(order.studentName ?? 'Customer',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '#$_shortId · ${order.itemCount} item(s) · ${Formatters.dateTime(order.createdAt)}'),
        trailing: StatusPill(label: order.status.label, color: color),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          // ---- WHAT to prepare ------------------------------------------
          _sectionLabel(context, 'Items to prepare'),
          ...order.items.map((it) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    color: scheme.surfaceContainerHighest,
                    child: it.productImage != null
                        ? Image.network(it.productImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.fastfood_outlined, size: 18))
                        : const Icon(Icons.fastfood_outlined, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('×${it.quantity}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(it.productName ?? 'Item',
                        style:
                        const TextStyle(fontWeight: FontWeight.w500))),
                Text(Formatters.money(it.lineTotal)),
              ],
            ),
          )),

          const Divider(height: 22),

          // ---- WHO + WHERE ----------------------------------------------
          _sectionLabel(context, 'Customer & delivery'),
          _detailRow(
            context,
            icon: Icons.person_outline,
            label: 'Name',
            value: order.studentName ?? 'Customer',
          ),
          if (_has(order.contactPhone))
            _detailRow(
              context,
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: order.contactPhone!,
              actions: [
                _MiniAction(
                  icon: Icons.call,
                  tooltip: 'Call',
                  onTap: () => _launch(context, 'tel:${order.contactPhone}'),
                ),
                _MiniAction(
                  icon: Icons.sms_outlined,
                  tooltip: 'Text',
                  onTap: () => _launch(context, 'sms:${order.contactPhone}'),
                ),
                _MiniAction(
                  icon: Icons.copy,
                  tooltip: 'Copy',
                  onTap: () => _copy(context, order.contactPhone!, 'Phone'),
                ),
              ],
            ),
          if (_has(order.deliveryAddress))
            _detailRow(
              context,
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: order.deliveryAddress!,
              actions: [
                _MiniAction(
                  icon: Icons.map_outlined,
                  tooltip: 'Open in Maps',
                  onTap: () => _launch(
                    context,
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order.deliveryAddress!)}',
                  ),
                ),
                _MiniAction(
                  icon: Icons.copy,
                  tooltip: 'Copy',
                  onTap: () =>
                      _copy(context, order.deliveryAddress!, 'Address'),
                ),
              ],
            ),
          if (_has(order.note))
            _detailRow(
              context,
              icon: Icons.sticky_note_2_outlined,
              label: 'Note',
              value: order.note!,
              highlight: true,
            ),

          const Divider(height: 22),

          // ---- HOW they pay ---------------------------------------------
          _sectionLabel(context, 'Payment'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(order.paymentMethodLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order total',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(Formatters.money(order.totalAmount),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: scheme.primary)),
            ],
          ),

          // ---- Actions --------------------------------------------------
          if (next.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: next.map((s) {
                final isCancel = s == OrderStatus.cancelled;
                return isCancel
                    ? OutlinedButton(
                  onPressed: () => _update(context, ref, s),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      minimumSize: const Size(0, 40)),
                  child: const Text('Cancel'),
                )
                    : FilledButton.icon(
                  onPressed: () => _update(context, ref, s),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40)),
                  icon: Icon(orderStatusIcon(s), size: 18),
                  label: Text('Mark ${s.label}'),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  bool _has(String? v) => v != null && v.trim().isNotEmpty;

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 1),
                Container(
                  decoration: highlight
                      ? BoxDecoration(
                    color: scheme.tertiaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  )
                      : null,
                  padding: highlight
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                      : EdgeInsets.zero,
                  child: Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, height: 1.3)),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 6),
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
      padding: const EdgeInsets.only(left: 4),
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
      return const StatusPill(label: 'Collect on delivery', color: Colors.orange);
    }
    return StatusPill(
      label: order.isPaid ? 'Paid' : 'Awaiting payment',
      color: order.isPaid ? Colors.green : Colors.orange,
    );
  }
}
