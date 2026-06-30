import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';

/// Data access for the student experience: browsing, cart, orders, reviews.
/// Campus isolation is enforced by RLS; queries here stay simple.
class StudentRepository {
  Future<List<Product>> fetchProducts({String? categoryId, String? search}) async {
    var query = supabase
        .from('products')
        .select(
        '*, vendors(business_name, approval_status, campus_id), product_images(image_url, position)')
        .eq('availability_status', 'available')
        .gt('quantity_available', 0);

    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('product_name', '%${search.trim()}%');
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// All approved shops on the student's campus (RLS scopes to campus).
  Future<List<Vendor>> fetchVendors({String? search}) async {
    var query = supabase
        .from('vendors')
        .select()
        .eq('approval_status', 'approved');
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('business_name', '%${search.trim()}%');
    }
    final rows = await query.order('business_name');
    return (rows as List)
        .map((e) => Vendor.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// A single shop's details.
  Future<Vendor?> fetchVendor(String vendorId) async {
    final data = await supabase
        .from('vendors')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();
    return data == null ? null : Vendor.fromMap(Map<String, dynamic>.from(data));
  }

  /// All available products belonging to a specific shop.
  Future<List<Product>> fetchProductsByVendor(String vendorId,
      {String? search, String? categoryId}) async {
    var query = supabase
        .from('products')
        .select(
        '*, vendors(business_name), product_images(image_url, position)')
        .eq('vendor_id', vendorId)
        .eq('availability_status', 'available')
        .gt('quantity_available', 0);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('product_name', '%${search.trim()}%');
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Cart -----------------------------------------------------------------
  Future<String> _cartId() async {
    final res = await supabase.rpc('get_or_create_cart');
    return res as String;
  }

  Future<List<CartItem>> fetchCart() async {
    final cartId = await _cartId();
    final rows = await supabase
        .from('cart_items')
        .select('*, products(*)')
        .eq('cart_id', cartId);
    return (rows as List)
        .map((e) => CartItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addToCart(String productId, {int quantity = 1}) async {
    final cartId = await _cartId();
    final existing = await supabase
        .from('cart_items')
        .select()
        .eq('cart_id', cartId)
        .eq('product_id', productId)
        .maybeSingle();
    if (existing == null) {
      await supabase.from('cart_items').insert({
        'cart_id': cartId,
        'product_id': productId,
        'quantity': quantity,
      });
    } else {
      await supabase
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity})
          .eq('cart_item_id', existing['cart_item_id']);
    }
  }

  Future<void> updateCartQuantity(String cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }
    await supabase
        .from('cart_items')
        .update({'quantity': quantity}).eq('cart_item_id', cartItemId);
  }

  Future<void> removeFromCart(String cartItemId) async {
    await supabase.from('cart_items').delete().eq('cart_item_id', cartItemId);
  }

  /// Reduce a product's cart quantity by [amount] (used for "undo add").
  /// Removes the line entirely if the quantity drops to zero or below.
  Future<void> decrementCartItem(String productId, int amount) async {
    final cartId = await _cartId();
    final existing = await supabase
        .from('cart_items')
        .select()
        .eq('cart_id', cartId)
        .eq('product_id', productId)
        .maybeSingle();
    if (existing == null) return;
    final newQty = (existing['quantity'] as int) - amount;
    if (newQty <= 0) {
      await supabase
          .from('cart_items')
          .delete()
          .eq('cart_item_id', existing['cart_item_id']);
    } else {
      await supabase
          .from('cart_items')
          .update({'quantity': newQty}).eq('cart_item_id', existing['cart_item_id']);
    }
  }

  /// Server-side, transactional checkout (legacy, no delivery details).
  Future<void> placeOrder() async {
    await supabase.rpc('place_order_from_cart');
  }

  /// Checkout with delivery address, contact phone and payment method.
  Future<void> placeOrderWithDelivery({
    required String deliveryAddress,
    required String contactPhone,
    required String paymentMethod,
    String? note,
  }) async {
    await supabase.rpc('place_order_checkout', params: {
      'p_delivery_address': deliveryAddress,
      'p_contact_phone': contactPhone,
      'p_payment_method': paymentMethod,
      'p_note': note,
    });
  }

  /// A student may cancel their own pending order (allowed by RLS).
  Future<void> cancelOwnOrder(String orderId) async {
    await supabase
        .from('orders')
        .update({'order_status': 'cancelled'}).eq('order_id', orderId);
  }

  // ---- Orders ---------------------------------------------------------------
  Future<List<AppOrder>> fetchMyOrders() async {
    final uid = currentAuthUser!.id;
    final rows = await supabase
        .from('orders')
        .select(
        '*, vendors(business_name), order_items(*, products(product_name, image_url))')
        .eq('student_id', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => AppOrder.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AppOrder?> fetchOrder(String orderId) async {
    final data = await supabase
        .from('orders')
        .select(
        '*, vendors(business_name), order_items(*, products(product_name, image_url))')
        .eq('order_id', orderId)
        .maybeSingle();
    return data == null
        ? null
        : AppOrder.fromMap(Map<String, dynamic>.from(data));
  }

  // ---- Favorites ------------------------------------------------------------
  Future<List<Product>> fetchFavorites() async {
    final uid = currentAuthUser!.id;
    final rows = await supabase
        .from('favorites')
        .select(
        'product_id, products(*, vendors(business_name), product_images(image_url, position))')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .where((e) => e['products'] != null)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e['products'])))
        .toList();
  }

  Future<Set<String>> fetchFavoriteIds() async {
    final uid = currentAuthUser!.id;
    final rows =
    await supabase.from('favorites').select('product_id').eq('user_id', uid);
    return (rows as List).map((e) => e['product_id'] as String).toSet();
  }

  Future<void> toggleFavorite(String productId, bool makeFavorite) async {
    final uid = currentAuthUser!.id;
    if (makeFavorite) {
      await supabase.from('favorites').upsert({
        'user_id': uid,
        'product_id': productId,
      });
    } else {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('product_id', productId);
    }
  }

  // ---- Reviews --------------------------------------------------------------
  Future<List<Review>> fetchVendorReviews(String vendorId) async {
    final rows = await supabase
        .from('reviews')
        .select('*, users(full_name)')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Review.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> submitReview({
    required String vendorId,
    required int rating,
    String? comment,
    String? orderId,
  }) async {
    await supabase.from('reviews').insert({
      'student_id': currentAuthUser!.id,
      'vendor_id': vendorId,
      'rating': rating,
      'comment': comment,
      'order_id': orderId,
    });
  }

  // ---- Services -------------------------------------------------------------
  /// Available services of approved sellers (RLS scopes by campus / guest).
  Future<List<Service>> fetchServices({String? category, String? search}) async {
    var query = supabase
        .from('services')
        .select('*, vendors(business_name), service_images(image_url, position)')
        .eq('status', 'available');
    if (category != null) query = query.eq('category', category);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('title', '%${search.trim()}%');
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Service.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Service?> fetchService(String serviceId) async {
    final data = await supabase
        .from('services')
        .select('*, vendors(business_name), service_images(image_url, position)')
        .eq('service_id', serviceId)
        .maybeSingle();
    return data == null ? null : Service.fromMap(Map<String, dynamic>.from(data));
  }

  // ---- Escrow / disputes (spec Section C) -----------------------------------
  /// Buyer confirms receipt → releases payment to the seller (status completed).
  Future<void> confirmReceipt(String orderId) async {
    await supabase.rpc('confirm_receipt', params: {'p_order': orderId});
  }

  /// Raise a dispute on an order.
  Future<void> raiseDispute({
    required String orderId,
    required String category,
    required String description,
    List<String>? evidence,
  }) async {
    await supabase.rpc('raise_dispute', params: {
      'p_order': orderId,
      'p_category': category,
      'p_description': description,
      'p_evidence': evidence,
    });
  }
}
