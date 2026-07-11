import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(browseServicesProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.sm),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search products on your campus...',
                  prefixIcon: Icon(AppIcons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                    icon: Icon(AppIcons.close, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(productSearchProvider.notifier).state = '';
                      setState(() {});
                    },
                  ),
                ),
                onChanged: (v) {
                  ref.read(productSearchProvider.notifier).state = v;
                  setState(() {});
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  child: Text('Categories', 
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: categories.when(
                    data: (cats) => ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      children: [
                        _chip(
                          label: 'All Items',
                          selected: selectedCat == null,
                          onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
                        ),
                        ...cats.map((c) => _chip(
                          label: c.categoryName,
                          selected: selectedCat == c.categoryId,
                          onTap: () => ref.read(selectedCategoryProvider.notifier).state = c.categoryId,
                        )),
                      ],
                    ),
                    loading: () => AppShimmer(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: 5,
                        itemBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: SkeletonBox(width: 80, height: 36, radius: 20),
                        ),
                      ),
                    ),
                    error: (e, _) => const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
          products.when(
            data: (list) {
              final serviceList = services.valueOrNull ?? [];
              if (list.isEmpty && services.isLoading) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SkeletonList(itemCount: 3, itemHeight: 96),
                  ),
                );
              }
              if (list.isEmpty && serviceList.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_rounded,
                    title: 'No matches found',
                    subtitle: 'Try a different search or category.',
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  if (list.isNotEmpty) ...[
                    _sectionHeader(context, 'Products', list.length),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm + 4),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: AppSpacing.sm + 4,
                          crossAxisSpacing: AppSpacing.sm + 4,
                          childAspectRatio: 0.66,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) => ProductCard(
                          product: list[i],
                        )
                            .animate()
                            .fadeIn(
                              delay: (40 * (i % 8)).ms,
                              duration: 300.ms,
                            )
                            .slideY(begin: 0.06, end: 0),
                      ),
                    ),
                  ],
                  services.when(
                    data: (serviceList) {
                      if (serviceList.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Services', serviceList.length),
                          ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm + 4,
                              AppSpacing.sm,
                              AppSpacing.sm + 4,
                              AppSpacing.md,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: serviceList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) =>
                                ServiceCard(service: serviceList[i])
                                    .animate()
                                    .fadeIn(
                                      delay: (40 * (i % 8)).ms,
                                      duration: 300.ms,
                                    )
                                    .slideY(begin: 0.05, end: 0),
                          ),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SkeletonList(itemCount: 3, itemHeight: 96),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ]),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: SkeletonGrid(itemCount: 6, shrinkWrap: true),
            ),
            error: (e, _) => SliverFillRemaining(
              child: ErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(productsProvider)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.titleLarge),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '($count)',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected 
            ? Theme.of(context).colorScheme.onPrimary 
            : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
