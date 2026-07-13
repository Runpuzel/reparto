import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/vendor_repository.dart';
import '../providers/vendor_providers.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(salesSummaryProvider);
    final orders = ref.watch(vendorOrdersProvider);
    final products = ref.watch(myProductsProvider);
    final services = ref.watch(myServicesProvider);
    final vendor = ref.watch(currentVendorProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentVendorProvider);
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(vendorOrdersProvider);
        ref.invalidate(myProductsProvider);
        ref.invalidate(myServicesProvider);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          final padding = constraints.maxWidth < 400 ? 12.0 : 16.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 28),
            children: [
              Text(
                vendor == null
                    ? 'Seller overview'
                    : 'Welcome back, ${vendor.businessName}',
                style: AppTextStyles.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Track what needs attention and how your store is performing.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (vendor != null && !vendor.hasPayoutDetails) ...[
                _PayoutSetupBanner(
                  onSetup: () async {
                    await context.push('/vendor/store/edit');
                    ref.invalidate(currentVendorProvider);
                  },
                ),
                const SizedBox(height: 18),
              ],
              AsyncView<SalesSummary>(
                value: summary,
                onRetry: () => ref.invalidate(salesSummaryProvider),
                data: (data) => Column(
                  children: [
                    _RevenuePanel(summary: data),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 100,
                      children: [
                        _DashboardMetric(
                          'Active orders',
                          '${data.activeOrders}',
                          'Needs fulfilment',
                          AppIcons.pending,
                          AppColors.warning,
                        ),
                        _DashboardMetric(
                          'Completed',
                          '${data.completedOrders}',
                          '${(data.completionRate * 100).round()}% completion',
                          AppIcons.checkFill,
                          AppColors.success,
                        ),
                        _DashboardMetric(
                          'Products',
                          '${products.valueOrNull?.length ?? 0}',
                          'Catalog listings',
                          AppIcons.package,
                          AppColors.info,
                        ),
                        _DashboardMetric(
                          'Services',
                          '${services.valueOrNull?.length ?? 0}',
                          'Service listings',
                          Icons.design_services_outlined,
                          AppColors.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Recent orders', style: AppTextStyles.titleMedium),
              const SizedBox(height: 10),
              orders.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => ErrorState(
                  message: '$error',
                  onRetry: () => ref.invalidate(vendorOrdersProvider),
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyOrders()
                    : Column(
                        children: items
                            .take(5)
                            .map((order) => _RecentOrder(order: order))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayoutSetupBanner extends StatelessWidget {
  const _PayoutSetupBanner({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 680),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash on Delivery only',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a valid Mobile Money payout number before buyers can prepay for your products.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onSetup,
            icon: const Icon(Icons.add_card_outlined, size: 18),
            label: const Text('Add payout details'),
          ),
        ],
      ),
    );
  }
}

class _RevenuePanel extends StatelessWidget {
  const _RevenuePanel({required this.summary});
  final SalesSummary summary;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            _FinanceValue('Completed revenue',
                Formatters.money(summary.revenue), AppIcons.revenue),
            _FinanceValue('Average completed order',
                Formatters.money(summary.averageCompletedOrder),
                Icons.analytics_outlined),
            _FinanceValue(
                'Total orders', '${summary.totalOrders}', AppIcons.receipt),
          ],
        ),
      );
}

class _FinanceValue extends StatelessWidget {
  const _FinanceValue(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodySmall),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleLarge),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric(
      this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodySmall),
                  Text(value, style: AppTextStyles.titleLarge),
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(color: color)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RecentOrder extends StatelessWidget {
  const _RecentOrder({required this.order});
  final AppOrder order;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status, context);
    final id = order.orderId.length >= 8
        ? order.orderId.substring(0, 8).toUpperCase()
        : order.orderId.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(orderStatusIcon(order.status), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.studentName ?? 'Customer',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('#$id - ${order.itemCount} item(s)',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label: order.status.label, color: color),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('New orders will appear here.'),
      );
}
