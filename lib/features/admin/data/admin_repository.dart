import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';

/// Data access for administrator tooling: campuses, vendor approvals,
/// account suspension and reporting.
class AdminRepository {
  // ---- Campuses -------------------------------------------------------------
  Future<List<Campus>> fetchAllCampuses() async {
    final rows =
    await supabase.from('campuses').select().order('campus_name');
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
    final rows =
    await supabase.from('categories').select().order('category_name');
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

  // ---- Users ----------------------------------------------------------------
  Future<List<AppUser>> fetchUsers() async {
    final rows =
    await supabase.from('users').select().order('created_at', ascending: false);
    return (rows as List)
        .map((e) => AppUser.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setUserSuspended(String userId, bool suspended) async {
    await supabase
        .from('users')
        .update({'is_suspended': suspended}).eq('user_id', userId);
  }

  // ---- Reports --------------------------------------------------------------
  Future<PlatformReport> fetchReport() async {
    final campuses = await supabase.from('campuses').select('campus_id');
    final users = await supabase.from('users').select('role');
    final vendors = await supabase.from('vendors').select('approval_status');
    final products = await supabase.from('products').select('product_id');
    final orders =
    await supabase.from('orders').select('total_amount, order_status');

    int students = 0, vendorUsers = 0;
    for (final u in users as List) {
      if (u['role'] == 'student') students++;
      if (u['role'] == 'vendor') vendorUsers++;
    }
    int approvedVendors = 0, pendingVendors = 0, suspendedVendors = 0;
    for (final v in vendors as List) {
      switch (v['approval_status']) {
        case 'approved':
          approvedVendors++;
          break;
        case 'pending':
          pendingVendors++;
          break;
        case 'suspended':
          suspendedVendors++;
          break;
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
