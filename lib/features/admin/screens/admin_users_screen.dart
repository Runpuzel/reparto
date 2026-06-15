import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
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
      child: AsyncView<List<AppUser>>(
        value: users,
        onRetry: () => ref.invalidate(allUsersProvider),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              EmptyState(icon: Icons.group_outlined, title: 'No users'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final u = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(u.fullName.isNotEmpty
                        ? u.fullName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(u.fullName),
                  subtitle: Text('${u.email}\n${u.role.name}'),
                  isThreeLine: true,
                  trailing: u.role == UserRole.admin
                      ? const StatusPill(label: 'Admin', color: Colors.indigo)
                      : Switch(
                    value: !u.isSuspended,
                    onChanged: (active) async {
                      final suspend = !active;
                      final confirmed = await ConfirmActions.confirm(
                        context,
                        title: suspend
                            ? 'Suspend user?'
                            : 'Reactivate user?',
                        message: suspend
                            ? 'Suspend "${u.fullName}"? They will not be able to use the app.'
                            : 'Reactivate "${u.fullName}"?',
                        confirmLabel:
                        suspend ? 'Suspend' : 'Reactivate',
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
                              suspend
                                  ? 'User suspended'
                                  : 'User reactivated',
                              success: !suspend);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ConfirmActions.showError(context, e);
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
