import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/push_service.dart';
import '../../../models/models.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Streams raw Supabase auth state.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The current signed-in profile (null when logged out). Re-fetches whenever
/// auth state changes.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  if (Supabase.instance.client.auth.currentUser == null) return null;
  final profile = await repo.fetchProfile();

  // Register for push once we have an authenticated profile.
  if (profile != null && Env.pushEnabled) {
    // Fire-and-forget; never block auth resolution.
    PushService.init();
  }
  return profile;
});

/// True when there is no signed-in user (guest / unauthenticated browsing).
final isGuestProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.valueOrNull == null;
});

/// The vendor business record for the current user (null if not a vendor).
final currentVendorProvider = FutureProvider<Vendor?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null || user.role != UserRole.vendor) return null;
  return ref.watch(authRepositoryProvider).fetchVendor();
});
