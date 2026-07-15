import '../../../core/config/supabase_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/models.dart';

/// Data access for the vendor experience: products, inventory, orders, sales.
class VendorRepository {
  Future<VendorWallet> fetchWallet(String vendorId) async {
    final wallet = await supabase
        .from('vendor_wallets')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();
    final rows = await supabase
        .from('wallet_transactions')
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false)
        .limit(50);
    return VendorWallet(
      availablePesewas: (wallet?['available_pesewas'] as num?)?.toInt() ?? 0,
      reservedPesewas: (wallet?['reserved_pesewas'] as num?)?.toInt() ?? 0,
      transactions: (rows as List)
          .map((row) =>
              WalletTransaction.fromMap(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }

  Future<PlatformSetting> fetchPlatformSettings() async {
    final row = await supabase
        .from('platform_settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      throw StateError(
          'Marketplace fee settings are unavailable. Contact support.');
    }
    return PlatformSetting.fromMap(Map<String, dynamic>.from(row));
  }

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
  Future<String> upsertProduct(
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
      await supabase
          .from('products')
          .update(payload)
          .eq('product_id', productId);
      id = productId;
    }

    if (imageUrls != null) {
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
    return id;
  }

  Future<void> deleteProduct(String productId) async {
    await supabase.from('products').delete().eq('product_id', productId);
  }

  // ---- Services -------------------------------------------------------------
  Future<List<Service>> fetchMyServices(String vendorId) async {
    final rows = await supabase
        .from('services')
        .select(
            '*, vendors(business_name), service_images(image_url, position)')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Service.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> activeServiceCount(String vendorId) async {
    final rows = await supabase
        .from('services')
        .select('service_id')
        .eq('vendor_id', vendorId)
        .eq('status', 'available');
    return (rows as List).length;
  }

  Future<String> upsertService(
    Map<String, dynamic> data, {
    String? serviceId,
    List<String>? imageUrls,
  }) async {
    final cover = (imageUrls != null && imageUrls.isNotEmpty)
        ? imageUrls.first
        : data['image_url'];
    final payload = {...data, 'image_url': cover};

    String id;
    if (serviceId == null) {
      final inserted = await supabase
          .from('services')
          .insert(payload)
          .select('service_id')
          .single();
      id = inserted['service_id'] as String;
    } else {
      await supabase
          .from('services')
          .update(payload)
          .eq('service_id', serviceId);
      id = serviceId;
    }

    if (imageUrls != null) {
      await supabase.from('service_images').delete().eq('service_id', id);
      if (imageUrls.isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        for (var i = 0; i < imageUrls.length; i++) {
          rows.add({
            'service_id': id,
            'image_url': imageUrls[i],
            'position': i,
          });
        }
        await supabase.from('service_images').insert(rows);
      }
    }
    return id;
  }

  Future<void> deleteService(String serviceId) async {
    await supabase.from('services').delete().eq('service_id', serviceId);
  }

  Future<void> updateServiceStatus(String serviceId, String status) async {
    await supabase
        .from('services')
        .update({'status': status}).eq('service_id', serviceId);
  }

  Future<void> authorizeService(String serviceId) async {
    await supabase.rpc('authorize_service_from_wallet', params: {
      'p_service': serviceId,
    });
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

  Future<List<ProductStat>> fetchProductStats(String vendorId) async {
    final rows = await supabase
        .rpc('vendor_product_stats', params: {'p_vendor_id': vendorId});
    return (rows as List)
        .map((e) => ProductStat.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

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

  Future<SalesSummary> fetchSalesSummary(String vendorId) async {
    final rows = await supabase
        .from('orders')
        .select('total_amount, order_status')
        .eq('vendor_id', vendorId);
    double revenue = 0;
    int completed = 0, active = 0, cancelled = 0, total = 0;
    for (final r in rows as List) {
      total++;
      final status = r['order_status'] as String;
      if (status == 'completed' || status == 'delivered') {
        completed++;
        revenue += (r['total_amount'] as num).toDouble();
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        active++;
      }
    }
    return SalesSummary(
      totalOrders: total,
      completedOrders: completed,
      activeOrders: active,
      cancelledOrders: cancelled,
      revenue: revenue,
    );
  }

  Future<void> recordSellerConsent(
      String vendorId, Map<String, dynamic> metadata) async {
    await supabase.from('vendors').update({
      'consent_seller_agreement': true,
      'consent_seller_agreement_at': DateTime.now().toIso8601String(),
      'consent_seller_agreement_version':
          metadata['consent_seller_agreement_version'] ?? 'v1.0-2025-07',
    }).eq('vendor_id', vendorId);

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await supabase.from('consent_records').insert({
        'user_id': userId,
        'consent_type': 'seller_agreement',
        'policy_version': metadata['policy_version'] ?? 'v1.0-2025-07',
        'metadata': metadata,
      });
    }
  }

  /// Updates all vendor profile details.
  Future<void> updateStoreDetails(Map<String, dynamic> payload) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw 'User session expired';
    // Update the vendors table directly
    await supabase.from('vendors').update(payload).eq('user_id', uid);
  }

  Future<void> submitVerification(Map<String, dynamic> data) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw 'User session expired';
    await supabase.rpc('vendor_submit_verification', params: {
      'p_payload': data,
    });
  }
}

class SalesSummary {
  final int totalOrders;
  final int completedOrders;
  final int activeOrders;
  final int cancelledOrders;
  final double revenue;
  SalesSummary({
    required this.totalOrders,
    required this.completedOrders,
    required this.activeOrders,
    required this.cancelledOrders,
    required this.revenue,
  });

  double get averageCompletedOrder =>
      completedOrders == 0 ? 0 : revenue / completedOrders;

  double get completionRate =>
      totalOrders == 0 ? 0 : completedOrders / totalOrders;
}

class VendorWallet {
  const VendorWallet({
    required this.availablePesewas,
    required this.reservedPesewas,
    required this.transactions,
  });
  final int availablePesewas;
  final int reservedPesewas;
  final List<WalletTransaction> transactions;
}

class WalletTransaction {
  const WalletTransaction({
    required this.kind,
    required this.amountPesewas,
    required this.description,
    required this.createdAt,
  });
  final String kind;
  final int amountPesewas;
  final String description;
  final DateTime createdAt;

  factory WalletTransaction.fromMap(Map<String, dynamic> map) =>
      WalletTransaction(
        kind: map['kind'] as String,
        amountPesewas: (map['amount_pesewas'] as num).toInt(),
        description: map['description'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
