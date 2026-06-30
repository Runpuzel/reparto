import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
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
import '../../auth/providers/auth_providers.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(currentVendorProvider);
    final user = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return AsyncView<Vendor?>(
      value: vendor,
      data: (v) {
        if (v == null) return const SizedBox();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.sm + 4),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                backgroundImage: (v.logoUrl != null && v.logoUrl!.isNotEmpty)
                    ? NetworkImage(v.logoUrl!)
                    : null,
                child: (v.logoUrl == null || v.logoUrl!.isEmpty)
                    ? Icon(AppIcons.storefrontFill, size: 42)
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(v.businessName,
                  style: AppTextStyles.titleLarge
                      .copyWith(color: scheme.onSurface)),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Center(
              child: StatusPill(
                label: v.approvalStatus.label,
                color: v.isApproved ? AppColors.success : AppColors.warning,
                icon: v.isApproved ? AppIcons.check : AppIcons.pending,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _tile(context, AppIcons.user, 'Owner', v.ownerName ?? '—'),
            _tile(context, AppIcons.phone, 'Personal Phone',
                v.phoneNumber ?? '—'),
            _tile(context, AppIcons.phoneBusiness, 'Business Phone',
                v.businessPhone ?? '—'),
            _tile(context, AppIcons.wallet, 'Mobile Money',
                v.momoNumber == null
                    ? '—'
                    : '${v.momoNumber} (${v.momoNetwork ?? ''})'),
            _tile(context, AppIcons.badge, 'Ghana Card',
                v.ghanaCardNumber ?? '—'),
            _tile(context, AppIcons.email, 'Email',
                user.valueOrNull?.email ?? '—'),
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
              .animate(interval: 35.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.03, end: 0),
        );
      },
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 2),
                  Text(value,
                      style: AppTextStyles.titleSmall
                          .copyWith(color: scheme.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
