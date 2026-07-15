import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/student_repository.dart';

final studentRepositoryProvider =
    Provider<StudentRepository>((ref) => StudentRepository());

/// Search & category filter state.
final productSearchProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final productsProvider = FutureProvider<List<Product>>((ref) async {
  // Guest and signed-in catalogue policies differ, so refresh whenever the
  // Supabase session changes instead of retaining the previous result.
  ref.watch(authStateProvider);
  final repo = ref.watch(studentRepositoryProvider);
  final search = ref.watch(productSearchProvider);
  final category = ref.watch(selectedCategoryProvider);
  return repo.fetchProducts(categoryId: category, search: search);
});

final cartProvider = FutureProvider<List<CartItem>>((ref) async {
  ref.watch(authStateProvider);
  if (currentAuthUser == null) return const <CartItem>[];
  return ref.watch(studentRepositoryProvider).fetchCart();
});

/// Cart total in exact integer pesewas (computed with integer math to avoid
/// floating-point accumulation; this is the source of truth for totals).
final cartTotalPesewasProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? [];
  return cart.fold<int>(0, (sum, item) => sum + item.lineTotalPesewas);
});

/// Cart total in cedis (derived from the exact pesewa total). Kept for widgets
/// that still expect a double.
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartTotalPesewasProvider) / 100;
});

/// Total number of units currently in the cart (for the badge count).
final cartCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? [];
  return cart.fold<int>(0, (sum, item) => sum + item.quantity);
});

// ---- Services ---------------------------------------------------------------

/// Search + category filter state for the Services tab.
final serviceSearchProvider = StateProvider<String>((ref) => '');
final serviceCategoryProvider = StateProvider<ServiceCategory?>((ref) => null);

final servicesProvider = FutureProvider<List<Service>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(studentRepositoryProvider);
  final search = ref.watch(serviceSearchProvider);
  final category = ref.watch(serviceCategoryProvider);
  return repo.fetchServices(category: category?.db, search: search);
});

final browseServicesProvider = FutureProvider<List<Service>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(studentRepositoryProvider);
  final search = ref.watch(productSearchProvider);
  return repo.fetchServices(search: search);
});

final serviceProvider =
    FutureProvider.family<Service?, String>((ref, serviceId) async {
  return ref.watch(studentRepositoryProvider).fetchService(serviceId);
});

final myOrdersProvider = FutureProvider<List<AppOrder>>((ref) async {
  return ref.watch(studentRepositoryProvider).fetchMyOrders();
});

final vendorReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, vendorId) async {
  return ref.watch(studentRepositoryProvider).fetchVendorReviews(vendorId);
});

// ---- Shops ------------------------------------------------------------------

/// Search query for the Shops tab.
final shopSearchProvider = StateProvider<String>((ref) => '');

/// All approved shops on the student's campus.
final shopsProvider = FutureProvider<List<Vendor>>((ref) async {
  ref.watch(authStateProvider);
  final search = ref.watch(shopSearchProvider);
  return ref.watch(studentRepositoryProvider).fetchVendors(search: search);
});

/// A single shop's details.
final shopProvider =
    FutureProvider.family<Vendor?, String>((ref, vendorId) async {
  return ref.watch(studentRepositoryProvider).fetchVendor(vendorId);
});

/// Products belonging to a specific shop.
final shopProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, vendorId) async {
  return ref.watch(studentRepositoryProvider).fetchProductsByVendor(vendorId);
});

final shopServicesProvider =
    FutureProvider.family<List<Service>, String>((ref, vendorId) async {
  return ref.watch(studentRepositoryProvider).fetchServicesByVendor(vendorId);
});

// ---- Favorites --------------------------------------------------------------

/// The student's favorite products (full objects, for the Favorites tab).
final favoritesProvider = FutureProvider<List<Product>>((ref) async {
  return ref.watch(studentRepositoryProvider).fetchFavorites();
});

/// Just the favorite product ids (for quick heart-toggle state everywhere).
final favoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(studentRepositoryProvider).fetchFavoriteIds();
});

// ---- Single order -----------------------------------------------------------
final orderDetailProvider =
    FutureProvider.family<AppOrder?, String>((ref, orderId) async {
  return ref.watch(studentRepositoryProvider).fetchOrder(orderId);
});
