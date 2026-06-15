import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/developer_info_card.dart';
import '../../../core/widgets/notifications_diagnostic_tile.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_providers.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final campuses = ref.watch(campusesProvider);

    return AsyncView<AppUser?>(
      value: user,
      data: (u) {
        if (u == null) return const SizedBox();
        final campusName = campuses.valueOrNull
            ?.firstWhere(
              (c) => c.campusId == u.campusId,
          orElse: () => Campus(campusId: '', campusName: 'Unknown'),
        )
            .campusName;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(u.fullName,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Center(child: Text(u.email)),
            const SizedBox(height: 24),
            _InfoTile(
                icon: Icons.school_outlined,
                label: 'Campus',
                value: campusName ?? '—'),
            _InfoTile(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: 'Student'),
            const SizedBox(height: 12),
            const ThemeModeTile(),
            const SizedBox(height: 12),
            const NotificationsDiagnosticTile(),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Forgot / Reset passcode'),
                subtitle: const Text('Contact support to reset your passcode'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/forgot-passcode'),
              ),
            ),
            const SizedBox(height: 12),
            const DeveloperInfoCard(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label,
            style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
