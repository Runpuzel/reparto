import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/admin_providers.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allUsersProvider),
      child: users.when(
        loading: () => const SkeletonList(itemCount: 8, itemHeight: 76),
        error: (e, _) => ErrorState(
            message: '$e', onRetry: () => ref.invalidate(allUsersProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              EmptyState(icon: Icons.group_outlined, title: 'No users'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _UserTile(user: list[i])
                .animate()
                .fadeIn(delay: (30 * (i % 14)).ms, duration: 260.ms)
                .slideY(begin: 0.04, end: 0),
          );
        },
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final AppUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final u = user;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
                u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall),
                Text(u.role.name,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          u.role == UserRole.admin
              ? StatusPill(
              label: 'Admin',
              color: AppColors.info,
              icon: AppIcons.shield)
              : Switch(
            value: !u.isSuspended,
            onChanged: (active) async {
              final suspend = !active;
              final confirmed = await ConfirmActions.confirm(
                context,
                title: suspend ? 'Suspend user?' : 'Reactivate user?',
                message: suspend
                    ? 'Suspend "${u.fullName}"? They will not be able to use the app.'
                    : 'Reactivate "${u.fullName}"?',
                confirmLabel: suspend ? 'Suspend' : 'Reactivate',
                destructive: suspend,
                icon: suspend
                    ? Icons.block
                    : Icons.check_circle_outline,
              );
              if (!confirmed) return;
              try {
                await ref
                    .read(adminRepositoryProvider)
                    .setUserSuspended(u.userId, suspend);
                ref.invalidate(allUsersProvider);
                if (context.mounted) {
                  ConfirmActions.toast(
                      context,
                      suspend ? 'User suspended' : 'User reactivated',
                      success: !suspend);
                }
              } catch (e) {
                if (context.mounted) {
                  ConfirmActions.showError(context, e);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
