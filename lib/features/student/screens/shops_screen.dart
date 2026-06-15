import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search shops...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close),
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
            child: AsyncView<List<Vendor>>(
              value: shops,
              onRetry: () => ref.invalidate(shopsProvider),
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
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ShopCard(shop: list[i]),
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
    return Card(
      child: InkWell(
        onTap: () => context.push('/student/shop/${shop.vendorId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.primaryContainer,
                  image: hasLogo
                      ? DecorationImage(
                      image: NetworkImage(shop.logoUrl!),
                      fit: BoxFit.cover)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: hasLogo
                    ? null
                    : Icon(Icons.storefront,
                    color: scheme.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.businessName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    if (shop.description != null &&
                        shop.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(shop.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant)),
                    ] else if (shop.businessPhone != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.call_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(shop.businessPhone!,
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant)),
                      ]),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
