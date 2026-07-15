// lib/models/models.dart
// Campus Marketplace – v1.0-2025-07
// Merged: 0001_schema + 0006_feature_upgrades + 0019_store_verification
// Backward compatible – all legacy fields retained

import '../core/constants/app_constants.dart';
import '../core/utils/money.dart';

double toDouble(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int toInt(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
DateTime? date(dynamic v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();
DateTime? calendarDate(dynamic v) {
  if (v == null) return null;
  final parsed = DateTime.tryParse('$v');
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
List<String> toStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => '$e').toList();
  return [];
}

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
  final String? referralCode;
  AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.campusId,
    this.profileImage,
    this.isSuspended = false,
    this.referralCode,
  });
  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    userId: m['user_id'] as String,
    fullName: (m['full_name'] as String?) ?? '',
    email: (m['email'] as String?) ?? '',
    role: UserRole.fromDb((m['role'] as String?) ?? 'student'),
    campusId: m['campus_id'] as String?,
    profileImage: m['profile_image'] as String?,
    isSuspended: (m['is_suspended'] as bool?) ?? false,
    referralCode: m['referral_code'] as String?,
  );
  bool get needsCampus => campusId == null;
}

// ===== VENDOR – v1.0 extended – backward compatible =====
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

  // v1.0 store profile
  final String? storeName;
  final String? storeDescription;
  final String? storeLocation;
  final String? storePhone;
  final String? whatsappNumber;
  final String? hallHostel;
  final double? gpsLat;
  final double? gpsLng;
  final List<String> workingDays;
  final String? openingTime;
  final String? closingTime;
  final bool isClosedToday;
  final DateTime? closedTodayDate;
  final bool holidayMode;
  final int deliveryRadiusKm;
  final String? sellerBio;
  final String? programYear;
  final List<String> specialties;
  final String? customNote;
  final bool profileCompleted;

  // v1.0 verification
  final bool isVerified;
  final String? verificationType;
  final String? verificationIdNumber;
  final String? verificationFrontUrl;
  final String? verificationBackUrl;
  final String? verificationSelfieUrl;
  final String verificationStatus;
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationApprovedAt;
  final String? verificationRejectedReason;

  // platform
  final double platformFeeRate;
  final bool consentSellerAgreement;
  final DateTime? consentSellerAgreementAt;
  final String? consentSellerAgreementVersion;

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
    this.storeName,
    this.storeDescription,
    this.storeLocation,
    this.storePhone,
    this.whatsappNumber,
    this.hallHostel,
    this.gpsLat,
    this.gpsLng,
    this.workingDays = const ['Mon','Tue','Wed','Thu','Fri'],
    this.openingTime = '08:00:00',
    this.closingTime = '20:00:00',
    this.isClosedToday = false,
    this.closedTodayDate,
    this.holidayMode = false,
    this.deliveryRadiusKm = 2,
    this.sellerBio,
    this.programYear,
    this.specialties = const [],
    this.customNote,
    this.profileCompleted = false,
    this.isVerified = false,
    this.verificationType,
    this.verificationIdNumber,
    this.verificationFrontUrl,
    this.verificationBackUrl,
    this.verificationSelfieUrl,
    this.verificationStatus = 'unverified',
    this.verificationSubmittedAt,
    this.verificationApprovedAt,
    this.verificationRejectedReason,
    this.platformFeeRate = 5.0,
    this.consentSellerAgreement = false,
    this.consentSellerAgreementAt,
    this.consentSellerAgreementVersion,
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
    approvalStatus: ApprovalStatus.fromDb((m['approval_status'] as String?) ?? 'pending'),
    campusId: m['campus_id'] as String,
    storeName: (m['store_name'] as String?) ?? m['business_name'] as String?,
    storeDescription: m['store_description'] as String?,
    storeLocation: m['store_location'] as String?,
    storePhone: m['store_phone'] as String?,
    whatsappNumber: m['whatsapp_number'] as String?,
    hallHostel: m['hall_hostel'] as String?,
    gpsLat: m['gps_lat'] == null ? null : toDouble(m['gps_lat']),
    gpsLng: m['gps_lng'] == null ? null : toDouble(m['gps_lng']),
    workingDays: toStringList(m['working_days']).isEmpty ? ['Mon','Tue','Wed','Thu','Fri'] : toStringList(m['working_days']),
    openingTime: m['opening_time'] as String? ?? '08:00:00',
    closingTime: m['closing_time'] as String? ?? '20:00:00',
    isClosedToday: m['is_closed_today'] as bool? ?? false,
    closedTodayDate: calendarDate(m['closed_today_date']),
    holidayMode: m['holiday_mode'] as bool? ?? false,
    deliveryRadiusKm: toInt(m['delivery_radius_km'] ?? 2),
    sellerBio: m['seller_bio'] as String?,
    programYear: m['program_year'] as String?,
    specialties: toStringList(m['specialties']),
    customNote: m['custom_note'] as String?,
    profileCompleted: m['profile_completed'] as bool? ?? false,
    isVerified: m['is_verified'] as bool? ?? false,
    verificationType: m['verification_type'] as String?,
    verificationIdNumber: m['verification_id_number'] as String?,
    verificationFrontUrl: m['verification_front_url'] as String?,
    verificationBackUrl: m['verification_back_url'] as String?,
    verificationSelfieUrl: m['verification_selfie_url'] as String?,
    verificationStatus: (m['verification_status'] as String?) ?? 'unverified',
    verificationSubmittedAt: date(m['verification_submitted_at']),
    verificationApprovedAt: date(m['verification_approved_at']),
    verificationRejectedReason: m['verification_rejected_reason'] as String?,
    platformFeeRate: toDouble(m['platform_fee_rate'] ?? 5.0),
    consentSellerAgreement: m['consent_seller_agreement'] as bool? ?? false,
    consentSellerAgreementAt: date(m['consent_seller_agreement_at']),
    consentSellerAgreementVersion: m['consent_seller_agreement_version'] as String?,
  );

  bool get isApproved => approvalStatus == ApprovalStatus.approved;
  bool get hasPayoutDetails {
    final number = momoNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final network = momoNetwork
            ?.toLowerCase()
            .replaceAll(RegExp(r'[^a-z]'), '') ??
        '';
    const supportedNetworks = {
      'mtn',
      'vodafone',
      'telecel',
      'airteltigo',
    };
    return number.length == 10 &&
        number.startsWith('0') &&
        supportedNetworks.contains(network);
  }

  bool get canAcceptPrepayment => isVerified && hasPayoutDetails;
  bool isClosedOn(DateTime value) {
    final closedDate = closedTodayDate;
    if (!isClosedToday || closedDate == null) return false;
    final utc = value.toUtc();
    return closedDate.year == utc.year &&
        closedDate.month == utc.month &&
        closedDate.day == utc.day;
  }
  String get displayStoreName => (storeName?.isNotEmpty == true) ? storeName! : businessName;
  String get displayDescription => (storeDescription?.isNotEmpty == true) ? storeDescription! : (description ?? '');
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
  final String? brand;
  final String? itemCondition;
  final String? specifications;
  final double price;
  final int quantityAvailable;
  final String? imageUrl;
  final List<String> images;
  final String availabilityStatus;
  final String? vendorName;
  final String? categoryName;
  Product({
    required this.productId,
    required this.vendorId,
    this.categoryId,
    required this.productName,
    this.description,
    this.brand,
    this.itemCondition,
    this.specifications,
    required this.price,
    required this.quantityAvailable,
    this.imageUrl,
    this.images = const [],
    this.availabilityStatus = 'available',
    this.vendorName,
    this.categoryName,
  });
  int get pricePesewas => Money.fromCedis(price);
  bool get isAvailable => availabilityStatus == 'available' && quantityAvailable > 0;
  List<String> get gallery {
    final list = <String>[];
    if (images.isNotEmpty) list.addAll(images);
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
      raw.sort((a, b) => toInt(a['position']).compareTo(toInt(b['position'])));
      imgs.addAll(raw.map((e) => e['image_url'] as String?).whereType<String>());
    }
    return Product(
      productId: m['product_id'] as String,
      vendorId: m['vendor_id'] as String,
      categoryId: m['category_id'] as String?,
      productName: (m['product_name'] as String?) ?? '',
      description: m['description'] as String?,
      brand: m['brand'] as String?,
      itemCondition: m['item_condition'] as String?,
      specifications: m['specifications'] as String?,
      price: toDouble(m['price']),
      quantityAvailable: toInt(m['quantity_available']),
      imageUrl: m['image_url'] as String?,
      images: imgs,
      availabilityStatus: (m['availability_status'] as String?) ?? 'available',
      vendorName: m['vendors'] is Map ? m['vendors']['business_name'] as String? : null,
      categoryName: m['categories'] is Map ? m['categories']['category_name'] as String? : null,
    );
  }
  Map<String, dynamic> toInsert() => {
    'vendor_id': vendorId,
    'category_id': categoryId,
    'product_name': productName,
    'description': description,
    'brand': brand,
    'item_condition': itemCondition,
    'specifications': specifications,
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
  final Product? product;
  CartItem({required this.cartItemId, required this.cartId, required this.productId, required this.quantity, this.product});
  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    cartItemId: m['cart_item_id'] as String,
    cartId: m['cart_id'] as String,
    productId: m['product_id'] as String,
    quantity: toInt(m['quantity']),
    product: m['products'] is Map ? Product.fromMap(Map<String, dynamic>.from(m['products'])) : null,
  );
  double get lineTotal => (product?.price ?? 0) * quantity;
  int get lineTotalPesewas => Money.lineTotal(Money.fromCedis(product?.price ?? 0), quantity);
}

