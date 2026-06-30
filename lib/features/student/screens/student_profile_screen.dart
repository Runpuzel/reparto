import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
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
    final scheme = Theme.of(context).colorScheme;

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
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.sm + 4),
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(
                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(u.fullName,
                  style: AppTextStyles.titleLarge
                      .copyWith(color: scheme.onSurface)),
            ),
            Center(
              child: Text(u.email,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: AppSpacing.lg),
            _InfoTile(
                icon: AppIcons.campus, label: 'Campus', value: campusName ?? '—'),
            const SizedBox(height: AppSpacing.sm),
            _InfoTile(icon: AppIcons.role, label: 'Role', value: 'Student'),
            const SizedBox(height: AppSpacing.sm + 4),
            AppCard(
              onTap: () => context.push('/referrals'),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(AppIcons.tag),
                title: const Text('Referral Hub'),
                subtitle: const Text('Invite friends & earn tokens'),
                trailing: Icon(AppIcons.caretRight, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const ThemeModeTile(),
            const SizedBox(height: AppSpacing.sm + 4),
            const NotificationsDiagnosticTile(),
            const SizedBox(height: AppSpacing.sm + 4),
            AppCard(
              onTap: () => context.push('/forgot-passcode'),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(AppIcons.lockReset),
                title: const Text('Forgot / Reset passcode'),
                subtitle:
                const Text('Contact support to reset your passcode'),
                trailing: Icon(AppIcons.caretRight, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const DeveloperInfoCard(),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign Out',
              icon: AppIcons.logout,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ]
              .animate(interval: 40.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.03, end: 0),
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
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(value,
                  style: AppTextStyles.titleSmall
                      .copyWith(color: scheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}
