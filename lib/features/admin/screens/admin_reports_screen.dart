import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/stat_card.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

/// Platform-wide analytics for the administrator: people, shops, products,
/// orders and funds.
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
        data: (r) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Funds highlight card.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: AppRadius.brLg,
                gradient: AppTheme.brandGradient,
                boxShadow: AppShadows.brand,
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.revenue,
                          color: Colors.white.withValues(alpha: 0.9), size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Gross Merchandise Value',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(Formatters.money(r.gmv),
                      style: AppTextStyles.displayLarge
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                      'Funds in active orders: ${Formatters.money(r.pendingFunds)}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Colors.white70)),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.06, end: 0),
            const SizedBox(height: AppSpacing.lg),
            _section(context, 'People'),
            const SizedBox(height: AppSpacing.sm + 4),
            _grid([
              StatCard(
                  icon: AppIcons.campus,
                  label: 'Campuses',
                  value: '${r.campuses}',
                  color: AppColors.primary),
              StatCard(
                  icon: AppIcons.people,
                  label: 'Students',
                  value: '${r.students}',
                  color: AppColors.info),
              StatCard(
                  icon: AppIcons.storefront,
                  label: 'Shops',
                  value: '${r.vendors}',
                  color: AppColors.secondary),
              StatCard(
                  icon: AppIcons.package,
                  label: 'Products',
                  value: '${r.products}',
                  color: AppColors.tertiary),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _section(context, 'Shops'),
            const SizedBox(height: AppSpacing.sm + 4),
            _grid([
              StatCard(
                  icon: AppIcons.approved,
                  label: 'Approved',
                  value: '${r.approvedVendors}',
                  color: AppColors.success),
              StatCard(
                  icon: AppIcons.pending,
                  label: 'Pending',
                  value: '${r.pendingVendors}',
                  color: AppColors.warning),
              StatCard(
                  icon: AppIcons.block,
                  label: 'Suspended',
                  value: '${r.suspendedVendors}',
                  color: AppColors.error),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _section(context, 'Orders'),
            const SizedBox(height: AppSpacing.sm + 4),
            _grid([
              StatCard(
                  icon: AppIcons.receipt,
                  label: 'Total Orders',
                  value: '${r.totalOrders}',
                  color: AppColors.neutral700),
              StatCard(
                  icon: AppIcons.truck,
                  label: 'Active',
                  value: '${r.activeOrders}',
                  color: AppColors.warning),
              StatCard(
                  icon: AppIcons.checkFill,
                  label: 'Delivered',
                  value: '${r.completedOrders}',
                  color: AppColors.success),
            ]),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) =>
      Text(title, style: AppTextStyles.titleMedium);

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: AppSpacing.sm + 4,
    crossAxisSpacing: AppSpacing.sm + 4,
    childAspectRatio: 1.35,
    children: children,
  );
}
