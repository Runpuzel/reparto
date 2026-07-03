// lib/features/vendor/screens/seller_agreement_screen.dart
// Phase 2 – Seller Agreement Screen (NEW) – blocking first-login consent
// v1.0-2025-07

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class SellerAgreementScreen extends ConsumerStatefulWidget {
  const SellerAgreementScreen({super.key});

  @override
  ConsumerState<SellerAgreementScreen> createState() => _SellerAgreementScreenState();
}

class _SellerAgreementScreenState extends ConsumerState<SellerAgreementScreen> {
  final _scrollCtrl = ScrollController();
  double _readPct = 0;
  bool c1 = false, c2 = false, c3 = false, c4 = false, c5 = false;
  bool _saving = false;
  int _seconds = 0;

  bool get _allChecked => c1 && c2 && c3 && c4 && c5;

  void _toggleAll(bool? val) {
    final v = val ?? false;
    setState(() {
      c1 = c2 = c3 = c4 = c5 = v;
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final max = _scrollCtrl.position.maxScrollExtent;
      final off = _scrollCtrl.position.pixels;
      final pct = max <= 0 ? 1.0 : (off / max).clamp(0.0, 1.0);
      if ((pct - _readPct).abs() > 0.01) setState(() => _readPct = pct);
    });
    Stream.periodic(const Duration(seconds: 1)).take(999).listen((i) {
      if (mounted) setState(() => _seconds = i + 1);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _canAgree =>
      _readPct >= 0.90 && c1 && c2 && c3 && c4 && c5 && !_saving;

  Future<void> _agree() async {
    setState(() => _saving = true);
    try {
      final vendor = ref.read(currentVendorProvider).valueOrNull;
      if (vendor == null) throw 'Vendor profile not found';

      final repo = ref.read(vendorRepositoryProvider);
      await repo.recordSellerConsent(vendor.vendorId, {
        'consent_seller_agreement_version': 'v1.0-2025-07',
        'policy_version': 'v1.0-2025-07',
        'scroll_pct': (_readPct * 100).round(),
        'time_on_page_sec': _seconds,
      });

      // Crucial: Wait for the refresh to complete so the router sees the updated state
      await ref.refresh(currentVendorProvider.future);
      
      if (!mounted) return;
      ConfirmActions.toast(context, 'Agreement recorded', success: true);
      context.go('/vendor');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppError.friendly(e)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pctText = '${(_readPct * 100).toInt()}%';
    return PopScope(
      canPop: false, // blocking navigation until consent
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Seller Agreement'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: _readPct, minHeight: 4),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.secondaryContainer.withValues(alpha: .5),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: 8),
              child: Text(
                  'Read $pctText – scroll to enable agreement  •  ${_seconds}s',
                  style: AppTextStyles.bodySmall),
            ),
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                      child: Text('Student Seller Agreement',
                          style: AppTextStyles.headlineSmall)),
                  Center(
                      child: Text('v1.0 – July 2025',
                          style: AppTextStyles.bodySmall)),
                  const SizedBox(height: AppSpacing.lg),
                  _policySection('1. Eligibility',
                      'You must be a currently enrolled student in Ghana, age 16+. False representation leads to immediate suspension.'),
                  _policySection('2. Verification & Trust',
                      'KYC (Ghana Card OR Student ID) is optional to list, required for prepayment. Verified sellers receive a blue “Approved Student Seller” badge.'),
                  _policySection('3. Service Listings & Expiration',
                      'Service listings are free for 14 days, then require a GHS 30 authorization fee for 30 days extension. CURRENT LAUNCH: Free Mode ON – no expiration until admin activates paid mode.'),
                  _policySection('4. Fees',
                      'Platform fee: 5% products, 8% services. Fees are seller-visible only, never shown to buyers. Payouts T+2 business days.'),
                  _policySection('5. Payments & Escrow',
                      'Unverified sellers: Cash on Delivery ONLY. Verified: Mobile Money unlocked. 48hr buyer confirmation / auto-release escrow.'),
                  _policySection('6. Prohibited Items',
                      'No exam malpractice services, alcohol to minors, illicit drugs, weapons, or IP infringement. 3-strike suspension.'),
                  _policySection('7. Data & Privacy (DPA 2012)',
                      'ID data encrypted AES-256, private bucket, admin signed-URL review only. Right to access / delete. Rejected KYC auto-purge 30 days.'),
                  _policySection('8. Disputes & Suspension',
                      '24hr takedown SLA on reports. Disputes freeze payout until admin resolution.'),
                  _policySection('9. Termination',
                      'Either party may terminate. Outstanding payouts held 14 days for dispute window.'),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      children: [
                        _check('Select all requirements', _allChecked, _toggleAll, isBold: true),
                        const Divider(height: 1),
                        _check(
                            'I am a currently enrolled student in Ghana, age 16+',
                            c1,
                            (v) => setState(() => c1 = v ?? false)),
                        _check(
                            'I have read and agree to the Seller Agreement v1.0',
                            c2,
                            (v) => setState(() => c2 = v ?? false)),
                        _check(
                            'I understand service listings expire in 14 days unless I pay the GHS 30 authorization fee (currently Free Mode – no expiration at launch)',
                            c3,
                            (v) => setState(() => c3 = v ?? false)),
                        _check(
                            'I consent to ID verification data processing under Ghana Data Protection Act 2012',
                            c4,
                            (v) => setState(() => c4 = v ?? false)),
                        _check(
                            'I agree to the 5% / 8% platform fee structure (seller-only)',
                            c5,
                            (v) => setState(() => c5 = v ?? false)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: _saving
                  ? 'Saving…'
                  : (_canAgree
                      ? 'Agree & Continue'
                      : 'Read to 90% + check all'),
              icon: _canAgree ? Icons.check_circle : Icons.lock_outline,
              loading: _saving,
              onPressed: _canAgree ? _agree : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _policySection(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body, style: AppTextStyles.bodyMedium),
          ],
        ),
      );

  Widget _check(String text, bool val, ValueChanged<bool?> onChanged, {bool isBold = false}) =>
      CheckboxListTile(
        value: val,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            )),
        onChanged: onChanged,
      );
}
