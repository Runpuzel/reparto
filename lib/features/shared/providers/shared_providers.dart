import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';

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
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  ref.watch(authStateProvider);
  final uid = currentAuthUser?.id;
  if (uid == null) return [];
  final rows = await supabase
      .from('notifications')
      .select()
      .eq('recipient_id', uid)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

Future<void> markNotificationRead(String id) async {
  await supabase
      .from('notifications')
      .update({'is_read': true}).eq('notification_id', id);
}
