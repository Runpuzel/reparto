import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Shimmer skeleton building blocks used for loading states.
///
/// Wrap any layout of [SkeletonBox]es in a [AppShimmer] to get the animated
/// loading effect themed for light/dark mode.
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF2C2430) : const Color(0xFFE9ECEF),
      highlightColor: dark ? const Color(0xFF3A323D) : const Color(0xFFF6F7F8),
      child: child,
    );
  }
}

/// A single grey block used inside an [AppShimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.margin,
  });

  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A reusable list skeleton — [itemCount] stacked card-like rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.shrinkWrap = false,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => Row(
          children: [
            const SkeletonBox(width: 56, height: 56, radius: AppRadius.md),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: AppSpacing.sm),
                  const SkeletonBox(width: 140, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable product-grid skeleton (2 columns of cards).
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.shrinkWrap = false,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.66,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => const SkeletonProductCard(),
      ),
    );
  }
}

/// Skeleton for a single product card.
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              radius: AppRadius.lg),
        ),
        const SizedBox(height: 10),
        const SkeletonBox(width: double.infinity, height: 14),
        const SizedBox(height: 6),
        const SkeletonBox(width: 120, height: 12),
        const SizedBox(height: 10),
        const SkeletonBox(width: 70, height: 18),
      ],
    );
  }
}
