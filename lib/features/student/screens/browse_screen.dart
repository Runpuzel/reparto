import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/student_providers.dart';
import '../widgets/product_card.dart';
import '../widgets/service_card.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchCtrl = TextEditingController();
  _ListingFilter _listingFilter = _ListingFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final services = ref.watch(browseServicesProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final search = ref.watch(productSearchProvider);

    if (_searchCtrl.text != search) {
      _searchCtrl.value = TextEditingValue(
        text: search,
        selection: TextSelection.collapsed(offset: search.length),
      );
    }

    return RefreshIndicator(
      edgeOffset: 8,
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(browseServicesProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child:
                _SearchPanel(
                      controller: _searchCtrl,
                      query: search,
                      onChanged: (value) {
                        ref.read(productSearchProvider.notifier).state = value;
                        setState(() {});
                      },
                      onClear: () {
                        _searchCtrl.clear();
                        ref.read(productSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                    )
                    .animate()
                    .fadeIn(delay: 80.ms, duration: 260.ms)
                    .slideY(begin: 0.04, end: 0),
          ),
          SliverToBoxAdapter(
            child: _ListingFilterBar(
              selected: _listingFilter,
              onSelected: (filter) => setState(() => _listingFilter = filter),
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryRail(
              categories: categories,
              selectedCategory: selectedCat,
              onSelected: (categoryId) {
                ref.read(selectedCategoryProvider.notifier).state = categoryId;
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
          ..._contentSlivers(context, products, services, _listingFilter),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    AsyncValue<List<Product>> products,
    AsyncValue<List<Service>> services,
    _ListingFilter filter,
  ) {
    if (filter == _ListingFilter.products) {
      return products.when(
        data: (items) => items.isEmpty
            ? const [_NoListingsFound()]
            : [SliverToBoxAdapter(child: _ProductSection(products: items))],
        loading: () => const [
          SliverToBoxAdapter(child: _LoadingProductSection()),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            child: ErrorState(
              error: error,
              onRetry: () => ref.invalidate(productsProvider),
            ),
          ),
        ],
      );
    }

    if (filter == _ListingFilter.services) {
      return services.when(
        data: (items) => items.isEmpty
            ? const [_NoListingsFound()]
            : [SliverToBoxAdapter(child: _ServiceSection(services: items))],
        loading: () => const [
          SliverToBoxAdapter(child: _LoadingServiceSection()),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            child: ErrorState(
              error: error,
              onRetry: () => ref.invalidate(browseServicesProvider),
            ),
          ),
        ],
      );
    }

    return products.when(
      data: (productList) {
        final serviceList = services.valueOrNull ?? const <Service>[];

        if (productList.isEmpty && services.isLoading) {
          return const [SliverToBoxAdapter(child: _LoadingServiceSection())];
        }

        if (productList.isEmpty && serviceList.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_rounded,
                title: 'No matches found',
                subtitle: 'Try a different search or category.',
              ),
            ),
          ];
        }

        return [
          SliverToBoxAdapter(
            child: _BalancedListingFeed(
              products: productList,
              services: serviceList,
              servicesLoading: services.isLoading,
            ),
          ),
        ];
      },
      loading: () => [
        if ((services.valueOrNull ?? const <Service>[]).isNotEmpty)
          SliverToBoxAdapter(
            child: _ServiceSection(services: services.valueOrNull!),
          )
        else
          const SliverToBoxAdapter(child: _LoadingProductSection()),
      ],
      error: (error, _) {
        final serviceList = services.valueOrNull ?? const <Service>[];
        if (serviceList.isNotEmpty) {
          return [
            SliverToBoxAdapter(
              child: _ServiceSection(services: serviceList),
            ),
          ];
        }
        return [
          SliverFillRemaining(
            child: ErrorState(
              error: error,
              onRetry: () => ref.invalidate(productsProvider),
            ),
          ),
        ];
      },
    );
  }
}

enum _ListingFilter { all, products, services }

class _ListingFilterBar extends StatelessWidget {
  const _ListingFilterBar({required this.selected, required this.onSelected});

  final _ListingFilter selected;
  final ValueChanged<_ListingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_ListingFilter>(
          segments: const [
            ButtonSegment(
              value: _ListingFilter.all,
              icon: Icon(AppIcons.grid),
              label: Text('All'),
            ),
            ButtonSegment(
              value: _ListingFilter.products,
              icon: Icon(AppIcons.bag),
              label: Text('Products'),
            ),
            ButtonSegment(
              value: _ListingFilter.services,
              icon: Icon(AppIcons.services),
              label: Text('Services'),
            ),
          ],
          selected: {selected},
          showSelectedIcon: false,
          onSelectionChanged: (value) => onSelected(value.first),
        ),
      ),
    );
  }
}

