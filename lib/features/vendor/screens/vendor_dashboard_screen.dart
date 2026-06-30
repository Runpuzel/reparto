import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/vendor_repository.dart';
import '../providers/vendor_providers.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(salesSummaryProvider);
    final vendor = ref.watch(currentVendorProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(vendorOrdersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (vendor != null)
            Text('Welcome, ${vendor.businessName}',
                style: AppTextStyles.titleLarge
                    .copyWith(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.md),
          AsyncView<SalesSummary>(
            value: summary,
            onRetry: () => ref.invalidate(salesSummaryProvider),
            data: (s) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm + 4,
              crossAxisSpacing: AppSpacing.sm + 4,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                    icon: AppIcons.revenue,
                    label: 'Revenue',
                    value: Formatters.money(s.revenue),
                    color: AppColors.success),
                StatCard(
                    icon: AppIcons.receipt,
                    label: 'Total Orders',
                    value: '${s.totalOrders}',
                    color: AppColors.info),
                StatCard(
                    icon: AppIcons.pending,
                    label: 'Pending',
                    value: '${s.pendingOrders}',
                    color: AppColors.warning),
                StatCard(
                    icon: AppIcons.check,
                    label: 'Delivered',
                    value: '${s.completedOrders}',
                    color: AppColors.primary),
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.08, end: 0),
            ),
          ),
        ],
      ),
    );
  }
}
