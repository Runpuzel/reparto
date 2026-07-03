// lib/features/vendor/screens/vendor_profile_screen.dart
// v1.0-2025-07 – REDESIGN – grouped sections, verified badge, platform fees seller-only

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
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(currentVendorProvider);
    final userAsync = ref.watch(currentUserProvider);
    final platformSettings =
        ref.watch(vendorPlatformSettingsProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return AsyncView<Vendor?>(
      value: vendorAsync,
      data: (v) {
        if (v == null) {
          return const Center(child: Text('Sign in as vendor'));
        }
        final user = userAsync.valueOrNull;
        final isVerified = v.isVerified;
        final profileCompleted = v.profileCompleted;
        final storeName = v.displayStoreName;
        final storeDesc = v.displayDescription;
        // operating hours display
        final hours = (_shortTime(v.openingTime) != null &&
                _shortTime(v.closingTime) != null)
            ? '${_shortTime(v.openingTime)} – ${_shortTime(v.closingTime)}'
            : 'Set hours';
        final workingDays = v.workingDays.isNotEmpty ? v.workingDays.join(' · ') : '—';

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Header – avatar + verified badge
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    backgroundImage: (v.logoUrl != null && v.logoUrl!.isNotEmpty)
                        ? NetworkImage(v.logoUrl!)
                        : null,
                    child: (v.logoUrl == null || v.logoUrl!.isEmpty)
                        ? Icon(AppIcons.storefrontFill, size: 44)
                        : null,
                  ),
                  if (isVerified)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 3),
                        ),
                        child: const Icon(Icons.verified, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Column(
                children: [
                  Text(storeName, style: AppTextStyles.titleLarge.copyWith(color: scheme.onSurface), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  // Verified badge pill
                  StatusPill(
                    label: isVerified ? 'Verified Student Seller' : _verificationLabel(v.verificationStatus),
                    color: isVerified ? AppColors.success : v.verificationStatus == 'pending' ? AppColors.warning : AppColors.neutral500,
                    icon: isVerified ? AppIcons.check : AppIcons.pending,
                  ),
                ],
              ),
            ),
            if (storeDesc.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  storeDesc,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // ===== Group 1: Store Info =====
            _groupLabel('Store Info', Icons.storefront_outlined),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  _rowTile(context, AppIcons.user, 'Owner', v.ownerName ?? '—'),
                  const Divider(height: 20),
                  _rowTile(context, AppIcons.mapPin, 'Location',
                      v.storeLocation?.isNotEmpty == true ? v.storeLocation! : 'Not set – tap Edit Store'),
                  const Divider(height: 20),
                  _rowTile(context, AppIcons.phone, 'WhatsApp',
                      v.whatsappNumber ?? v.businessPhone ?? v.phoneNumber ?? '—'),
                  const Divider(height: 20),
                  _rowTile(context, Icons.school_outlined, 'Program',
                      v.programYear?.isNotEmpty == true ? v.programYear! : '—'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Store'),
                          onPressed: () => context.push('/vendor/store/edit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ===== Group 2: Verification Status =====
            _groupLabel('Verification', Icons.verified_user_outlined),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              color: isVerified
                  ? AppColors.success.withValues(alpha: 0.06)
                  : v.verificationStatus == 'pending'
                  ? AppColors.warning.withValues(alpha: 0.06)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isVerified
                            ? Icons.verified
                            : v.verificationStatus == 'pending'
                            ? Icons.hourglass_top
                            : v.verificationStatus == 'rejected'
                            ? Icons.error_outline
                            : Icons.shield_outlined,
                        color: isVerified
                            ? AppColors.success
                            : v.verificationStatus == 'pending'
                            ? AppColors.warning
                            : v.verificationStatus == 'rejected'
                            ? AppColors.error
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isVerified
                              ? 'Verified Student Seller ✓'
                              : v.verificationStatus == 'pending'
                              ? 'Verification pending – 12–24hr'
                              : v.verificationStatus == 'rejected'
                              ? 'Verification rejected'
                              : 'Unverified – Cash on Delivery only',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isVerified
                                ? AppColors.success
                                : v.verificationStatus == 'rejected'
                                ? AppColors.error
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isVerified) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Verify with Ghana Card or Student ID to unlock:\n• Prepayment / Mobile Money\n• Verified badge\n• Priority search',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: Icon(v.verificationStatus == 'rejected' ? Icons.refresh : Icons.verified_user_outlined, size: 18),
                        label: Text(
                          v.verificationStatus == 'pending'
                              ? 'View Status'
                              : v.verificationStatus == 'rejected'
                              ? 'Re-apply'
                              : 'Verify ID Now',
                        ),
                        onPressed: () => context.push('/vendor/settings/verification'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      'ID: ${v.verificationType ?? 'verified'} • Prepayment unlocked',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ===== Group 3: Operating Hours =====
            _groupLabel('Operating Hours', Icons.access_time),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        v.isClosedToday || v.holidayMode ? Icons.do_not_disturb_on_outlined : Icons.check_circle_outline,
                        color: v.isClosedToday || v.holidayMode ? AppColors.warning : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        v.holidayMode
                            ? 'On break'
                            : v.isClosedToday
                            ? 'Closed today'
                            : 'Open',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: v.isClosedToday || v.holidayMode ? AppColors.warning : AppColors.success,
                        ),
                      ),
                      const Spacer(),
                      Text(hours, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(workingDays, style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                  if ((v.customNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('“${v.customNote}”', style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit hours'),
                      onPressed: () => context.push('/vendor/store/edit'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ===== Group 4: Earnings & Fees – SELLER ONLY =====
            _groupLabel('Earnings & Fees', Icons.account_balance_wallet_outlined, sellerOnly: true),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  _feeRow('Platform fee – products',
                      '${_fee(platformSettings?.platformFeeSellerPercent ?? v.platformFeeRate)}%', 'Seller-only'),
                  const Divider(height: 20),
                  _feeRow('Platform fee – services',
                      '${_fee(platformSettings?.platformFeeServicePercent ?? 8)}%', 'Seller-only'),
                  const Divider(height: 20),
                  _feeRow('Payout schedule', 'T+2 business days', null),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.insights_outlined, size: 18),
                      label: const Text('View Earnings Dashboard'),
                      onPressed: () => context.push('/vendor/earnings'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Platform fees are never shown to buyers – seller dashboard only.',
                    style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            if (!profileCompleted) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: AppColors.warning.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complete your store profile to improve discoverability.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/vendor/store/edit'),
                      child: const Text('Complete'),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ===== Group 5: Settings / Links =====
            _groupLabel('Settings', Icons.settings_outlined),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _navTile(context, AppIcons.user, 'Store Details', 'Working hours, location, bio',
                          () => context.push('/vendor/store/edit')),
                  const Divider(height: 1),
                  _navTile(context, Icons.verified_user_outlined, 'Identity Verification',
                      isVerified ? 'Verified ✓' : 'Ghana Card or Student ID',
                          () => context.push('/vendor/settings/verification'),
                      trailingBadge: isVerified ? '✓' : null,
                      badgeColor: AppColors.success),
                  const Divider(height: 1),
                  _navTile(context, Icons.description_outlined, 'Seller Agreement',
                      'v1.0 – ${v.consentSellerAgreement ? 'Agreed' : 'Review'}',
                          () => context.push('/vendor/agreement')),
                  const Divider(height: 1),
                  _navTile(context, AppIcons.tag, 'Referral Hub', 'Invite friends & earn tokens',
                          () => context.push('/referrals')),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // About / Developer – split out per spec
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _navTile(context, Icons.info_outline, 'About', 'About Campus Marketplace',
                          () => context.push('/profile/about')),
                  const Divider(height: 1),
                  _navTile(context, Icons.code, 'Developer', 'Build info, API, open source',
                          () => context.push('/profile/developer')),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // legacy tiles kept - theme, notifications, passcode
            // ThemeModeTile and NotificationsDiagnosticTile are project-specific – keep if available
            // const ThemeModeTile(),
            // const SizedBox(height: AppSpacing.sm),
            // const NotificationsDiagnosticTile(),

            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: 'Sign Out',
              icon: AppIcons.logout,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                user?.email ?? '',
                style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
          ]
              .animate(interval: 35.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.03, end: 0),
        );
      },
    );
  }

  static String _verificationLabel(String status) {
    switch (status) {
      case 'pending': return 'Verification pending';
      case 'approved': return 'Verified';
      case 'rejected': return 'Verification rejected';
      default: return 'Unverified';
    }
  }

  static String? _shortTime(String? value) {
    if (value == null || value.length < 5) return null;
    return value.substring(0, 5);
  }

  static String _fee(double value) => value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 1);

  Widget _groupLabel(String text, IconData icon, {bool sellerOnly = false}) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          if (sellerOnly) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'SELLER ONLY',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _rowTile(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feeRow(String label, String value, String? tag) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          if (tag != null) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10,
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );
    });
  }

  Widget _navTile(
      BuildContext context,
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap, {
        String? trailingBadge,
        Color? badgeColor,
      }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailingBadge != null
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (badgeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          trailingBadge,
          style: AppTextStyles.labelSmall.copyWith(
            color: badgeColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      )
          : Icon(AppIcons.caretRight, size: 18),
      onTap: onTap,
    );
  }
}