class _NoListingsFound extends SliverFillRemaining {
  const _NoListingsFound()
      : super(
          hasScrollBody: false,
          child: const EmptyState(
            icon: Icons.search_rounded,
            title: 'No matches found',
            subtitle: 'Try a different search or category.',
          ),
        );
}

class _BalancedListingFeed extends StatelessWidget {
  const _BalancedListingFeed({
    required this.products,
    required this.services,
    required this.servicesLoading,
  });

  final List<Product> products;
  final List<Service> services;
  final bool servicesLoading;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _SectionHeader(
        icon: AppIcons.grid,
        title: 'All listings',
        subtitle: 'Products and services available now',
        count: products.length + services.length,
      ),
      const SizedBox(height: AppSpacing.sm),
    ];

    var productIndex = 0;
    var serviceIndex = 0;
    while (productIndex < products.length || serviceIndex < services.length) {
      if (productIndex < products.length) {
        final end = productIndex + 2 < products.length
            ? productIndex + 2
            : products.length;
        children.add(
          _ProductGrid(products: products.sublist(productIndex, end)),
        );
        productIndex = end;
      }
      if (serviceIndex < services.length) {
        children.add(const SizedBox(height: AppSpacing.md));
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ServiceCard(service: services[serviceIndex]),
          ),
        );
        serviceIndex++;
      }
      if (productIndex < products.length || serviceIndex < services.length) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
    }

    if (servicesLoading) {
      children.add(const _LoadingServiceSection());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
          boxShadow: AppShadows.level2,
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search products and services...',
            prefixIcon: Icon(AppIcons.search, size: 21),
            suffixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: query.isEmpty
                  ? const SizedBox(key: ValueKey('empty'), width: 48)
                  : IconButton(
                      key: const ValueKey('clear'),
                      tooltip: 'Clear search',
                      icon: Icon(AppIcons.close, size: 20),
                      onPressed: onClear,
                    ),
            ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final AsyncValue<List<Category>> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Shop by category',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    selectedCategory == null ? 'All listings' : 'Filtered',
                    key: ValueKey(selectedCategory == null),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: categories.when(
              data: (items) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  _CategoryPill(
                    label: 'All Items',
                    selected: selectedCategory == null,
                    icon: AppIcons.grid,
                    onTap: () => onSelected(null),
                  ),
                  ...items.map(
                    (category) => _CategoryPill(
                      label: category.categoryName,
                      selected: selectedCategory == category.categoryId,
                      icon: AppIcons.tag,
                      onTap: () => onSelected(category.categoryId),
                    ),
                  ),
                ],
              ),
              loading: () => AppShimmer(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: 5,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: SkeletonBox(width: 96, height: 36, radius: 100),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedScale(
        scale: selected ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brFull,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brFull,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : scheme.surfaceContainerLow.withValues(alpha: 0.88),
                borderRadius: AppRadius.brFull,
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.76),
                ),
                boxShadow: selected ? AppShadows.brand : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? AppIcons.checkFill : icon,
                    size: 15,
                    color: foreground,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: AppIcons.bag,
          title: 'Products',
          subtitle: 'Fresh listings from campus sellers',
          count: products.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ProductGrid(products: products),
      ],
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 1180
              ? 5
              : width >= 900
              ? 4
              : width >= 620
              ? 3
              : 2;
          final ratio = width < 380
              ? 0.60
              : width >= 900
              ? 0.68
              : 0.64;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.sm + 6,
              childAspectRatio: ratio,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) =>
                ProductCard(product: products[index])
                    .animate()
                    .fadeIn(delay: (35 * (index % 10)).ms, duration: 280.ms)
                    .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

class _ServiceSection extends StatelessWidget {
  const _ServiceSection({required this.services});

  final List<Service> services;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: AppIcons.services,
            title: 'Services',
            subtitle: 'Skilled help from students and shops',
            count: services.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 760) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 124,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                    itemCount: services.length,
                    itemBuilder: (context, index) =>
                        ServiceCard(service: services[index])
                            .animate()
                            .fadeIn(
                              delay: (40 * (index % 8)).ms,
                              duration: 280.ms,
                            )
                            .slideY(begin: 0.04, end: 0),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      ServiceCard(service: services[index])
                          .animate()
                          .fadeIn(
                            delay: (40 * (index % 8)).ms,
                            duration: 280.ms,
                          )
                          .slideY(begin: 0.04, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: scheme.primary, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.56),
              borderRadius: AppRadius.brFull,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.labelMedium.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingProductSection extends StatelessWidget {
  const _LoadingProductSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SkeletonGrid(itemCount: 6, shrinkWrap: true),
    );
  }
}

class _LoadingServiceSection extends StatelessWidget {
  const _LoadingServiceSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SkeletonList(itemCount: 3, itemHeight: 104),
    );
  }
}