class OrderItem {
  final String orderItemId;
  final String orderId;
  final String? productId;
  final int quantity;
  final double unitPrice;
  final String? productName;
  final String? productImage;
  OrderItem({required this.orderItemId, required this.orderId, this.productId, required this.quantity, required this.unitPrice, this.productName, this.productImage});
  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    orderItemId: m['order_item_id'] as String,
    orderId: m['order_id'] as String,
    productId: m['product_id'] as String?,
    quantity: toInt(m['quantity']),
    unitPrice: toDouble(m['unit_price']),
    productName: m['products'] is Map ? m['products']['product_name'] as String? : null,
    productImage: m['products'] is Map ? m['products']['image_url'] as String? : null,
  );
  double get lineTotal => unitPrice * quantity;
  int get unitPricePesewas => Money.fromCedis(unitPrice);
  int get lineTotalPesewas => Money.lineTotal(unitPricePesewas, quantity);
}

class AppOrder {
  final String orderId;
  final String studentId;
  final String vendorId;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String? vendorName;
  final String? studentName;
  final List<OrderItem> items;
  final String? deliveryAddress;
  final String? contactPhone;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? note;
  final String? vendorMomoNumber;
  final String? vendorMomoNetwork;
  final int tokenDiscountPesewas;
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
    this.tokenDiscountPesewas = 0,
    this.confirmedAt,
    this.dispatchedAt,
    this.deliveredAt,
  });
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
  int get totalAmountPesewas => Money.fromCedis(totalAmount);
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
  String get paymentSummary {
    if (paymentMethod == 'cash_on_delivery' || paymentMethod == null) {
      return 'Pay on Delivery';
    }
    return '$paymentMethodLabel · ${isPaid ? 'Paid' : 'Pending'}';
  }
  factory AppOrder.fromMap(Map<String, dynamic> m) => AppOrder(
    orderId: m['order_id'] as String,
    studentId: m['student_id'] as String,
    vendorId: m['vendor_id'] as String,
    totalAmount: toDouble(m['total_amount']),
    status: OrderStatus.fromDb((m['order_status'] as String?) ?? 'pending'),
    createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    vendorName: m['vendors'] is Map ? m['vendors']['business_name'] as String? : null,
    studentName: m['users'] is Map ? m['users']['full_name'] as String? : null,
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
    tokenDiscountPesewas: toInt(m['token_discount_pesewas']),
    confirmedAt: date(m['confirmed_at']),
    dispatchedAt: date(m['dispatched_at']),
    deliveredAt: date(m['delivered_at']),
  );
}

