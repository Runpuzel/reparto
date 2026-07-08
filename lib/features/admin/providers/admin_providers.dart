import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/models.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository());

final allCampusesProvider = FutureProvider<List<Campus>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchAllCampuses();
});

final pendingVendorsProvider = FutureProvider<List<Vendor>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchVendors(status: 'pending');
});

final allVendorsProvider = FutureProvider<List<Vendor>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchVendors();
});

final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final platformReportProvider = FutureProvider<PlatformReport>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchReport();
});

final adminCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchCategories();
});

final adminDisputesProvider = FutureProvider<List<Dispute>>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchDisputes();
});

final adminDisputeKpisProvider = FutureProvider<DisputeKpis>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchDisputeKpis();
});

// ---- Services (v1.0) ----

final adminServicesProvider =
    FutureProvider.family<List<Service>, AdminServiceQuery>((ref, query) async {
  return ref.watch(adminRepositoryProvider).fetchServices(query);
});

final adminServiceKpisProvider = FutureProvider<ServiceKpis>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchServiceKpis();
});

final platformSettingsProvider = FutureProvider<PlatformSetting>((ref) async {
  return ref.watch(adminRepositoryProvider).fetchPlatformSettings();
});

final serviceBookingsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, serviceId) async {
  return [];
});
