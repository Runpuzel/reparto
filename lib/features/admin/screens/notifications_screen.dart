import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: AsyncView<List<AppNotification>>(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'No notifications',
                  subtitle: 'Updates about your orders will appear here.',
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final n = list[i];
                return Card(
                  color: n.isRead
                      ? null
                      : Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.4),
                  child: ListTile(
                    leading: Icon(
                      n.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: n.isRead
                          ? null
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(n.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${n.body ?? ''}\n${Formatters.dateTime(n.createdAt)}'),
                    isThreeLine: true,
                    onTap: () async {
                      if (!n.isRead) {
                        await markNotificationRead(n.notificationId);
                        ref.invalidate(notificationsProvider);
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
