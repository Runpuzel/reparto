import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/shared_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifications.when(
          loading: () => const SkeletonList(itemCount: 7, itemHeight: 76),
          error: (e, _) => ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(notificationsProvider)),
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
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final n = list[i];
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  color: n.isRead
                      ? scheme.surfaceContainerLowest
                      : scheme.primaryContainer.withValues(alpha: 0.4),
                  onTap: () async {
                    if (!n.isRead) {
                      await markNotificationRead(n.notificationId);
                      ref.invalidate(notificationsProvider);
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        n.isRead ? AppIcons.bellNone : AppIcons.bellActive,
                        color:
                        n.isRead ? scheme.onSurfaceVariant : scheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title,
                                style: AppTextStyles.titleSmall
                                    .copyWith(color: scheme.onSurface)),
                            if (n.body != null && n.body!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(n.body!,
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: scheme.onSurface)),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            Text(Formatters.dateTime(n.createdAt),
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          margin: const EdgeInsets.only(top: 4, left: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: (30 * (i % 14)).ms, duration: 260.ms)
                    .slideY(begin: 0.04, end: 0);
              },
            );
          },
        ),
      ),
    );
  }
}
