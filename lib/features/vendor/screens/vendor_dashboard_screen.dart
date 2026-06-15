import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(vendorOrdersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vendor != null)
            Text('Welcome, ${vendor.businessName}',
                style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AsyncView<SalesSummary>(
            value: summary,
            onRetry: () => ref.invalidate(salesSummaryProvider),
            data: (s) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                    icon: Icons.payments_outlined,
                    label: 'Revenue',
                    value: Formatters.money(s.revenue),
                    color: Colors.green),
                StatCard(
                    icon: Icons.receipt_long,
                    label: 'Total Orders',
                    value: '${s.totalOrders}',
                    color: Colors.blue),
                StatCard(
                    icon: Icons.hourglass_top,
                    label: 'Pending',
                    value: '${s.pendingOrders}',
                    color: Colors.orange),
                StatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Delivered',
                    value: '${s.completedOrders}',
                    color: Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
