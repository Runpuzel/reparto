// lib/features/vendor/screens/seller_agreement_screen.dart
// Phase 2 – Seller Agreement Screen (NEW) – blocking first-login consent
// v1.0-2025-07

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/listing_policy.dart';
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
        'consent_seller_agreement_version': 'v2.0-2026-07',
        'policy_version': 'v2.0-2026-07',
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
                      child: Text('v2.0 - July 2026',
                          style: AppTextStyles.bodySmall)),
                  const SizedBox(height: AppSpacing.lg),
                  _policySection('1. Eligibility',
                      'You may access your seller account immediately after registration. You must be a currently enrolled student in Ghana and at least 16 years old. False identity or enrollment information may lead to suspension.'),
                  _policySection('2. Identity and listing allowance',
                      'Identity verification is optional for your first $unverifiedListingLimit combined product and service listings. Before publishing listing ${unverifiedListingLimit + 1}, submit a valid Student ID and receive admin approval. Editing an existing listing does not use another slot.'),
                  _policySection('3. Account review',
                      'General admin approval is not required to sign in or publish within the starter allowance. Admins may review or remove unsafe or misleading content and suspend accounts that breach these rules.'),
                  _policySection('4. Listings and stock',
                      'Stock, price, description, images, location, and availability must be accurate. Product stock decreases when ordered and is restored after cancellation. Service duration and authorization charges follow current Platform Settings.'),
                  _policySection('5. Fees and Cash on Delivery',
                      'The current marketplace fee is shown in the app as a percentage. For COD orders it is reserved from your prepaid wallet when you confirm an order, captured after delivery, and returned if the order is cancelled.'),
                  _policySection('6. Prepayment and payouts',
                      'Prepayment is available only to identity-verified sellers. Eligible buyer payments remain protected until receipt confirmation or automatic release. The marketplace fee is retained and seller net proceeds are submitted to the registered payout account.'),
                  _policySection('7. Prohibited items',
                      'No exam malpractice services, alcohol to minors, illicit drugs, weapons, or IP infringement. 3-strike suspension.'),
                  _policySection('8. Privacy and identity documents',
                      'Identity documents are used only for verification and fraud prevention with restricted admin access. Data rights are handled under Ghana\'s Data Protection Act, 2012 (Act 843).'),
                  _policySection('9. Orders and disputes',
                      'Fulfil orders accurately and update statuses honestly. A dispute pauses payout while an admin reviews evidence. A ruling may refund the buyer or release payment to the seller.'),
                  _policySection('10. Suspension and termination',
                      'Serious safety, fraud, identity, payment, or repeated fulfilment violations may cause listing removal or suspension. Valid unsettled orders, refunds, marketplace fees, and disputes remain enforceable after closure.'),
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
                            'I have read and agree to the Seller Agreement v2.0',
                            c2,
                            (v) => setState(() => c2 = v ?? false)),
                        _check(
                            'I understand identity approval is required before publishing more than $unverifiedListingLimit combined listings',
                            c3,
                            (v) => setState(() => c3 = v ?? false)),
                        _check(
                            'I consent to ID verification data processing under Ghana Data Protection Act 2012',
                            c4,
                            (v) => setState(() => c4 = v ?? false)),
                        _check(
                            'I agree to displayed fees, escrow rules, and the COD marketplace fee wallet process',
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
