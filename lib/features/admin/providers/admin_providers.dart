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
