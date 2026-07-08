import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';

/// Query parameters for filtering services in the admin dashboard.
class AdminServiceQuery {
  final String status;
  final String q;
  final String verification;
  const AdminServiceQuery({
    required this.status,
    required this.q,
    required this.verification,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminServiceQuery &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          q == other.q &&
          verification == other.verification;

  @override
  int get hashCode => status.hashCode ^ q.hashCode ^ verification.hashCode;
}

/// Key performance indicators for campus services.
class ServiceKpis {
  final int active;
  final int pendingAuth;
  final int expired;
  final double revenueMtd;
  const ServiceKpis({
    this.active = 0,
    this.pendingAuth = 0,
    this.expired = 0,
    this.revenueMtd = 0,
  });
}

/// Key performance indicators for customer disputes.
class DisputeKpis {
  final int open;
  final int underReview;
  final int resolved;

  const DisputeKpis({
    this.open = 0,
    this.underReview = 0,
    this.resolved = 0,
  });
}

/// Data access for administrator tooling: campuses, vendor approvals,
/// account suspension and reporting.
class AdminRepository {
  // ---- Campuses -------------------------------------------------------------
  Future<List<Campus>> fetchAllCampuses() async {
    final rows = await supabase.from('campuses').select().order('campus_name');
    return (rows as List)
        .map((e) => Campus.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createCampus(String name, String? location) async {
    await supabase.from('campuses').insert({
      'campus_name': name,
      'location': location,
    });
  }

  Future<void> setCampusStatus(String campusId, String status) async {
    await supabase
        .from('campuses')
        .update({'status': status}).eq('campus_id', campusId);
  }

  // ---- Vendors --------------------------------------------------------------
  Future<List<Vendor>> fetchVendors({String? status}) async {
    var q = supabase.from('vendors').select();
    if (status != null) q = q.eq('approval_status', status);
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Vendor.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setVendorApproval(String vendorId, String status) async {
    await supabase
        .from('vendors')
        .update({'approval_status': status}).eq('vendor_id', vendorId);
  }

  // ---- Categories -----------------------------------------------------------
  Future<List<Category>> fetchCategories() async {
    final rows = await supabase.from('categories').select().order('category_name');
    return (rows as List)
        .map((e) => Category.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createCategory(String name, String? description) async {
    await supabase.from('categories').insert({
      'category_name': name,
      'description': description,
    });
  }

  Future<void> updateCategory(
      String categoryId, String name, String? description) async {
    await supabase.from('categories').update({
      'category_name': name,
      'description': description,
    }).eq('category_id', categoryId);
  }

  Future<void> deleteCategory(String categoryId) async {
    await supabase.from('categories').delete().eq('category_id', categoryId);
  }

  // ---- Services (v1.0) ------------------------------------------------------
  Future<List<Service>> fetchServices(AdminServiceQuery query) async {
    var q = supabase.from('services').select('*, vendors(business_name, is_verified)');

    if (query.status != 'all') {
      if (query.status == 'active') {
        q = q.eq('status', 'available');
      } else if (query.status == 'pending_auth') {
        q = q.eq('is_authorized', false).lt('expires_at', DateTime.now().add(const Duration(days: 3)).toIso8601String());
      } else if (query.status == 'expired') {
        q = q.lt('expires_at', DateTime.now().toIso8601String());
      } else if (query.status == 'authorized') {
        q = q.eq('is_authorized', true);
      }
    }

    if (query.verification == 'verified') {
      q = q.eq('vendors.is_verified', true);
    } else if (query.verification == 'unverified') {
      q = q.eq('vendors.is_verified', false);
    }

    if (query.q.isNotEmpty) {
      q = q.ilike('title', '%${query.q}%');
    }

    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Service.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ServiceKpis> fetchServiceKpis() async {
    final currentTime = DateTime.now();
    final now = currentTime.toIso8601String();
    final authorizationDeadline =
        currentTime.add(const Duration(days: 3)).toIso8601String();

    final activeRes = await supabase
        .from('services')
        .select('service_id')
        .eq('status', 'available')
        .or('expires_at.is.null,expires_at.gt.$now');
    final expiredRes = await supabase
        .from('services')
        .select('service_id')
        .eq('status', 'expired');
    final pendingAuthRes = await supabase
        .from('services')
        .select('service_id')
        .eq('is_authorized', false)
        .lt('expires_at', authorizationDeadline)
        .gte('expires_at', now);

    // Revenue MTD (estimate from authorization fees)
    final firstOfMonth =
        DateTime(currentTime.year, currentTime.month).toIso8601String();
    final revRows = await supabase
        .from('services')
        .select('authorization_fee_paid')
        .gte('authorization_paid_at', firstOfMonth);
    double revenue = 0;
    for (final r in revRows as List) {
      revenue += (r['authorization_fee_paid'] as num?)?.toDouble() ?? 0;
    }

    return ServiceKpis(
      active: activeRes.length,
      expired: expiredRes.length,
      pendingAuth: pendingAuthRes.length,
      revenueMtd: revenue,
    );
  }

  Future<PlatformSetting> fetchPlatformSettings() async {
    final row = await supabase
        .from('platform_settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return PlatformSetting.freeMode;
    return PlatformSetting.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> reviewVerification(String vendorId, bool approve,
      {String? reason}) async {
    await supabase.rpc('admin_review_verification', params: {
      'p_vendor_id': vendorId,
      'p_approve': approve,
      'p_reason': reason,
    });
  }

  Future<void> updatePlatformSettings(Map<String, dynamic> data) async {
    await supabase.rpc('set_platform_settings', params: {'p_settings': data});
  }

  Future<void> extendServiceExpiration(String serviceId, int days) async {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Must be greater than zero');
    }

    final service = await supabase
        .from('services')
        .select('expires_at')
        .eq('service_id', serviceId)
        .single();
    final expiresAt = DateTime.tryParse(service['expires_at'] as String? ?? '');
    final baseline =
        expiresAt != null && expiresAt.isAfter(DateTime.now())
            ? expiresAt
            : DateTime.now();
    final next = baseline.add(Duration(days: days));
    await supabase
        .from('services')
        .update({'expires_at': next.toIso8601String()})
        .eq('service_id', serviceId);
  }

  Future<void> authorizeService(String serviceId, bool auth, String reason) async {
    await supabase.from('services').update({
      'is_authorized': auth,
      'authorization_paid_at': auth ? DateTime.now().toIso8601String() : null,
      'authorization_expires_at': auth ? DateTime.now().add(const Duration(days: 30)).toIso8601String() : null,
      'status': auth ? 'available' : 'available',
    }).eq('service_id', serviceId);
  }

  Future<void> setServiceStatus(String serviceId, String status) async {
    await supabase.from('services').update({'status': status}).eq('service_id', serviceId);
  }

  Future<void> deleteService(String serviceId) async {
    await supabase.from('services').delete().eq('service_id', serviceId);
  }

  Future<int> expireUnpaidServices() async {
    final res = await supabase.rpc('expire_unpaid_services');
    return (res as num?)?.toInt() ?? 0;
  }

  Future<void> bulkExtendServices(List<String> ids, int days) async {
    for (final id in ids) {
      await extendServiceExpiration(id, days);
    }
  }

  Future<void> bulkAuthorizeServices(List<String> ids, bool auth) async {
    await supabase.from('services').update({
      'is_authorized': auth,
      'authorization_paid_at': auth ? DateTime.now().toIso8601String() : null,
      'authorization_expires_at': auth ? DateTime.now().add(const Duration(days: 30)).toIso8601String() : null,
    }).inFilter('service_id', ids);
  }

  // ---- Users ----------------------------------------------------------------
  Future<List<AppUser>> fetchUsers() async {
    final rows = await supabase.from('users').select().order('created_at', ascending: false);
    return (rows as List)
        .map((e) => AppUser.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setUserSuspended(String userId, bool suspended) async {
    await supabase
        .from('users')
        .update({'is_suspended': suspended}).eq('user_id', userId);
  }

  // ---- Disputes (spec G4) ---------------------------------------------------
  Future<List<Dispute>> fetchDisputes({String? status}) async {
    var q = supabase.from('disputes').select(
        '*, users(full_name), orders(total_amount, vendors(business_name))');
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Dispute.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DisputeKpis> fetchDisputeKpis() async {
    final rows = await supabase.from('disputes').select('status');
    int open = 0, review = 0, resolved = 0;
    for (final r in rows as List) {
      switch (r['status'] as String?) {
        case 'resolved':
          resolved++;
          break;
        case 'under_review':
          review++;
          break;
        default:
          open++;
      }
    }
    return DisputeKpis(open: open, underReview: review, resolved: resolved);
  }

  Future<void> resolveDispute(
      String disputeId, String outcome, String? note) async {
    const outcomes = {'refund_buyer', 'release_seller'};
    if (!outcomes.contains(outcome)) {
      throw ArgumentError.value(outcome, 'outcome', 'Unsupported ruling');
    }
    if (note == null || note.trim().length < 10) {
      throw ArgumentError.value(note, 'note', 'Enter at least 10 characters');
    }
    await supabase.rpc('resolve_dispute', params: {
      'p_dispute': disputeId,
      'p_outcome': outcome,
      'p_note': note.trim(),
    });
    if (outcome == 'release_seller') {
      final dispute = await supabase
          .from('disputes')
          .select('order_id')
          .eq('dispute_id', disputeId)
          .single();
      try {
        await supabase.functions.invoke(
          'process-payouts',
          body: {'order_id': dispute['order_id']},
        );
      } catch (_) {
        // The settlement remains queued and can be retried by the worker.
      }
    }
  }

  Future<void> markDisputeUnderReview(String disputeId) async {
    await supabase.rpc('review_dispute', params: {'p_dispute': disputeId});
  }

  // ---- Reports --------------------------------------------------------------
  Future<PlatformReport> fetchReport() async {
    final campuses = await supabase.from('campuses').select('campus_id');
    final users = await supabase.from('users').select('role');
    final vendors = await supabase.from('vendors').select('approval_status');
    final products = await supabase.from('products').select('product_id');
    final orders = await supabase.from('orders').select('total_amount, order_status');

    int students = 0, vendorUsers = 0;
    for (final u in users as List) {
      if (u['role'] == 'student') students++;
      if (u['role'] == 'vendor') vendorUsers++;
    }
    int approvedVendors = 0, pendingVendors = 0, suspendedVendors = 0;
    for (final v in vendors as List) {
      switch (v['approval_status']) {
        case 'approved': approvedVendors++; break;
        case 'pending': pendingVendors++; break;
        case 'suspended': suspendedVendors++; break;
      }
    }
    double gmv = 0;
    double pendingFunds = 0;
    int completed = 0, active = 0;
    for (final o in orders as List) {
      final status = o['order_status'];
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      if (status == 'completed' || status == 'delivered') {
        completed++;
        gmv += amount;
      } else if (status != 'cancelled') {
        active++;
        pendingFunds += amount;
      }
    }

    return PlatformReport(
      campuses: (campuses as List).length,
      students: students,
      vendors: vendorUsers,
      approvedVendors: approvedVendors,
      pendingVendors: pendingVendors,
      suspendedVendors: suspendedVendors,
      products: (products as List).length,
      totalOrders: (orders).length,
      completedOrders: completed,
      activeOrders: active,
      gmv: gmv,
      pendingFunds: pendingFunds,
    );
  }
}

class PlatformReport {
  final int campuses;
  final int students;
  final int vendors;
  final int approvedVendors;
  final int pendingVendors;
  final int suspendedVendors;
  final int products;
  final int totalOrders;
  final int completedOrders;
  final int activeOrders;
  final double gmv;
  final double pendingFunds;
  PlatformReport({
    required this.campuses,
    required this.students,
    required this.vendors,
    required this.approvedVendors,
    required this.pendingVendors,
    required this.suspendedVendors,
    required this.products,
    required this.totalOrders,
    required this.completedOrders,
    required this.activeOrders,
    required this.gmv,
    required this.pendingFunds,
  });
}
