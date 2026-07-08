import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';

/// Lists all approved shops on the student's campus.
class ShopsScreen extends ConsumerStatefulWidget {
  const ShopsScreen({super.key});

  @override
  ConsumerState<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends ConsumerState<ShopsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(shopsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(shopsProvider),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search shops...',
                prefixIcon: Icon(AppIcons.search, size: 20),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(AppIcons.close, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    ref.read(shopSearchProvider.notifier).state = '';
                    setState(() {});
                  },
                ),
              ),
              onChanged: (v) {
                ref.read(shopSearchProvider.notifier).state = v;
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: shops.when(
              loading: () => const SkeletonList(itemCount: 6, itemHeight: 88),
              error: (e, _) => ErrorState(
                  message: '$e', onRetry: () => ref.invalidate(shopsProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 100),
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No shops yet',
                      subtitle: 'Approved shops on your campus appear here.',
                    ),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm + 4, AppSpacing.xs, AppSpacing.sm + 4,
                      AppSpacing.md),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm + 2),
                  itemBuilder: (_, i) => _ShopCard(shop: list[i])
                      .animate()
                      .fadeIn(delay: (40 * (i % 12)).ms, duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Vendor shop;
  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLogo = shop.logoUrl != null && shop.logoUrl!.isNotEmpty;
    return AppCard(
      onTap: () => context.push('/student/shop/${shop.vendorId}'),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brLg,
            child: SizedBox(
              width: 60,
              height: 60,
              child: hasLogo
                  ? AppNetworkImage(
                  url: shop.logoUrl, fallbackIcon: AppIcons.storefront)
                  : Container(
                color: scheme.primaryContainer,
                child: Icon(AppIcons.storefrontFill,
                    color: scheme.onPrimaryContainer, size: 28),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.businessName,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: scheme.onSurface)),
                if (shop.description != null &&
                    shop.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(shop.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          Icon(AppIcons.caretRight, color: scheme.onSurfaceVariant, size: 18),
        ],
      ),
    );
  }
}
