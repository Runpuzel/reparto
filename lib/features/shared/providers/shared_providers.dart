import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/tokens_repository.dart';

/// All active campuses (used in registration / campus selection).
final campusesProvider = FutureProvider<List<Campus>>((ref) async {
  final rows = await supabase
      .from('campuses')
      .select()
      .eq('status', 'active')
      .order('campus_name');
  return (rows as List)
      .map((e) => Campus.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

/// Current marketplace fee settings. The database uses the same row when an
/// order is settled, keeping displayed and charged fees consistent.
final marketplaceSettingsProvider = FutureProvider<PlatformSetting>((ref) async {
  final row = await supabase
      .from('platform_settings')
      .select()
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return row == null
      ? PlatformSetting.freeMode
      : PlatformSetting.fromMap(Map<String, dynamic>.from(row));
});

/// Product categories.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final rows =
  await supabase.from('categories').select().order('category_name');
  return (rows as List)
      .map((e) => Category.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

/// Unread notification count for the badge — scoped to the signed-in user and
/// rebuilt whenever the authenticated user changes (so it's always user-specific).
final unreadNotificationsProvider = StreamProvider<int>((ref) {
  // Re-evaluate when auth state changes (login/logout/account switch).
  ref.watch(authStateProvider);
  final uid = currentAuthUser?.id;
  if (uid == null) return Stream.value(0);
  return supabase
      .from('notifications')
      .stream(primaryKey: ['notification_id'])
      .eq('recipient_id', uid)
      .map((rows) => rows.where((r) => r['is_read'] == false).length);
});

/// All notifications for the current user (user-specific; rebuilt on auth change).
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  ref.watch(authStateProvider);
  final uid = currentAuthUser?.id;
  if (uid == null) return Stream.value(const []);
  return supabase
      .from('notifications')
      .stream(primaryKey: ['notification_id'])
      .eq('recipient_id', uid)
      .map((rows) {
        final items = rows
            .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      });
});

Future<void> markNotificationRead(String id) async {
  await supabase
      .from('notifications')
      .update({'is_read': true}).eq('notification_id', id);
}

// ---- Referral tokens (spec F7) ---------------------------------------------
final tokensRepositoryProvider =
Provider<TokensRepository>((ref) => TokensRepository());

final tokenBalanceProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateProvider);
  if (currentAuthUser == null) return 0;
  return ref.watch(tokensRepositoryProvider).balance();
});

final tokenHistoryProvider = FutureProvider<List<TokenTransaction>>((ref) async {
  ref.watch(authStateProvider);
  if (currentAuthUser == null) return [];
  return ref.watch(tokensRepositoryProvider).history();
});
