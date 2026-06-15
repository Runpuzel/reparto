import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/models.dart';
import '../data/student_repository.dart';

final studentRepositoryProvider =
Provider<StudentRepository>((ref) => StudentRepository());

/// Search & category filter state.
final productSearchProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(studentRepositoryProvider);
  final search = ref.watch(productSearchProvider);
  final category = ref.watch(selectedCategoryProvider);
  return repo.fetchProducts(categoryId: category, search: search);
});

final cartProvider = FutureProvider<List<CartItem>>((ref) async {
  return ref.watch(studentRepositoryProvider).fetchCart();
});

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? [];
  return cart.fold(0.0, (sum, item) => sum + item.lineTotal);
});

/// Total number of units currently in the cart (for the badge count).
final cartCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? [];
  return cart.fold<int>(0, (sum, item) => sum + item.quantity);
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
