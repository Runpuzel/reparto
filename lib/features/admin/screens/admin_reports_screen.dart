import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          padding: const EdgeInsets.all(16),
          children: [
            // Funds highlight card.
            Card(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gross Merchandise Value',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(Formatters.money(r.gmv),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                        'Funds in active orders: ${Formatters.money(r.pendingFunds)}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _section(context, 'People'),
            const SizedBox(height: 12),
            _grid([
              StatCard(
                  icon: Icons.school,
                  label: 'Campuses',
                  value: '${r.campuses}',
                  color: Colors.indigo),
              StatCard(
                  icon: Icons.people,
                  label: 'Students',
                  value: '${r.students}',
                  color: Colors.blue),
              StatCard(
                  icon: Icons.storefront,
                  label: 'Shops',
                  value: '${r.vendors}',
                  color: Colors.deepPurple),
              StatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Products',
                  value: '${r.products}',
                  color: Colors.brown),
            ]),
            const SizedBox(height: 20),
            _section(context, 'Shops'),
            const SizedBox(height: 12),
            _grid([
              StatCard(
                  icon: Icons.verified,
                  label: 'Approved',
                  value: '${r.approvedVendors}',
                  color: Colors.teal),
              StatCard(
                  icon: Icons.hourglass_top,
                  label: 'Pending',
                  value: '${r.pendingVendors}',
                  color: Colors.orange),
              StatCard(
                  icon: Icons.block,
                  label: 'Suspended',
                  value: '${r.suspendedVendors}',
                  color: Colors.redAccent),
            ]),
            const SizedBox(height: 20),
            _section(context, 'Orders'),
            const SizedBox(height: 12),
            _grid([
              StatCard(
                  icon: Icons.receipt_long,
                  label: 'Total Orders',
                  value: '${r.totalOrders}',
                  color: Colors.blueGrey),
              StatCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'Active',
                  value: '${r.activeOrders}',
                  color: Colors.orange),
              StatCard(
                  icon: Icons.check_circle,
                  label: 'Delivered',
                  value: '${r.completedOrders}',
                  color: Colors.green),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Text(title,
      style: Theme.of(context).textTheme.titleMedium);

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.5,
    children: children,
  );
}
