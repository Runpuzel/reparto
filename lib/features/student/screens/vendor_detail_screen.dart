import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';

final _vendorProvider =
FutureProvider.family<Vendor?, String>((ref, id) async {
  final data = await supabase
      .from('vendors')
      .select()
      .eq('vendor_id', id)
      .maybeSingle();
  return data == null ? null : Vendor.fromMap(Map<String, dynamic>.from(data));
});

final _vendorProductsProvider =
FutureProvider.family<List<Product>, String>((ref, id) async {
  final rows = await supabase
      .from('products')
      .select()
      .eq('vendor_id', id)
      .eq('availability_status', 'available')
      .order('created_at', ascending: false);
  return (rows as List)
      .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

class VendorDetailScreen extends ConsumerWidget {
  final String vendorId;
  const VendorDetailScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(_vendorProvider(vendorId));
    final products = ref.watch(_vendorProductsProvider(vendorId));
    final reviews = ref.watch(vendorReviewsProvider(vendorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor')),
      body: vendor.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (v) {
          if (v == null) return const Center(child: Text('Vendor not found'));
          final revs = reviews.valueOrNull ?? [];
          final avg = revs.isEmpty
              ? 0.0
              : revs.map((r) => r.rating).reduce((a, b) => a + b) / revs.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.storefront, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.businessName,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (revs.isNotEmpty)
                          Row(children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            Text(
                                ' ${avg.toStringAsFixed(1)} (${revs.length})'),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Products',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...((products.valueOrNull ?? []).map((p) => Card(
                child: ListTile(
                  title: Text(p.productName),
                  subtitle: Text('${p.quantityAvailable} in stock'),
                  trailing: Text(Formatters.money(p.price),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  onTap: () {},
                ),
              ))),
              const SizedBox(height: 20),
              Text('Reviews',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (revs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No reviews yet.'),
                )
              else
                ...revs.map((r) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(
                            (r.studentName ?? '?')[0].toUpperCase())),
                    title: Row(
                      children: List.generate(
                        5,
                            (i) => Icon(
                            i < r.rating ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber),
                      ),
                    ),
                    subtitle: Text(r.comment ?? ''),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}
