import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/vendor_providers.dart';

class VendorProductsScreen extends ConsumerWidget {
  const VendorProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(myProductsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myProductsProvider),
      child: AsyncView<List<Product>>(
        value: products,
        onRetry: () => ref.invalidate(myProductsProvider),
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
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ProductTile(product: list[i]),
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
    final low = product.quantityAvailable <= 0;
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: product.imageUrl != null
                ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_outlined))
                : const Icon(Icons.fastfood_outlined),
          ),
        ),
        title: Text(product.productName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Text(Formatters.money(product.price)),
            const SizedBox(width: 10),
            Text('Qty: ${product.quantityAvailable}',
                style: TextStyle(color: low ? Colors.red : null)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
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
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => context.push('/vendor/product-form', extra: product),
      ),
    );
  }
}
