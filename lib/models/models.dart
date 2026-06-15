import '../core/constants/app_constants.dart';

/// Lightweight immutable data models mapping to the Supabase tables.

double _toDouble(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int _toInt(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

class Campus {
  final String campusId;
  final String campusName;
  final String? location;
  final String status;

  Campus({
    required this.campusId,
    required this.campusName,
    this.location,
    this.status = 'active',
  });

  factory Campus.fromMap(Map<String, dynamic> m) => Campus(
    campusId: m['campus_id'] as String,
    campusName: m['campus_name'] as String,
    location: m['location'] as String?,
    status: (m['status'] as String?) ?? 'active',
  );
}

class AppUser {
  final String userId;
  final String fullName;
  final String email;
  final UserRole role;
  final String? campusId;
  final String? profileImage;
  final bool isSuspended;

  AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.campusId,
    this.profileImage,
    this.isSuspended = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    userId: m['user_id'] as String,
    fullName: (m['full_name'] as String?) ?? '',
    email: (m['email'] as String?) ?? '',
    role: UserRole.fromDb((m['role'] as String?) ?? 'student'),
    campusId: m['campus_id'] as String?,
    profileImage: m['profile_image'] as String?,
    isSuspended: (m['is_suspended'] as bool?) ?? false,
  );

  bool get needsCampus => campusId == null;
}

class Vendor {
  final String vendorId;
  final String userId;
  final String businessName;
  final String? ownerName;
  final String? phoneNumber;
  final String? businessPhone;
  final String? momoNumber;
  final String? momoNetwork;
  final String? ghanaCardNumber;
  final String? ghanaCardImageUrl;
  final String? logoUrl;
  final String? description;
  final ApprovalStatus approvalStatus;
  final String campusId;

  Vendor({
    required this.vendorId,
    required this.userId,
    required this.businessName,
    this.ownerName,
    this.phoneNumber,
    this.businessPhone,
    this.momoNumber,
    this.momoNetwork,
    this.ghanaCardNumber,
    this.ghanaCardImageUrl,
    this.logoUrl,
    this.description,
    required this.approvalStatus,
    required this.campusId,
  });

  factory Vendor.fromMap(Map<String, dynamic> m) => Vendor(
    vendorId: m['vendor_id'] as String,
    userId: m['user_id'] as String,
    businessName: (m['business_name'] as String?) ?? '',
    ownerName: m['owner_name'] as String?,
    phoneNumber: m['phone_number'] as String?,
    businessPhone: m['business_phone'] as String?,
    momoNumber: m['momo_number'] as String?,
    momoNetwork: m['momo_network'] as String?,
    ghanaCardNumber: m['ghana_card_number'] as String?,
    ghanaCardImageUrl: m['ghana_card_image_url'] as String?,
    logoUrl: m['logo_url'] as String?,
    description: m['description'] as String?,
    approvalStatus:
    ApprovalStatus.fromDb((m['approval_status'] as String?) ?? 'pending'),
    campusId: m['campus_id'] as String,
  );

  bool get isApproved => approvalStatus == ApprovalStatus.approved;
}

class Category {
  final String categoryId;
  final String categoryName;
  final String? description;

  Category({required this.categoryId, required this.categoryName, this.description});

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    categoryId: m['category_id'] as String,
    categoryName: (m['category_name'] as String?) ?? '',
    description: m['description'] as String?,
  );
}

class Product {
  final String productId;
  final String vendorId;
  final String? categoryId;
  final String productName;
  final String? description;
  final double price;
  final int quantityAvailable;
  final String? imageUrl; // cover image
  final List<String> images; // full gallery (joined)
  final String availabilityStatus;
  final String? vendorName; // joined
  final String? categoryName; // joined

  Product({
    required this.productId,
    required this.vendorId,
    this.categoryId,
    required this.productName,
    this.description,
    required this.price,
    required this.quantityAvailable,
    this.imageUrl,
    this.images = const [],
    this.availabilityStatus = 'available',
    this.vendorName,
    this.categoryName,
  });

  bool get isAvailable =>
      availabilityStatus == 'available' && quantityAvailable > 0;

  /// All gallery images, guaranteed to include the cover first if present.
  List<String> get gallery {
    final list = <String>[];
    if (images.isNotEmpty) {
      list.addAll(images);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty && !list.contains(imageUrl)) {
      list.insert(0, imageUrl!);
    }
    return list;
  }

  factory Product.fromMap(Map<String, dynamic> m) {
    final imgs = <String>[];
    if (m['product_images'] is List) {
      final raw = List<Map<String, dynamic>>.from(
          (m['product_images'] as List).map((e) => Map<String, dynamic>.from(e)));
      raw.sort((a, b) => _toInt(a['position']).compareTo(_toInt(b['position'])));
      imgs.addAll(raw
          .map((e) => e['image_url'] as String?)
          .whereType<String>());
    }
    return Product(
      productId: m['product_id'] as String,
      vendorId: m['vendor_id'] as String,
      categoryId: m['category_id'] as String?,
      productName: (m['product_name'] as String?) ?? '',
      description: m['description'] as String?,
      price: _toDouble(m['price']),
      quantityAvailable: _toInt(m['quantity_available']),
      imageUrl: m['image_url'] as String?,
      images: imgs,
      availabilityStatus: (m['availability_status'] as String?) ?? 'available',
      vendorName:
      m['vendors'] is Map ? m['vendors']['business_name'] as String? : null,
      categoryName: m['categories'] is Map
          ? m['categories']['category_name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
    'vendor_id': vendorId,
    'category_id': categoryId,
    'product_name': productName,
    'description': description,
    'price': price,
    'quantity_available': quantityAvailable,
    'image_url': imageUrl,
  };
}

class CartItem {
  final String cartItemId;
  final String cartId;
  final String productId;
  final int quantity;
  final Product? product; // joined

  CartItem({
    required this.cartItemId,
    required this.cartId,
    required this.productId,
    required this.quantity,
    this.product,
  });

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    cartItemId: m['cart_item_id'] as String,
    cartId: m['cart_id'] as String,
    productId: m['product_id'] as String,
    quantity: _toInt(m['quantity']),
    product: m['products'] is Map
        ? Product.fromMap(Map<String, dynamic>.from(m['products']))
        : null,
  );

  double get lineTotal => (product?.price ?? 0) * quantity;
}

class OrderItem {
  final String orderItemId;
  final String orderId;
  final String? productId;
  final int quantity;
  final double unitPrice;
  final String? productName; // joined
  final String? productImage; // joined

