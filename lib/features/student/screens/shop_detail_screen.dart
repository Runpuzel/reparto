import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';
import '../widgets/product_card.dart';

/// A shop's storefront: header with logo + rating, all its products, reviews.
class ShopDetailScreen extends ConsumerWidget {
  final String vendorId;
  const ShopDetailScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider(vendorId));
    final products = ref.watch(shopProductsProvider(vendorId));
    final reviews = ref.watch(vendorReviewsProvider(vendorId));

    return Scaffold(
      body: shop.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(shopProvider(vendorId))),
        ),
        data: (v) {
          if (v == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                  icon: Icons.storefront_outlined, title: 'Shop not found'),
            );
          }
          final revs = reviews.valueOrNull ?? [];
          final avg = revs.isEmpty
              ? 0.0
              : revs.map((r) => r.rating).reduce((a, b) => a + b) /
              revs.length;
          final productList = products.valueOrNull ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shopProductsProvider(vendorId));
              ref.invalidate(vendorReviewsProvider(vendorId));
            },
            child: CustomScrollView(
              slivers: [
                _ShopHeader(shop: v, avg: avg, reviewCount: revs.length),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.lg, AppSpacing.md,
                        AppSpacing.sm),
                    child: Row(
                      children: [
                        Text('Products', style: AppTextStyles.titleLarge),
                        const SizedBox(width: AppSpacing.sm),
                        Text('(${productList.length})',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                products.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: ErrorState(message: '$e'),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products yet',
                            subtitle: 'This shop has no available items.',
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm + 4, 0, AppSpacing.sm + 4,
                          AppSpacing.sm + 4),
                      sliver: SliverGrid(
                        gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: AppSpacing.sm + 4,
                          crossAxisSpacing: AppSpacing.sm + 4,
                          childAspectRatio: 0.66,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, i) =>
                              ProductCard(product: list[i], showVendor: false),
                          childCount: list.length,
                        ),
                      ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md,
                        AppSpacing.sm),
                    child: Text('Reviews', style: AppTextStyles.titleLarge),
                  ),
                ),
                if (revs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                      child: Text('No reviews yet.',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm + 4, 0, AppSpacing.sm + 4,
                            AppSpacing.sm),
                        child: _ReviewCard(review: revs[i]),
                      ),
                      childCount: revs.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  final Vendor shop;
  final double avg;
  final int reviewCount;
  const _ShopHeader(
      {required this.shop, required this.avg, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    final hasLogo = shop.logoUrl != null && shop.logoUrl!.isNotEmpty;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      foregroundColor: Colors.white,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(shop.businessName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        background: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppTheme.brandGradient),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 56),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.brLg,
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasLogo
                        ? AppNetworkImage(
                        url: shop.logoUrl,
                        fallbackIcon: AppIcons.storefront)
                        : Icon(AppIcons.storefrontFill,
                        color: AppTheme.primary, size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reviewCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: AppRadius.brFull,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.starFill,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${avg.toStringAsFixed(1)} · $reviewCount reviews',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  children: List.generate(
                    5,
                        (i) => Icon(
                        i < review.rating
                            ? AppIcons.starFill
                            : AppIcons.star,
                        size: 16,
                        color: Colors.amber),
                  ),
                ),
                if (review.comment != null && review.comment!.isNotEmpty) ...[
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