class ProductStat {
  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  ProductStat({required this.productId, required this.productName, required this.unitsSold, required this.revenue});
  factory ProductStat.fromMap(Map<String, dynamic> m) => ProductStat(
    productId: m['product_id'] as String,
    productName: (m['product_name'] as String?) ?? '',
    unitsSold: toInt(m['units_sold']),
    revenue: toDouble(m['revenue']),
  );
}

class AppNotification {
  final String notificationId;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;
  AppNotification({required this.notificationId, required this.title, this.body, required this.isRead, required this.createdAt});
  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    notificationId: m['notification_id'] as String,
    title: (m['title'] as String?) ?? '',
    body: m['body'] as String?,
    isRead: (m['is_read'] as bool?) ?? false,
    createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
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
  Review({required this.reviewId, required this.studentId, required this.vendorId, required this.rating, this.comment, required this.createdAt, this.studentName});
  factory Review.fromMap(Map<String, dynamic> m) => Review(
    reviewId: m['review_id'] as String,
    studentId: m['student_id'] as String,
    vendorId: m['vendor_id'] as String,
    rating: toInt(m['rating']),
    comment: m['comment'] as String?,
    createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    studentName: m['users'] is Map ? m['users']['full_name'] as String? : null,
  );
}

enum ServiceCategory {
  hairGrooming,
  beautyMakeup,
  technicalRepairs,
  academicSupport,
  printingTyping,
  creativeServices,
  laundryCleaning,
  deliveryErrands,
  transportErrands,
  roomCleaning,
  eventSupport,
  foodCatering,
  fitnessSports,
  homeRoomServices,
  other;
  String get db {
    switch (this) {
      case ServiceCategory.hairGrooming: return 'hair_grooming';
      case ServiceCategory.beautyMakeup: return 'beauty_makeup';
      case ServiceCategory.technicalRepairs: return 'technical_repairs';
      case ServiceCategory.academicSupport: return 'academic_support';
      case ServiceCategory.printingTyping: return 'printing_typing';
      case ServiceCategory.creativeServices: return 'creative_services';
      case ServiceCategory.laundryCleaning: return 'laundry_cleaning';
      case ServiceCategory.deliveryErrands: return 'delivery_errands';
      case ServiceCategory.transportErrands: return 'transport_errands';
      case ServiceCategory.roomCleaning: return 'room_cleaning';
      case ServiceCategory.eventSupport: return 'event_support';
      case ServiceCategory.foodCatering: return 'food_catering';
      case ServiceCategory.fitnessSports: return 'fitness_sports';
      case ServiceCategory.homeRoomServices: return 'home_room_services';
      case ServiceCategory.other: return 'other';
    }
  }
  String get label {
    switch (this) {
      case ServiceCategory.hairGrooming: return 'Hair & Grooming';
      case ServiceCategory.beautyMakeup: return 'Beauty & Makeup';
      case ServiceCategory.technicalRepairs: return 'Technical Repairs';
      case ServiceCategory.academicSupport: return 'Academic Support';
      case ServiceCategory.printingTyping: return 'Printing & Typing';
      case ServiceCategory.creativeServices: return 'Creative Services';
      case ServiceCategory.laundryCleaning: return 'Laundry & Cleaning';
      case ServiceCategory.deliveryErrands: return 'Delivery & Errands';
      case ServiceCategory.transportErrands: return 'Transport & Errands';
      case ServiceCategory.roomCleaning: return 'Room Cleaning';
      case ServiceCategory.eventSupport: return 'Event Support';
      case ServiceCategory.foodCatering: return 'Food & Catering';
      case ServiceCategory.fitnessSports: return 'Fitness & Sports';
      case ServiceCategory.homeRoomServices: return 'Home & Room Services';
      case ServiceCategory.other: return 'Other';
    }
  }
  static ServiceCategory fromDb(String? v) {
    for (final c in ServiceCategory.values) { if (c.db == v) return c; }
    return ServiceCategory.other;
  }
}

