import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/vendor_repository.dart';

final vendorRepositoryProvider =
Provider<VendorRepository>((ref) => VendorRepository());

final myProductsProvider = FutureProvider<List<Product>>((ref) async {
  final vendor = await ref.watch(currentVendorProvider.future);
  if (vendor == null) return [];
  return ref.watch(vendorRepositoryProvider).fetchMyProducts(vendor.vendorId);
});

final vendorOrdersProvider = FutureProvider<List<AppOrder>>((ref) async {
  final vendor = await ref.watch(currentVendorProvider.future);
  if (vendor == null) return [];
  return ref.watch(vendorRepositoryProvider).fetchOrders(vendor.vendorId);
});

final salesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final vendor = await ref.watch(currentVendorProvider.future);
  if (vendor == null) {
    return SalesSummary(
        totalOrders: 0, completedOrders: 0, pendingOrders: 0, revenue: 0);
  }
  return ref.watch(vendorRepositoryProvider).fetchSalesSummary(vendor.vendorId);
});

final productStatsProvider = FutureProvider<List<ProductStat>>((ref) async {
  final vendor = await ref.watch(currentVendorProvider.future);
  if (vendor == null) return [];
  return ref.watch(vendorRepositoryProvider).fetchProductStats(vendor.vendorId);
});

final myShopReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final vendor = await ref.watch(currentVendorProvider.future);
  if (vendor == null) return [];
  return ref.watch(vendorRepositoryProvider).fetchReviews(vendor.vendorId);
});
