import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/vendor_providers.dart';

class VendorProductsScreen extends ConsumerWidget {
  const VendorProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(myProductsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myProductsProvider),
      child: products.when(
        loading: () => const SkeletonList(itemCount: 6, itemHeight: 80),
        error: (e, _) => ErrorState(
            message: '$e', onRetry: () => ref.invalidate(myProductsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No products yet',
                subtitle: 'Tap "Add Product" to list your first item.',
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _ProductTile(product: list[i])
                .animate()
                .fadeIn(delay: (40 * (i % 12)).ms, duration: 280.ms)
                .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final low = product.quantityAvailable <= 0;
    return AppCard(
      onTap: () => context.push('/vendor/product-form', extra: product),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brMd,
            child: SizedBox(
              width: 52,
              height: 52,
              child: AppNetworkImage(
                  url: product.imageUrl, fallbackIcon: AppIcons.image),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(Formatters.money(product.price),
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Text('Qty: ${product.quantityAvailable}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: low
                                ? AppColors.error
                                : scheme.onSurfaceVariant,
                            fontWeight:
                            low ? FontWeight.w700 : FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
            onSelected: (v) async {
              if (v == 'boost') {
                await _redeem(
                  context, ref,
                  action: () => ref
                      .read(tokensRepositoryProvider)
                      .redeemBoost(product.productId),
                  success: 'Listing boosted for 3 days',
                );
              } else if (v == 'waive') {
                await _redeem(
                  context, ref,
                  action: () => ref
                      .read(tokensRepositoryProvider)
                      .redeemCommissionDiscount(product.productId),
                  success: 'Commission waived on this listing',
                );
              } else if (v == 'edit') {
                context.push('/vendor/product-form', extra: product);
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete product?'),
                    content: Text('Remove "${product.productName}"?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref
                      .read(vendorRepositoryProvider)
                      .deleteProduct(product.productId);
                  ref.invalidate(myProductsProvider);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'boost',
                child: Row(children: [
                  Icon(AppIcons.flash, size: 18),
                  const SizedBox(width: AppSpacing.sm + 4),
                  const Text('Boost (10 tokens)'),
                ]),
              ),
              PopupMenuItem(
                value: 'waive',
                child: Row(children: [
                  Icon(AppIcons.price, size: 18),
                  const SizedBox(width: AppSpacing.sm + 4),
                  const Text('Waive commission (5 tokens)'),
                ]),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(AppIcons.edit, size: 18),
                  const SizedBox(width: AppSpacing.sm + 4),
                  const Text('Edit'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(AppIcons.trash, size: 18, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(
      BuildContext context,
      WidgetRef ref, {
        required Future<void> Function() action,
        required String success,
      }) async {
    try {
      await action();
      ref.invalidate(myProductsProvider);
      ref.invalidate(tokenBalanceProvider);
      if (context.mounted) {
        ConfirmActions.toast(context, success, success: true);
      }
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }
}