// ===== SERVICE – v1.0 =====
class Service {
  final String serviceId;
  final String vendorId;
  final String title;
  final String? description;
  final ServiceCategory category;
  final double price;
  final bool priceFrom;
  final String? availability;
  final String? location;
  final String? imageUrl;
  final String status;
  final List<String> images;
  final String? vendorName;
  // v1.0
  final DateTime? expiresAt;
  final DateTime createdAt;
  final bool isAuthorized;
  final double? authorizationFeePaid;
  final DateTime? authorizationPaidAt;
  final DateTime? authorizationExpiresAt;
  final bool consentGiven;
  final DateTime? consentGivenAt;
  final bool? vendorIsVerified;

  Service({
    required this.serviceId,
    required this.vendorId,
    required this.title,
    this.description,
    required this.category,
    required this.price,
    this.priceFrom = false,
    this.availability,
    this.location,
    this.imageUrl,
    this.status = 'available',
    this.images = const [],
    this.vendorName,
    this.expiresAt,
    required this.createdAt,
    this.isAuthorized = false,
    this.authorizationFeePaid,
    this.authorizationPaidAt,
    this.authorizationExpiresAt,
    this.consentGiven = false,
    this.consentGivenAt,
    this.vendorIsVerified,
  });

  int get pricePesewas => Money.fromCedis(price);
  List<String> get gallery {
    final list = <String>[];
    list.addAll(images);
    if (imageUrl != null && imageUrl!.isNotEmpty && !list.contains(imageUrl)) {
      list.insert(0, imageUrl!);
    }
    return list;
  }
  String get priceLabel {
    final money = Money.format(pricePesewas);
    return priceFrom ? 'From $money' : money;
  }
  int get daysLeft {
    if (expiresAt == null) return 999;
    return expiresAt!.difference(DateTime.now()).inDays;
  }
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isExpiringSoon => daysLeft >= 0 && daysLeft <= 3;

