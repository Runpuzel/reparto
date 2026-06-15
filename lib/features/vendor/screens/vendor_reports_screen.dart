import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../models/models.dart';
import '../data/vendor_repository.dart';
import '../providers/vendor_providers.dart';

/// Sales report for the shop owner: KPIs, per-product performance, and
/// customer reviews with an average rating.
class VendorReportsScreen extends ConsumerWidget {
  const VendorReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(salesSummaryProvider);
    final stats = ref.watch(productStatsProvider);
    final reviews = ref.watch(myShopReviewsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(productStatsProvider);
        ref.invalidate(myShopReviewsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heading(context, 'Sales overview', Icons.insights_outlined),
          const SizedBox(height: 12),
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
                    label: 'Total Revenue',
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
                    icon: Icons.local_shipping_outlined,
                    label: 'Delivered',
                    value: '${s.completedOrders}',
                    color: Colors.teal),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _heading(context, 'Product performance', Icons.leaderboard_outlined),
          const SizedBox(height: 12),
          AsyncView<List<ProductStat>>(
            value: stats,
            onRetry: () => ref.invalidate(productStatsProvider),
            data: (list) {
              if (list.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('No products yet'),
                  ),
                );
              }
              final maxUnits = list
                  .map((e) => e.unitsSold)
                  .fold<int>(0, (a, b) => a > b ? a : b);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: list
                        .map((p) => _ProductStatRow(stat: p, maxUnits: maxUnits))
                        .toList(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          _heading(context, 'Customer reviews', Icons.reviews_outlined),
          const SizedBox(height: 12),
          AsyncView<List<Review>>(
            value: reviews,
            onRetry: () => ref.invalidate(myShopReviewsProvider),
            data: (list) {
              if (list.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.rate_review_outlined),
                    title: Text('No reviews yet'),
                  ),
                );
              }
              final avg =
                  list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(avg.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                      (i) => Icon(
                                      i < avg.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 20),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${list.length} review(s)',
                                  style:
                                  Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...list.map((r) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                            (r.studentName ?? '?')[0].toUpperCase()),
                      ),
                      title: Row(
                        children: List.generate(
                          5,
                              (i) => Icon(
                              i < r.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 15,
                              color: Colors.amber),
                        ),
                      ),
                      subtitle: (r.comment != null && r.comment!.isNotEmpty)
                          ? Text(r.comment!)
                          : null,
                      trailing: Text(Formatters.dateTime(r.createdAt),
                          style: Theme.of(context).textTheme.bodySmall),
                      isThreeLine:
                      r.comment != null && r.comment!.isNotEmpty,
                    ),
                  )),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _ProductStatRow extends StatelessWidget {
  final ProductStat stat;
  final int maxUnits;
  const _ProductStatRow({required this.stat, required this.maxUnits});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = maxUnits == 0 ? 0.0 : stat.unitsSold / maxUnits;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('${stat.unitsSold} sold',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 10),
              Text(Formatters.money(stat.revenue),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction == 0 ? null : fraction,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
