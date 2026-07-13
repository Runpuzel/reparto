// lib/features/student/screens/shop_detail_screen.dart
// v1.0-2025-07 – Verified badge + store details (hours, location)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/operating_hours.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';
import '../widgets/product_card.dart';
import '../widgets/service_card.dart';

/// A shop's storefront: header with logo + rating, all its products, reviews.
/// v1.0 adds: verified badge, store hours / location / contact block.
class ShopDetailScreen extends ConsumerWidget {
  final String vendorId;
  const ShopDetailScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider(vendorId));
    final products = ref.watch(shopProductsProvider(vendorId));
    final services = ref.watch(shopServicesProvider(vendorId));
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
              : revs.map((r) => r.rating).reduce((a, b) => a + b) / revs.length;
          final productList = products.valueOrNull ?? [];

          final isVerified = v.isVerified;
          final workingDays = v.workingDays;
          final openingTime = v.openingTime;
          final closingTime = v.closingTime;
          final holidayMode = v.holidayMode;
          final storeLocation = v.storeLocation ?? '';
          final sellerBio = v.sellerBio;
          final specialties = v.specialties;
          final customNote = v.customNote;

          // Ghana stays on UTC year-round, so this remains correct even if a
          // visitor's device is configured for another timezone.
          final now = DateTime.now().toUtc();
          final weekdayMap = {
            1: 'Mon',
            2: 'Tue',
            3: 'Wed',
            4: 'Thu',
            5: 'Fri',
            6: 'Sat',
            7: 'Sun'
          };
          final todayStr = weekdayMap[now.weekday] ?? 'Mon';
          final isOpenDay = workingDays.contains(todayStr);
          final isClosedToday = v.isClosedOn(now);
          final isWithinHours = OperatingHours.isOpenAt(
            now: now,
            openingTime: openingTime,
            closingTime: closingTime,
          );
          String openStatus;
          Color openColor;
          if (holidayMode) {
            openStatus = 'On break';
            openColor = AppColors.warning;
          } else if (isClosedToday || !isOpenDay) {
            openStatus = 'Closed today';
            openColor = AppColors.error;
          } else if (!isWithinHours) {
            openStatus = 'Closed now';
            openColor = AppColors.error;
          } else {
            openStatus = 'Open now';
            openColor = AppColors.success;
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shopProductsProvider(vendorId));
              ref.invalidate(shopServicesProvider(vendorId));
              ref.invalidate(vendorReviewsProvider(vendorId));
              ref.invalidate(shopProvider(vendorId));
            },
            child: CustomScrollView(
              slivers: [
                ShopHeader(
                  shop: v,
                  avg: avg,
                  reviewCount: revs.length,
                  isVerified: isVerified,
                ),
                // v1.0 – Store details card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shop information',
                              style: AppTextStyles.titleLarge),
                          const SizedBox(height: AppSpacing.md),
                          Text('Status', style: AppTextStyles.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          // verified + open status row
                          Row(
                            children: [
                              if (isVerified) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.1),
                                    borderRadius: AppRadius.brFull,
                                    border: Border.all(
                                        color: AppColors.success
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.verified,
                                          size: 14, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text(
                                        'Approved Student Seller',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: openColor.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.brFull,
                                ),
                                child: Text(
                                  openStatus,
                                  style: TextStyle(
                                    color: openColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((sellerBio ?? '').isNotEmpty) ...[
                            const Divider(height: 28),
                            Text('About this seller',
                                style: AppTextStyles.titleSmall),
                            const SizedBox(height: AppSpacing.xs),
                            Text(sellerBio!, style: AppTextStyles.bodyMedium),
                          ],
                          const Divider(height: 28),
                          Text('Opening hours',
                              style: AppTextStyles.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  workingDays.isNotEmpty
                                      ? '${workingDays.join(' · ')}  •  ${OperatingHours.display(openingTime)} – ${OperatingHours.display(closingTime)}'
                                      : 'Hours not set',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (storeLocation.isNotEmpty) ...[
                            const Divider(height: 28),
                            Text('Shop location',
                                style: AppTextStyles.titleSmall),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_outlined, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    storeLocation,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ),
                                if (((v as dynamic).gpsLat) != null)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      minimumSize: const Size(0, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      // TODO: launch maps
                                    },
                                    child: const Text(
                                      'Directions',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (specialties.isNotEmpty) ...[
                            const Divider(height: 28),
                            Text('Specialties',
                                style: AppTextStyles.titleSmall),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: specialties
                                  .map((s) => Chip(
                                        label: Text(
                                          s,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ],
                          if ((customNote ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.warning.withValues(alpha: 0.07),
                                borderRadius: AppRadius.brMd,
                              ),
                              child: Text(
                                '“$customNote”',
                                style: AppTextStyles.bodySmall
                                    .copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                        AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
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
                      padding: const EdgeInsets.fromLTRB(AppSpacing.sm + 4, 0,
                          AppSpacing.sm + 4, AppSpacing.sm + 4),
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                        AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                    child: Row(
                      children: [
                        Text('Services', style: AppTextStyles.titleLarge),
                        const SizedBox(width: AppSpacing.sm),
                        Text('(${services.valueOrNull?.length ?? 0})',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                services.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: SkeletonList(itemCount: 2, itemHeight: 96),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: ErrorState(message: '$e'),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: EmptyState(
                            icon: Icons.handyman_outlined,
                            title: 'No services yet',
                            subtitle: 'This shop has no available services.',
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm + 4,
                            0,
                            AppSpacing.sm + 4,
                            AppSpacing.sm,
                          ),
                          child: ServiceCard(
                            service: list[i],
                            showVendor: false,
                          ),
                        ),
                        childCount: list.length,
                      ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                        AppSpacing.sm + 4, AppSpacing.md, AppSpacing.sm),
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
                        padding: const EdgeInsets.fromLTRB(AppSpacing.sm + 4, 0,
                            AppSpacing.sm + 4, AppSpacing.sm),
                        child: ReviewCard(review: revs[i]),
                      ),
                      childCount: revs.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.lg)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ShopHeader extends StatelessWidget {
  final Vendor shop;
  final double avg;
  final int reviewCount;
  final bool isVerified;
  const ShopHeader(
      {required this.shop,
      required this.avg,
      required this.reviewCount,
      this.isVerified = false});

  @override
  Widget build(BuildContext context) {
    final hasLogo = shop.logoUrl != null && shop.logoUrl!.isNotEmpty;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      foregroundColor: Colors.white,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(shop.businessName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: Colors.white, size: 18),
            ],
          ],
        ),
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
                  Stack(
                    clipBehavior: Clip.none,
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
                      if (isVerified)
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isVerified)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: AppRadius.brFull,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              '✓ Verified Student Seller',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
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

class ReviewCard extends StatelessWidget {
  final Review review;
  const ReviewCard({super.key, required this.review});

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
                        i < review.rating ? AppIcons.starFill : AppIcons.star,
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
