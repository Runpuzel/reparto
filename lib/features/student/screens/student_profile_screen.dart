import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final campuses = ref.watch(campusesProvider);
    final tokens = ref.watch(tokenBalanceProvider).valueOrNull ?? 0;
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return AsyncView<AppUser?>(
      value: user,
      onRetry: () => ref.invalidate(currentUserProvider),
      data: (student) {
        if (student == null) {
          return const EmptyState(
            icon: Icons.person_outline,
            title: 'Profile unavailable',
            subtitle: 'Sign in again to view your student profile.',
          );
        }
        final campusName = campuses.valueOrNull
                ?.firstWhere(
                  (campus) => campus.campusId == student.campusId,
                  orElse: () =>
                      Campus(campusId: '', campusName: 'Campus not set'),
                )
                .campusName ??
            'Campus not set';

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
            ref.invalidate(campusesProvider);
            ref.invalidate(tokenBalanceProvider);
            ref.invalidate(unreadNotificationsProvider);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth < 400 ? 12.0 : 20.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
                children: [
                  _ProfileHeader(student: student, campusName: campusName),
                  const SizedBox(height: 16),
                  _StudentSummary(
                    campusName: campusName,
                    tokens: tokens,
                    unread: unread,
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Student account'),
                  const SizedBox(height: 8),
                  _SettingsGroup(
                    children: [
                      _ProfileAction(
                        icon: AppIcons.storefront,
                        title: student.role == UserRole.vendor
                            ? 'Seller dashboard'
                            : 'Become a Student Seller',
                        subtitle: student.role == UserRole.vendor
                            ? 'Manage your products, services, and sales'
                            : 'Sell products and services with this account',
                        onTap: student.role == UserRole.vendor
                            ? () => context.go('/vendor')
                            : () => _becomeSeller(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Security'),
                  const SizedBox(height: 8),
                  _SettingsGroup(
                    children: [
                      _ProfileAction(
                        icon: AppIcons.lockReset,
                        title: 'Reset passcode',
                        subtitle: 'Recover access to your account',
                        onTap: () => context.push('/forgot-passcode'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _becomeSeller(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Become a Student Seller?',
      message: 'Your account, cart, favorites, and purchases will stay intact. '
          'You will also get seller tools for posting products and services.',
      confirmLabel: 'Continue',
      icon: AppIcons.storefront,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).becomeStudentSeller();
      ref.invalidate(currentUserProvider);
      ref.invalidate(currentVendorProvider);
      if (context.mounted) context.go('/vendor/agreement');
    } catch (error) {
      if (context.mounted) {
        ConfirmActions.showError(
          context,
          'Could not enable seller mode. Please try again.',
        );
      }
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student, required this.campusName});
  final AppUser student;
  final String campusName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            student.fullName.trim().isEmpty
                ? '?'
                : student.fullName.trim()[0].toUpperCase(),
            style: AppTextStyles.headlineSmall.copyWith(fontSize: 34),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          student.fullName,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: 3),
        Text(
          student.email,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: student.role == UserRole.vendor ? 'Vendor' : 'Student',
              icon: student.role == UserRole.vendor
                  ? AppIcons.storefront
                  : AppIcons.user,
              color: student.role == UserRole.vendor
                  ? scheme.tertiary
                  : scheme.primary,
            ),
            StatusPill(
              label: campusName,
              icon: AppIcons.campus,
              color: scheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _StudentSummary extends StatelessWidget {
  const _StudentSummary({
    required this.campusName,
    required this.tokens,
    required this.unread,
  });
  final String campusName;
  final int tokens;
  final int unread;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SummaryValue(
                icon: AppIcons.campus,
                label: 'Campus',
                value: campusName,
              ),
            ),
            const SizedBox(height: 44, child: VerticalDivider()),
            Expanded(
              child: _SummaryValue(
                icon: AppIcons.tag,
                label: 'Tokens',
                value: '$tokens',
              ),
            ),
            const SizedBox(height: 44, child: VerticalDivider()),
            Expanded(
              child: _SummaryValue(
                icon: AppIcons.notification,
                label: 'Unread',
                value: '$unread',
              ),
            ),
          ],
        ),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Icon(AppIcons.caretRight, size: 18),
          ],
        ),
        onTap: onTap,
      );
}
