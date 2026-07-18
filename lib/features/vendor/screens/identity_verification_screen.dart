// lib/features/vendor/screens/identity_verification_screen.dart
// Phase 2 – Identity Verification Screen (NEW)
// Student ID verification for sellers.

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

enum KycUiState { form, pending, approved, rejected }

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends ConsumerState<IdentityVerificationScreen> {
  final _studentId = TextEditingController();
  final _program = TextEditingController();
  String _year = '1';
  PickedImage? _sidFront;
  PickedImage? _sidBack;
  bool _consent = false;
  bool _submitting = false;
  bool _retrying = false;
  int _submitCount = 0;

  final _storage = StorageService();

  @override
  void dispose() {
    _studentId.dispose();
    _program.dispose();
    super.dispose();
  }

  KycUiState _deriveState(Vendor v) {
    switch (v.verificationStatus) {
      case 'pending': return KycUiState.pending;
      case 'approved': return KycUiState.approved;
      case 'rejected':
        return _retrying ? KycUiState.form : KycUiState.rejected;
      default:
        return KycUiState.form;
    }
  }

  Future<void> _submit(Vendor v) async {
    if (_studentId.text.trim().isEmpty) {
      ConfirmActions.showError(context, 'Student ID number is required');
      return;
    }
    if (_sidFront == null) {
      ConfirmActions.showError(context, 'Student ID front image is required');
      return;
    }
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
      Future<String?> up(PickedImage? p, String name) async {
        if (p == null) return null;
        return _storage.upload(
          bucket: StorageService.kycDocuments,
          bytes: p.bytes,
          fileName: 'kyc/$vendorId/sid/${ts}_$name.jpg',
          publicUrl: false,
        );
      }

      frontUrl = await up(_sidFront, 'front');
      backUrl = await up(_sidBack, 'back');

      await ref.read(vendorRepositoryProvider).submitVerification({
        'verification_type': 'student_id',
        'verification_id_number': _studentId.text.trim(),
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

  Widget _formBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Student ID', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
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
          onPressed: () => setState(() => _retrying = true),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
