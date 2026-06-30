import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _heading(context, 'Sales overview', AppIcons.insights),
          const SizedBox(height: AppSpacing.sm + 4),
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
                    label: 'Total Revenue',
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
                    icon: AppIcons.truck,
                    label: 'Delivered',
                    value: '${s.completedOrders}',
                    color: AppColors.primary),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _heading(context, 'Product performance', AppIcons.leaderboard),
          const SizedBox(height: AppSpacing.sm + 4),
          AsyncView<List<ProductStat>>(
            value: stats,
            onRetry: () => ref.invalidate(productStatsProvider),
            data: (list) {
              if (list.isEmpty) {
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(AppIcons.package),
                    title: const Text('No products yet'),
                  ),
                );
              }
              final maxUnits = list
                  .map((e) => e.unitsSold)
                  .fold<int>(0, (a, b) => a > b ? a : b);
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: list
                      .map((p) =>
                      _ProductStatRow(stat: p, maxUnits: maxUnits))
                      .toList(),
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),
          _heading(context, 'Customer reviews', AppIcons.reviews),
          const SizedBox(height: AppSpacing.sm + 4),
          AsyncView<List<Review>>(
            value: reviews,
            onRetry: () => ref.invalidate(myShopReviewsProvider),
            data: (list) {
              if (list.isEmpty) {
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(AppIcons.reviews),
                    title: const Text('No reviews yet'),
                  ),
                );
              }
              final avg =
                  list.map((r) => r.rating).reduce((a, b) => a + b) /
                      list.length;
              return Column(
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Text(avg.toStringAsFixed(1),
                            style: AppTextStyles.displayMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                    (i) => Icon(
                                    i < avg.round()
                                        ? AppIcons.starFill
                                        : AppIcons.star,
                                    color: Colors.amber,
                                    size: 20),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text('${list.length} review(s)',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...list.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ReviewTile(review: r),
                  )),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: AppTextStyles.titleLarge),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasComment = review.comment != null && review.comment!.isNotEmpty;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text((review.studentName ?? '?')[0].toUpperCase()),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(
                      5,
                          (i) => Icon(
                          i < review.rating
                              ? AppIcons.starFill
                              : AppIcons.star,
                          size: 15,
                          color: Colors.amber),
                    ),
                    const Spacer(),
                    Text(Formatters.dateTime(review.createdAt),
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                if (hasComment) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(review.comment!,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: scheme.onSurface)),
                ],
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(stat.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSmall),
              ),
              Text('${stat.unitsSold} sold', style: AppTextStyles.bodySmall),
              const SizedBox(width: AppSpacing.sm + 2),
              Text(Formatters.money(stat.revenue),
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          ClipRRect(
            borderRadius: AppRadius.brSm,
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