  factory Service.fromMap(Map<String, dynamic> m) {
    final imgs = <String>[];
    if (m['service_images'] is List) {
      final raw = List<Map<String, dynamic>>.from(
          (m['service_images'] as List).map((e) => Map<String, dynamic>.from(e)));
      raw.sort((a, b) => toInt(a['position']).compareTo(toInt(b['position'])));
      imgs.addAll(raw.map((e) => e['image_url'] as String?).whereType<String>());
    }
    bool? vVerified;
    if (m['vendors'] is Map) {
      vVerified = (m['vendors']['is_verified'] as bool?);
    }
    return Service(
      serviceId: m['service_id'] as String,
      vendorId: m['vendor_id'] as String,
      title: (m['title'] as String?) ?? '',
      description: m['description'] as String?,
      category: ServiceCategory.fromDb(m['category'] as String?),
      price: toDouble(m['price']),
      priceFrom: (m['price_from'] as bool?) ?? false,
      availability: m['availability'] as String?,
      location: m['location'] as String?,
      imageUrl: m['image_url'] as String?,
      status: (m['status'] as String?) ?? 'available',
      images: imgs,
      vendorName: m['vendors'] is Map ? m['vendors']['business_name'] as String? : null,
      expiresAt: date(m['expires_at']),
      createdAt: date(m['created_at']) ?? DateTime.now(),
      isAuthorized: m['is_authorized'] as bool? ?? false,
      authorizationFeePaid: m['authorization_fee_paid'] == null ? null : toDouble(m['authorization_fee_paid']),
      authorizationPaidAt: date(m['authorization_paid_at']),
      authorizationExpiresAt: date(m['authorization_expires_at']),
      consentGiven: m['consent_given'] as bool? ?? false,
      consentGivenAt: date(m['consent_given_at']),
      vendorIsVerified: vVerified,
    );
  }
}

class TokenTransaction {
  final String txnId;
  final int delta;
  final String reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  TokenTransaction({required this.txnId, required this.delta, required this.reason, required this.createdAt, this.expiresAt});
  bool get isEarn => delta > 0;
  bool get isExpired => isEarn && expiresAt != null && expiresAt!.isBefore(DateTime.now());
  factory TokenTransaction.fromMap(Map<String, dynamic> m) => TokenTransaction(
    txnId: m['txn_id'] as String,
    delta: toInt(m['delta']),
    reason: (m['reason'] as String?) ?? '',
    createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    expiresAt: m['expires_at'] == null ? null : DateTime.tryParse('${m['expires_at']}')?.toLocal(),
  );
}

