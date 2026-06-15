import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/student_providers.dart';
import '../widgets/product_card.dart';

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
    final categories = ref.watch(categoriesProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(productsProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search products on your campus...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close),
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
            child: SizedBox(
              height: 44,
              child: categories.when(
                data: (cats) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip(
                      label: 'All',
                      selected: selectedCat == null,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = null,
                    ),
                    ...cats.map((c) => _chip(
                      label: c.categoryName,
                      selected: selectedCat == c.categoryId,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = c.categoryId,
                    )),
                  ],
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          products.when(
            data: (list) {
              if (list.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products found',
                    subtitle: 'Try a different search or category.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => ProductCard(product: list[i]),
                    childCount: list.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
              child: ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(productsProvider)),
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
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
