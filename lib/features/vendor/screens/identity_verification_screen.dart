// lib/features/vendor/screens/identity_verification_screen.dart
// Phase 2 – Identity Verification Screen (NEW)
// v1.0-2025-07 – Ghana Card OR Student ID – post-registration KYC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/consent_dialog.dart';
import '../../../core/widgets/image_upload_field.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

enum KycType { ghanaCard, studentId }
enum KycUiState { choose, form, pending, approved, rejected }

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends ConsumerState<IdentityVerificationScreen> {
  KycType? _type;
  // Ghana Card
  final _gcName = TextEditingController();
  final _gcNumber = TextEditingController();
  PickedImage? _gcFront;
  PickedImage? _gcBack;
  // Student ID
  final _studentId = TextEditingController();
  final _program = TextEditingController();
  String _year = '1';
  PickedImage? _sidFront;
  PickedImage? _sidBack;
  bool _consent = false;
  bool _submitting = false;
  int _submitCount = 0;

  final _storage = StorageService();

  @override
  void dispose() {
    _gcName.dispose();
    _gcNumber.dispose();
    _studentId.dispose();
    _program.dispose();
    super.dispose();
  }

  KycUiState _deriveState(Vendor v) {
    switch (v.verificationStatus) {
      case 'pending': return KycUiState.pending;
      case 'approved': return KycUiState.approved;
      case 'rejected': return KycUiState.rejected;
      default: return _type == null ? KycUiState.choose : KycUiState.form;
    }
  }

  Future<void> _submit(Vendor v) async {
    if (!_consent) {
      ConfirmActions.showError(context, 'Please accept the DPA consent to continue');
      return;
    }
    if (_submitCount >= 3) {
      ConfirmActions.showError(context, 'Rate limit: 3 submissions / 24h');
      return;
    }

    final settings = await ref.read(vendorPlatformSettingsProvider.future);
    final ok = await showConsentDialog(
      context,
      type: ConsentType.verificationSubmit,
      policyVersion: settings.currentPolicyVersion,
      title: 'ID Verification Consent',
      bodyMarkdown: '''
**Ghana Data Protection Act 2012**
- Your ID images are encrypted at rest (AES-256).
- Stored in a private secure bucket.
- Used solely for identity verification.
- Rejected documents are deleted after 30 days.
''',
      requiredCheckboxes: [
        'I consent to ID verification data processing under Ghana DPA 2012',
        'I confirm the documents uploaded are my own and valid',
      ],
    );
    if (!ok) return;

    setState(() => _submitting = true);
    try {
      String? frontUrl, backUrl;
      final vendorId = v.vendorId;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final isGc = _type == KycType.ghanaCard;

      Future<String?> up(PickedImage? p, String name) async {
        if (p == null) return null;
        return _storage.upload(
          bucket: StorageService.kycDocuments,
          bytes: p.bytes,
          fileName: 'kyc/$vendorId/${isGc ? 'gc' : 'sid'}/${ts}_$name.jpg',
          publicUrl: false,
        );
      }

      if (isGc) {
        frontUrl = await up(_gcFront, 'front');
        backUrl = await up(_gcBack, 'back');
      } else {
        frontUrl = await up(_sidFront, 'front');
        backUrl = await up(_sidBack, 'back');
      }

      await ref.read(vendorRepositoryProvider).submitVerification({
        'verification_type': isGc ? 'ghana_card' : 'student_id',
        'verification_id_number': isGc ? _gcNumber.text.trim().toUpperCase() : _studentId.text.trim(),
        'verification_front_url': frontUrl,
        'verification_back_url': backUrl,
        'verification_status': 'pending',
        'verification_submitted_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(currentVendorProvider);
      if (mounted) {
        ConfirmActions.toast(context, 'Verification submitted for review', success: true);
        setState(() => _submitCount++);
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorAsync = ref.watch(currentVendorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: AsyncView<Vendor?>(
        value: vendorAsync,
        onRetry: () => ref.invalidate(currentVendorProvider),
        data: (v) {
          if (v == null) return const Center(child: Text('Vendor sign-in required'));
          final state = _deriveState(v);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(currentVendorProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _buildHeader(v, state),
                const SizedBox(height: AppSpacing.lg),
                switch (state) {
                  KycUiState.choose => _chooseType(),
                  KycUiState.form => _formBody(),
                  KycUiState.pending => _pendingCard(v),
                  KycUiState.approved => _approvedCard(v),
                  KycUiState.rejected => _rejectedCard(v),
                }
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Vendor v, KycUiState s) {
    final color = v.isVerified ? AppColors.success : s == KycUiState.rejected ? AppColors.error : AppColors.warning;
    final icon = v.isVerified ? Icons.verified : s == KycUiState.pending ? Icons.hourglass_top : Icons.shield_outlined;
    final label = v.isVerified ? 'Verified Student Seller ✓' : s == KycUiState.pending ? 'Review pending' : s == KycUiState.rejected ? 'Verification rejected' : 'Unverified – COD only';
    return AppCard(
      color: color.withValues(alpha: .08),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.titleMedium.copyWith(color: color, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _chooseType() {
    final allowed = ref.watch(vendorPlatformSettingsProvider).valueOrNull
            ?.kycAllowedTypes ??
        const ['ghana_card', 'student_id'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select verification method:', style: AppTextStyles.titleSmall),
        const SizedBox(height: 12),
        if (allowed.contains('ghana_card')) _typeCard(
          title: 'Ghana Card',
          subtitle: 'Recommended – Quick verification',
          icon: AppIcons.badge,
          onTap: () => setState(() => _type = KycType.ghanaCard),
        ),
        if (allowed.contains('ghana_card') && allowed.contains('student_id'))
          const SizedBox(height: AppSpacing.md),
        if (allowed.contains('student_id')) _typeCard(
          title: 'Student ID',
          subtitle: 'Valid student ID card',
          icon: Icons.school_outlined,
          onTap: () => setState(() => _type = KycType.studentId),
        ),
      ],
    );
  }

  Widget _typeCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.titleMedium),
          Text(subtitle, style: AppTextStyles.bodySmall),
        ])),
        const Icon(Icons.chevron_right),
      ]),
    );
  }

  Widget _formBody() {
    final isGc = _type == KycType.ghanaCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(isGc ? 'Ghana Card' : 'Student ID', style: AppTextStyles.titleLarge),
            const Spacer(),
            TextButton(onPressed: () => setState(() => _type = null), child: const Text('Change')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (isGc) ...[
          AppTextField(controller: _gcName, label: 'Full name on card *', prefixIcon: AppIcons.user),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _gcNumber, label: 'Ghana Card Number *', hint: 'GHA-123456789-0', prefixIcon: AppIcons.badge),
          const SizedBox(height: AppSpacing.md),
          ImageUploadField(label: 'Card front *', icon: Icons.badge_outlined, onPicked: (p)=> _gcFront = p),
          const SizedBox(height: AppSpacing.md),
          ImageUploadField(label: 'Card back *', icon: Icons.badge_outlined, onPicked: (p)=> _gcBack = p),
        ] else ...[
          AppTextField(controller: _studentId, label: 'Student ID number *', prefixIcon: AppIcons.badge),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _program, label: 'Program *', prefixIcon: AppIcons.user),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _year,
            decoration: const InputDecoration(labelText: 'Year of study'),
            items: ['1','2','3','4'].map((y)=>DropdownMenuItem(value:y, child: Text('Year $y'))).toList(),
            onChanged: (v)=> setState(()=> _year = v ?? '1'),
          ),
          const SizedBox(height: AppSpacing.md),
          ImageUploadField(label: 'Student ID front *', icon: Icons.credit_card, onPicked: (p)=> _sidFront = p),
          const SizedBox(height: AppSpacing.md),
          ImageUploadField(label: 'Student ID back (optional)', icon: Icons.credit_card, onPicked: (p)=> _sidBack = p),
        ],
        const SizedBox(height: AppSpacing.lg),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v)=> setState(()=> _consent = v ?? false),
          title: const Text('I consent to ID verification per Ghana Data Protection Act 2012.', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: _submitting ? 'Submitting…' : 'Submit for Review',
          icon: _submitting ? null : Icons.verified_user_outlined,
          loading: _submitting,
          onPressed: () {
            final v = ref.read(currentVendorProvider).valueOrNull;
            if (v != null) _submit(v);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Review takes 12–24 hours', style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _pendingCard(Vendor v) {
    return AppCard(
      child: Column(children: [
        const Icon(Icons.hourglass_top, size: 48, color: AppColors.warning),
        const SizedBox(height: 12),
        Text('Verification submitted', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        const Text('Our team is reviewing your documents. You\'ll be notified once approved.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: ()=> ref.invalidate(currentVendorProvider), child: const Text('Refresh status')),
      ]),
    );
  }

  Widget _approvedCard(Vendor v) {
    return AppCard(
      color: AppColors.success.withValues(alpha: .07),
      child: Column(children: [
        const Icon(Icons.verified, size: 56, color: AppColors.success),
        const SizedBox(height: 12),
        Text('Verified Student Seller ✓', style: AppTextStyles.titleLarge.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('You have full access to Mobile Money payments and priority search ranking.', textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _rejectedCard(Vendor v) {
    final reason = v.verificationRejectedReason ?? 'Documents unclear – please resubmit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.error.withValues(alpha: 0.06),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 44, color: AppColors.error),
              const SizedBox(height: 8),
              Text('Verification rejected', style: AppTextStyles.titleMedium.copyWith(color: AppColors.error)),
              const SizedBox(height: 8),
              Text(reason, textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Try Again',
          icon: Icons.refresh,
          onPressed: () => setState(() => _type = null),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