class Dispute {
  final String disputeId;
  final String orderId;
  final String studentId;
  final String category;
  final String description;
  final List<String> evidence;
  final String status;
  final String? resolution;
  final String? resolutionOutcome;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? studentName;
  final double? orderTotal;
  final String? vendorName;
  Dispute({
    required this.disputeId, required this.orderId, required this.studentId,
    required this.category, required this.description,
    this.evidence = const [], this.status = 'open', this.resolution,
    this.resolutionOutcome,
    required this.createdAt, this.resolvedAt, this.studentName, this.orderTotal, this.vendorName,
  });
  bool get isResolved => status == 'resolved';
  String get statusLabel {
    switch (status) {
      case 'resolved': return 'Resolved';
      case 'under_review': return 'Under review';
      case 'open': default: return 'Open';
    }
  }
  factory Dispute.fromMap(Map<String, dynamic> m) {
    final order = m['orders'] is Map ? Map<String, dynamic>.from(m['orders']) : null;
    return Dispute(
      disputeId: m['dispute_id'] as String,
      orderId: m['order_id'] as String,
      studentId: m['student_id'] as String,
      category: (m['category'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      evidence: (m['evidence'] is List) ? List<String>.from((m['evidence'] as List).whereType<String>()) : const [],
      status: (m['status'] as String?) ?? 'open',
      resolution: m['resolution'] as String?,
      resolutionOutcome: m['resolution_outcome'] as String?,
      createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      resolvedAt: m['resolved_at'] == null
          ? null
          : DateTime.tryParse('${m['resolved_at']}')?.toLocal(),
      studentName: m['users'] is Map ? m['users']['full_name'] as String? : null,
      orderTotal: order != null && order['total_amount'] != null ? toDouble(order['total_amount']) : null,
      vendorName: order != null && order['vendors'] is Map ? order['vendors']['business_name'] as String? : null,
    );
  }
}

// ===== v1.0 NEW MODELS =====

class PlatformSetting {
  final String id;
  final double serviceAuthFee;
  final int serviceAuthDurationDays;
  final int serviceFreeListingDays;
  final double platformFeeSellerPercent;
  final double platformFeeServicePercent;
  final bool verificationRequiredForPrepayment;
  final List<String> kycAllowedTypes;
  final String currentPolicyVersion;
  final DateTime updatedAt;
  PlatformSetting({
    required this.id,
    required this.serviceAuthFee,
    required this.serviceAuthDurationDays,
    required this.serviceFreeListingDays,
    required this.platformFeeSellerPercent,
    required this.platformFeeServicePercent,
    required this.verificationRequiredForPrepayment,
    required this.kycAllowedTypes,
    required this.currentPolicyVersion,
    required this.updatedAt,
  });
  bool get isFreeMode => serviceAuthFee == 0;
  factory PlatformSetting.fromMap(Map<String, dynamic> m) => PlatformSetting(
    id: m['id'] as String,
    serviceAuthFee: toDouble(m['service_auth_fee']),
    serviceAuthDurationDays: toInt(m['service_auth_duration_days']),
    serviceFreeListingDays: toInt(m['service_free_listing_days']),
    platformFeeSellerPercent: toDouble(m['platform_fee_seller_percent']),
    platformFeeServicePercent: toDouble(m['platform_fee_service_percent']),
    verificationRequiredForPrepayment: m['verification_required_for_prepayment'] as bool? ?? true,
    kycAllowedTypes: toStringList(m['kyc_allowed_types']),
    currentPolicyVersion: m['current_policy_version'] as String? ?? 'v1.0-2025-07',
    updatedAt: date(m['updated_at']) ?? DateTime.now(),
  );
  static PlatformSetting get freeMode => PlatformSetting(
    id: 'local-free',
    serviceAuthFee: 0,
    serviceAuthDurationDays: 30,
    serviceFreeListingDays: 14,
    platformFeeSellerPercent: 5.0,
    platformFeeServicePercent: 8.0,
    verificationRequiredForPrepayment: true,
    kycAllowedTypes: const ['ghana_card','student_id'],
    currentPolicyVersion: 'v1.0-2025-07',
    updatedAt: DateTime.now(),
  );
}

enum ConsentType {
  sellerAgreement,
  servicePost,
  paymentAuth,
  verificationSubmit,
  checkoutPolicy,
  termsUpdate;
  String get db {
    switch (this) {
      case ConsentType.sellerAgreement: return 'seller_agreement';
      case ConsentType.servicePost: return 'service_post';
      case ConsentType.paymentAuth: return 'payment_auth';
      case ConsentType.verificationSubmit: return 'verification_submit';
      case ConsentType.checkoutPolicy: return 'checkout_policy';
      case ConsentType.termsUpdate: return 'terms_update';
    }
  }
  static ConsentType fromDb(String s) => ConsentType.values.firstWhere(
          (e) => e.db == s, orElse: () => ConsentType.termsUpdate);
}

class ConsentRecord {
  final String id;
  final String userId;
  final ConsentType consentType;
  final String policyVersion;
  final DateTime consentedAt;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> metadata;
  final String? signatureHash;
  final DateTime? revokedAt;
  ConsentRecord({
    required this.id,
    required this.userId,
    required this.consentType,
    required this.policyVersion,
    required this.consentedAt,
    this.ipAddress,
    this.userAgent,
    this.metadata = const {},
    this.signatureHash,
    this.revokedAt,
  });
  factory ConsentRecord.fromMap(Map<String, dynamic> m) => ConsentRecord(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    consentType: ConsentType.fromDb(m['consent_type'] as String),
    policyVersion: m['policy_version'] as String,
    consentedAt: date(m['consented_at']) ?? DateTime.now(),
    ipAddress: m['ip_address']?.toString(),
    userAgent: m['user_agent'] as String?,
    metadata: (m['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    signatureHash: m['signature_hash'] as String?,
    revokedAt: date(m['revoked_at']),
  );
}