  OrderItem({
    required this.orderItemId,
    required this.orderId,
    this.productId,
    required this.quantity,
    required this.unitPrice,
    this.productName,
    this.productImage,
  });

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    orderItemId: m['order_item_id'] as String,
    orderId: m['order_id'] as String,
    productId: m['product_id'] as String?,
    quantity: _toInt(m['quantity']),
    unitPrice: _toDouble(m['unit_price']),
    productName: m['products'] is Map
        ? m['products']['product_name'] as String?
        : null,
    productImage: m['products'] is Map
        ? m['products']['image_url'] as String?
        : null,
  );

  double get lineTotal => unitPrice * quantity;
}

class AppOrder {
  final String orderId;
  final String studentId;
  final String vendorId;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String? vendorName; // joined
  final String? studentName; // joined
  final List<OrderItem> items;
  // delivery details
  final String? deliveryAddress;
  final String? contactPhone;
  final String? paymentMethod;
  final String? paymentStatus; // pending / paid / failed / refunded
  final String? note;
  final String? vendorMomoNumber;
  final String? vendorMomoNetwork;
  final DateTime? confirmedAt;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;

  AppOrder({
    required this.orderId,
    required this.studentId,
    required this.vendorId,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.vendorName,
    this.studentName,
    this.items = const [],
    this.deliveryAddress,
    this.contactPhone,
    this.paymentMethod,
    this.paymentStatus,
    this.note,
    this.vendorMomoNumber,
    this.vendorMomoNetwork,
    this.confirmedAt,
    this.dispatchedAt,
    this.deliveredAt,
  });

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  /// Human label for the chosen payment method.
  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'momo':
      case 'mobile_money':
      case 'paystack':
        return 'Mobile Money';
      case 'cash_on_delivery':
      default:
        return 'Pay on Delivery';
    }
  }

  bool get isPaid => paymentStatus == 'paid';

  /// Short label combining method + payment state, e.g. "Paystack · Paid".
  String get paymentSummary {
    if (paymentMethod == 'cash_on_delivery' || paymentMethod == null) {
      return 'Pay on Delivery';
    }
    return '$paymentMethodLabel · ${isPaid ? 'Paid' : 'Pending'}';
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse('$v')?.toLocal();

  factory AppOrder.fromMap(Map<String, dynamic> m) => AppOrder(
    orderId: m['order_id'] as String,
    studentId: m['student_id'] as String,
    vendorId: m['vendor_id'] as String,
    totalAmount: _toDouble(m['total_amount']),
    status: OrderStatus.fromDb((m['order_status'] as String?) ?? 'pending'),
    createdAt:
    DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    vendorName:
    m['vendors'] is Map ? m['vendors']['business_name'] as String? : null,
    studentName:
    m['users'] is Map ? m['users']['full_name'] as String? : null,
    items: m['order_items'] is List
        ? (m['order_items'] as List)
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
        .toList()
        : const [],
    deliveryAddress: m['delivery_address'] as String?,
    contactPhone: m['contact_phone'] as String?,
    paymentMethod: m['payment_method'] as String?,
    paymentStatus: m['payment_status'] as String?,
    note: m['note'] as String?,
    vendorMomoNumber: m['vendor_momo_number'] as String?,
    vendorMomoNetwork: m['vendor_momo_network'] as String?,
    confirmedAt: _date(m['confirmed_at']),
    dispatchedAt: _date(m['dispatched_at']),
    deliveredAt: _date(m['delivered_at']),
  );
}

/// Aggregated sales numbers for one of a vendor's products.
class ProductStat {
  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  ProductStat({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
  });

  factory ProductStat.fromMap(Map<String, dynamic> m) => ProductStat(
    productId: m['product_id'] as String,
    productName: (m['product_name'] as String?) ?? '',
    unitsSold: _toInt(m['units_sold']),
    revenue: _toDouble(m['revenue']),
  );
}

class AppNotification {
  final String notificationId;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.notificationId,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    notificationId: m['notification_id'] as String,
    title: (m['title'] as String?) ?? '',
    body: m['body'] as String?,
    isRead: (m['is_read'] as bool?) ?? false,
    createdAt:
    DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
  );
}

class Review {
  final String reviewId;
  final String studentId;
  final String vendorId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? studentName;

  Review({
    required this.reviewId,
    required this.studentId,
    required this.vendorId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.studentName,
  });

  factory Review.fromMap(Map<String, dynamic> m) => Review(
    reviewId: m['review_id'] as String,
    studentId: m['student_id'] as String,
    vendorId: m['vendor_id'] as String,
    rating: _toInt(m['rating']),
    comment: m['comment'] as String?,
    createdAt:
    DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    studentName:
    m['users'] is Map ? m['users']['full_name'] as String? : null,
  );
}
