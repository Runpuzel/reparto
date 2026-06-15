import '../../../core/config/supabase_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/models.dart';

/// Data access for the vendor experience: products, inventory, orders, sales.
class VendorRepository {
  Future<List<Product>> fetchMyProducts(String vendorId) async {
    final rows = await supabase
        .from('products')
        .select('*, product_images(image_url, position)')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Creates or updates a product and replaces its gallery with [imageUrls].
  /// The first image is also stored as the cover (`products.image_url`).
  Future<void> upsertProduct(
      Map<String, dynamic> data, {
        String? productId,
        List<String>? imageUrls,
      }) async {
    final cover = (imageUrls != null && imageUrls.isNotEmpty)
        ? imageUrls.first
        : data['image_url'];
    final payload = {...data, 'image_url': cover};

    String id;
    if (productId == null) {
      final inserted = await supabase
          .from('products')
          .insert(payload)
          .select('product_id')
          .single();
      id = inserted['product_id'] as String;
    } else {
      await supabase.from('products').update(payload).eq('product_id', productId);
      id = productId;
    }

    if (imageUrls != null) {
      // Replace the gallery atomically (simple delete + reinsert).
      await supabase.from('product_images').delete().eq('product_id', id);
      if (imageUrls.isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        for (var i = 0; i < imageUrls.length; i++) {
          rows.add({
            'product_id': id,
            'image_url': imageUrls[i],
            'position': i,
          });
        }
        await supabase.from('product_images').insert(rows);
      }
    }
  }

  Future<void> deleteProduct(String productId) async {
    await supabase.from('products').delete().eq('product_id', productId);
  }

  Future<List<AppOrder>> fetchOrders(String vendorId) async {
    final rows = await supabase
        .from('orders')
        .select(
        '*, users(full_name), order_items(*, products(product_name, image_url))')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => AppOrder.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await supabase
        .from('orders')
        .update({'order_status': status.db}).eq('order_id', orderId);
  }

  /// Per-product sales stats (units sold + revenue) via RPC.
  Future<List<ProductStat>> fetchProductStats(String vendorId) async {
    final rows = await supabase
        .rpc('vendor_product_stats', params: {'p_vendor_id': vendorId});
    return (rows as List)
        .map((e) => ProductStat.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Customer reviews for the shop, with average + count.
  Future<List<Review>> fetchReviews(String vendorId) async {
    final rows = await supabase
        .from('reviews')
        .select('*, users(full_name)')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Review.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Simple sales summary computed client-side from completed orders.
  Future<SalesSummary> fetchSalesSummary(String vendorId) async {
    final rows = await supabase
        .from('orders')
        .select('total_amount, order_status')
        .eq('vendor_id', vendorId);
    double revenue = 0;
    int completed = 0, pending = 0, total = 0;
    for (final r in rows as List) {
      total++;
      final status = r['order_status'] as String;
      if (status == 'completed' || status == 'delivered') {
        completed++;
        revenue += (r['total_amount'] as num).toDouble();
      } else if (status == 'pending') {
        pending++;
      }
    }
    return SalesSummary(
      totalOrders: total,
      completedOrders: completed,
      pendingOrders: pending,
      revenue: revenue,
    );
  }
}

class SalesSummary {
  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;
  final double revenue;
  SalesSummary({
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.revenue,
  });
}
