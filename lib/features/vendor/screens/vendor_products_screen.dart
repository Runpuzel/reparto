// lib/features/vendor/screens/vendor_products_screen.dart
// v1.0-2025-07 – Products + Services tabs, expiration badges – CLEAN, no shims

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_client.dart';
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
import '../providers/vendor_providers.dart';

class VendorProductsScreen extends ConsumerStatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  ConsumerState<VendorProductsScreen> createState() =>
      VendorProductsScreenState();
}

class VendorProductsScreenState
    extends ConsumerState<VendorProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController tab;
  RealtimeChannel? _inventoryChannel;

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 2, vsync: this);
    _inventoryChannel = supabase
        .channel('vendor-inventory-${supabase.auth.currentUser?.id ?? 'guest'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          callback: (_) => ref.invalidate(myProductsProvider),
        )
        .subscribe();
  }

  @override
  void dispose() {
    tab.dispose();
    final channel = _inventoryChannel;
    if (channel != null) supabase.removeChannel(channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: tab,
            tabs: const [
              Tab(
                  text: 'Products',
                  icon: Icon(Icons.inventory_2_outlined, size: 20)),
              Tab(
                  text: 'Services',
                  icon: Icon(Icons.design_services_outlined, size: 20)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tab,
            children: const [
              ProductsTab(),
              ServicesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ===== Products Tab =====
class ProductsTab extends ConsumerWidget {
  const ProductsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(myProductsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myProductsProvider),
      child: products.when(
        loading: () =>
        const SkeletonList(itemCount: 6, itemHeight: 80),
        error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(myProductsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  subtitle:
                  'Tap "Add Product" to list your first item.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => ProductTile(product: list[i])
                .animate()
                .fadeIn(
                delay: Duration(milliseconds: 40 * (i % 12)),
                duration: const Duration(milliseconds: 280))
                .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

class ProductTile extends ConsumerWidget {
  final Product product;
  const ProductTile({required this.product, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final low = product.quantityAvailable <= 0;
    return AppCard(
      onTap: () =>
          context.push('/vendor/product-form', extra: product),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brMd,
            child: SizedBox(
              width: 52,
              height: 52,
              child: AppNetworkImage(
                  url: product.imageUrl,
                  fallbackIcon: AppIcons.image),
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
                    Text(
                        'Qty: ${product.quantityAvailable}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: low
                                ? AppColors.error
                                : scheme.onSurfaceVariant,
                            fontWeight: low
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: scheme.onSurfaceVariant),
            onSelected: (v) async {
              if (v == 'edit') {
                context.push('/vendor/product-form',
                    extra: product);
              } else if (v == 'delete') {
                final ok = await ConfirmActions.confirm(
                  context,
                  title: 'Delete product?',
                  message: 'Remove "${product.productName}"?',
                  destructive: true,
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
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(AppIcons.edit, size: 18),
                  SizedBox(width: 12),
                  Text('Edit'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== Services Tab – v1.0 expiration badges =====
class ServicesTab extends ConsumerWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(myServicesProvider);
    final platform = ref.watch(vendorPlatformSettingsProvider);

    final isFreeMode = platform.value?.isFreeMode ?? true;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myServicesProvider);
        ref.invalidate(vendorPlatformSettingsProvider);
      },
      child: services.when(
        loading: () =>
        const SkeletonList(itemCount: 4, itemHeight: 96),
        error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(myServicesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 100),
                EmptyState(
                  icon: Icons.design_services_outlined,
                  title: 'No services yet',
                  subtitle: isFreeMode
                      ? 'Post a service – Free Mode: no expiration'
                      : 'Post a service under the current listing policy',
                ),
                const SizedBox(height: 16),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Offer a Service'),
                    onPressed: () =>
                        context.push('/vendor/service-form'),
                  ),
                ),
              ],
            );
          }

          final sorted = [...list];
          sorted.sort((a, b) {
            if (a.isAuthorized != b.isAuthorized) {
              return a.isAuthorized ? 1 : -1;
            }
            return a.daysLeft.compareTo(b.daysLeft);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            itemCount: sorted.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => ServiceTile(
              service: sorted[i],
              isFreeMode: isFreeMode,
            )
                .animate()
                .fadeIn(
                delay: Duration(
                    milliseconds: 35 * (i % 12)),
                duration:
                const Duration(milliseconds: 260))
                .slideY(begin: 0.04, end: 0),
          );
        },
      ),
    );
  }
}

class ServiceTile extends ConsumerWidget {
  final Service service;
  final bool isFreeMode;
  const ServiceTile(
      {required this.service,
        required this.isFreeMode,
        super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final exp = _expirationInfo(service, isFreeMode);

    return AppCard(
      onTap: () => context
          .push('/vendor/services/posted/${service.serviceId}'),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.brMd,
            child: SizedBox(
              width: 64,
              height: 64,
              child: AppNetworkImage(
                url: service.imageUrl,
                fallbackIcon: AppIcons.services,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSmall.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ExpirationBadge(info: exp),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  service.priceLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  service.category.label,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                        service.isAuthorized
                            ? Icons.verified
                            : Icons.schedule,
                        size: 14,
                        color: exp.color),
                    const SizedBox(width: 4),
                    Text(
                      exp.label,
                      style: AppTextStyles.labelSmall.copyWith(
                          color: exp.color,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: scheme.onSurfaceVariant),
            onSelected: (v) async {
              if (v == 'edit') {
                context.push('/vendor/service-form',
                    extra: service);
              } else if (v == 'delete') {
                final ok = await ConfirmActions.confirm(
                  context,
                  title: 'Delete service?',
                  message: 'Remove "${service.title}"?',
                  destructive: true,
                );
                if (ok == true) {
                  await ref
                      .read(vendorRepositoryProvider)
                      .deleteService(service.serviceId);
                  ref.invalidate(myServicesProvider);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(AppIcons.edit, size: 18),
                  SizedBox(width: 12),
                  Text('Edit'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== Expiration badge =====
class _ExpInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _ExpInfo(this.label, this.color, this.icon);
}

_ExpInfo _expirationInfo(Service s, bool freeMode) {
  if (s.isAuthorized) {
    return const _ExpInfo(
        'Authorized ✓', AppColors.success, Icons.verified);
  }
  if (freeMode) {
    return const _ExpInfo(
        'Live – Free Mode', AppColors.success, Icons.all_inclusive);
  }
  final d = s.daysLeft;
  if (d < 0) {
    return const _ExpInfo('Expired - renewal required',
        AppColors.error, Icons.error_outline);
  }
  if (d == 0) {
    return const _ExpInfo(
        'Expires today', AppColors.error, Icons.warning_amber_rounded);
  }
  if (d <= 2) {
    return _ExpInfo(
        'Expires in $d d', AppColors.error, Icons.timer_outlined);
  }
  if (d <= 7) {
    return _ExpInfo('$d d left', AppColors.warning, Icons.schedule);
  }
  return _ExpInfo(
      '$d d left', AppColors.success, Icons.check_circle_outline);
}

class _ExpirationBadge extends StatelessWidget {
  final _ExpInfo info;
  const _ExpirationBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
            color: info.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 12, color: info.color),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: info.color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
