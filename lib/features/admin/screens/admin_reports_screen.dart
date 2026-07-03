import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(platformReportProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(platformReportProvider),
      child: AsyncView<PlatformReport>(
        value: report,
        onRetry: () => ref.invalidate(platformReportProvider),
        data: (data) => _ReportContent(report: data),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final PlatformReport report;

  @override
  Widget build(BuildContext context) {
    final completionRate = _rate(report.completedOrders, report.totalOrders);
    final approvalRate = _rate(report.approvedVendors, report.vendors);
    final inactiveTotal = report.totalOrders -
        report.completedOrders -
        report.activeOrders;
    final inactiveOrders = inactiveTotal < 0 ? 0 : inactiveTotal;
    final averageOrder = report.completedOrders == 0
        ? 0.0
        : report.gmv / report.completedOrders;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final padding = constraints.maxWidth < 420 ? 12.0 : 20.0;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padding, 18, padding, 32),
          children: [
            _DashboardHeader(
              totalOrders: report.totalOrders,
              pendingVendors: report.pendingVendors,
            ),
            const SizedBox(height: 18),
            _FinancialSummary(
              gmv: report.gmv,
              pendingFunds: report.pendingFunds,
              averageOrder: averageOrder,
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Operational overview',
              subtitle: 'The current health of orders and vendor operations.',
            ),
            const SizedBox(height: 12),
            _ResponsiveGrid(
              columns: columns,
              itemHeight: 112,
              children: [
                _MetricTile(
                  icon: AppIcons.receipt,
                  label: 'Total orders',
                  value: '${report.totalOrders}',
                  detail: '${report.activeOrders} currently active',
                  color: AppColors.info,
                ),
                _MetricTile(
                  icon: AppIcons.checkFill,
                  label: 'Completed',
                  value: '${report.completedOrders}',
                  detail: '${_percent(completionRate)} completion rate',
                  color: AppColors.success,
                ),
                _MetricTile(
                  icon: AppIcons.pending,
                  label: 'Active orders',
                  value: '${report.activeOrders}',
                  detail: Formatters.money(report.pendingFunds),
                  color: AppColors.warning,
                ),
                _MetricTile(
                  icon: Icons.remove_circle_outline,
                  label: 'Inactive orders',
                  value: '$inactiveOrders',
                  detail: 'Cancelled or closed',
                  color: AppColors.neutral500,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _OrderHealth(
                      active: report.activeOrders,
                      completed: report.completedOrders,
                      inactive: inactiveOrders,
                      completionRate: completionRate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _VendorHealth(
                      approved: report.approvedVendors,
                      pending: report.pendingVendors,
                      suspended: report.suspendedVendors,
                      approvalRate: approvalRate,
                    ),
                  ),
                ],
              )
            else ...[
              _OrderHealth(
                active: report.activeOrders,
                completed: report.completedOrders,
                inactive: inactiveOrders,
                completionRate: completionRate,
              ),
              const SizedBox(height: 12),
              _VendorHealth(
                approved: report.approvedVendors,
                pending: report.pendingVendors,
                suspended: report.suspendedVendors,
                approvalRate: approvalRate,
              ),
            ],
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Marketplace footprint',
              subtitle: 'People, locations, shops, and available inventory.',
            ),
            const SizedBox(height: 12),
            _ResponsiveGrid(
              columns: columns,
              itemHeight: 96,
              children: [
                _MetricTile(
                  icon: AppIcons.people,
                  label: 'Students',
                  value: '${report.students}',
                  color: AppColors.info,
                ),
                _MetricTile(
                  icon: AppIcons.storefront,
                  label: 'Vendor accounts',
                  value: '${report.vendors}',
                  color: AppColors.secondary,
                ),
                _MetricTile(
                  icon: AppIcons.package,
                  label: 'Products',
                  value: '${report.products}',
                  color: AppColors.tertiary,
                ),
                _MetricTile(
                  icon: AppIcons.campus,
                  label: 'Campuses',
                  value: '${report.campuses}',
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  double _rate(int value, int total) => total == 0 ? 0 : value / total;
  String _percent(double value) => '${(value * 100).round()}%';
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.totalOrders,
    required this.pendingVendors,
  });

  final int totalOrders;
  final int pendingVendors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform report', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'A live summary of marketplace activity and operational health.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (pendingVendors > 0)
          _AttentionBadge(label: '$pendingVendors vendor reviews'),
      ],
    );
  }
}

class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.priority_high, size: 16, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      );
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({
    required this.gmv,
    required this.pendingFunds,
    required this.averageOrder,
  });

  final double gmv;
  final double pendingFunds;
  final double averageOrder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final metrics = [
            _FinanceMetric('Completed GMV', Formatters.money(gmv),
                Icons.account_balance_wallet_outlined),
            _FinanceMetric('Funds in active orders',
                Formatters.money(pendingFunds), Icons.hourglass_top),
            _FinanceMetric('Average completed order',
                Formatters.money(averageOrder), Icons.analytics_outlined),
          ];
          return compact
              ? Column(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      metrics[i],
                      if (i < metrics.length - 1) const Divider(height: 24),
                    ],
                  ],
                )
              : Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      Expanded(child: metrics[i]),
                      if (i < metrics.length - 1)
                        const SizedBox(height: 54, child: VerticalDivider()),
                    ],
                  ],
                );
        },
      ),
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleLarge),
              ],
            ),
          ),
        ],
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.columns,
    required this.itemHeight,
    required this.children,
  });
  final int columns;
  final double itemHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: itemHeight,
        children: children,
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleLarge),
                  if (detail != null)
                    Text(detail!,
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

class _OrderHealth extends StatelessWidget {
  const _OrderHealth({
    required this.active,
    required this.completed,
    required this.inactive,
    required this.completionRate,
  });
  final int active;
  final int completed;
  final int inactive;
  final double completionRate;

  @override
  Widget build(BuildContext context) => _HealthPanel(
        title: 'Order health',
        value: '${(completionRate * 100).round()}%',
        caption: 'Completion rate',
        progress: completionRate,
        color: AppColors.success,
        rows: [
          _HealthRow('Completed', completed, AppColors.success),
          _HealthRow('Active', active, AppColors.warning),
          _HealthRow('Inactive', inactive, AppColors.neutral500),
        ],
      );
}

class _VendorHealth extends StatelessWidget {
  const _VendorHealth({
    required this.approved,
    required this.pending,
    required this.suspended,
    required this.approvalRate,
  });
  final int approved;
  final int pending;
  final int suspended;
  final double approvalRate;

  @override
  Widget build(BuildContext context) => _HealthPanel(
        title: 'Vendor health',
        value: '${(approvalRate * 100).round()}%',
        caption: 'Approval rate',
        progress: approvalRate,
        color: AppColors.info,
        rows: [
          _HealthRow('Approved', approved, AppColors.success),
          _HealthRow('Pending review', pending, AppColors.warning),
          _HealthRow('Suspended', suspended, AppColors.error),
        ],
      );
}

class _HealthRow {
  const _HealthRow(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({
    required this.title,
    required this.value,
    required this.caption,
    required this.progress,
    required this.color,
    required this.rows,
  });
  final String title;
  final String value;
  final String caption;
  final double progress;
  final Color color;
  final List<_HealthRow> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: AppTextStyles.headlineSmall),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(caption, style: AppTextStyles.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 16),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, color: row.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.label)),
                    Text('${row.value}', style: AppTextStyles.labelMedium),
                  ],
                ),
              ),
          ],
        ),
      );
}
