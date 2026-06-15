import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
              message: '$e', onRetry: () => ref.invalidate(shopProvider(vendorId))),
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
              : revs.map((r) => r.rating).reduce((a, b) => a + b) / revs.length;
          final productList = products.valueOrNull ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shopProductsProvider(vendorId));
              ref.invalidate(vendorReviewsProvider(vendorId));
            },
            child: CustomScrollView(
              slivers: [
                _ShopHeader(shop: v, avg: avg, reviewCount: revs.length),
                // Products section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Text('Products',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(width: 8),
                        Text('(${productList.length})',
                            style: TextStyle(
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
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      sliver: SliverGrid(
                        gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
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
                // Reviews
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text('Reviews',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                if (revs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Text('No reviews yet.'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _ReviewCard(review: revs[i]),
                      ),
                      childCount: revs.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
            // subtle pattern via gradient overlay
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
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      image: hasLogo
                          ? DecorationImage(
                          image: NetworkImage(shop.logoUrl!),
                          fit: BoxFit.cover)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasLogo
                        ? null
                        : const Icon(Icons.storefront,
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
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
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text((review.studentName ?? '?')[0].toUpperCase()),
        ),
        title: Row(
          children: List.generate(
            5,
                (i) => Icon(i < review.rating ? Icons.star : Icons.star_border,
                size: 16, color: Colors.amber),
          ),
        ),
        subtitle: (review.comment != null && review.comment!.isNotEmpty)
            ? Text(review.comment!)
            : null,
      ),
    );
  }
}
