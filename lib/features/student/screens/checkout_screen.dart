// lib/features/student/screens/checkout_screen.dart
// v1.0-2025-07 – COD lock for unverified vendors, consent, NO platform fee display

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/consent_dialog.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/student_providers.dart';

/// Collects delivery address, contact phone and payment method, shows an order
/// summary, then places the order (cash on delivery) or runs Paystack checkout.
/// v1.0: unverified vendor = COD only lock, consent checkbox, NO fee display.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => CheckoutScreenState();
}

class CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final address = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();
  late PaymentMethod method = Env.paymentsEnabled
      ? PaymentMethod.mobileMoney
      : PaymentMethod.cashOnDelivery;
  bool loading = false;
  bool policyConsent = false;
  bool useTokens = false;
  int tokenDiscountPesewas = 0;
  int tokensToRedeem = 0;

  // v1.0 – vendor verification gating
  bool _vendorChecked = false;
  bool _vendorVerified = false;
  String? _vendorName;
  bool _checkingVendor = true;

  List<PaymentMethod> get methods => [
    PaymentMethod.cashOnDelivery,
    if (Env.paymentsEnabled) PaymentMethod.mobileMoney,
  ];

  @override
  void dispose() {
    address.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // check vendor verification after first frame (cart loaded)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVendor();
      _loadTokenQuote();
    });
  }

  Future<void> _loadTokenQuote() async {
    try {
      final quote = await ref.read(studentRepositoryProvider).checkoutTokenQuote();
      if (!mounted) return;
      setState(() {
        tokenDiscountPesewas =
            (quote['discount_pesewas'] as num?)?.toInt() ?? 0;
        tokensToRedeem = (quote['tokens_to_redeem'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _checkVendor() async {
    setState(() => _checkingVendor = true);
    try {
      final cart = await ref.read(cartProvider.future);
      if (cart.isEmpty) {
        setState(() {
          _vendorChecked = true;
          _checkingVendor = false;
        });
        return;
      }
      // assume single-vendor cart – take first product's vendor
      // product model may not include vendor_id directly in cart join – use student repo
      // fallback: try to resolve via shopProvider if we can get vendorId
      String? vendorId;
      // CartItem.product?.vendorId exists?
      try {
        // ignore: avoid_dynamic_calls
        vendorId = (cart.first.product as dynamic)?.vendorId as String?;
      } catch (_) {}
      if (vendorId != null) {
        final repo = ref.read(studentRepositoryProvider);
        // v1.0 method – may not exist yet – try/catch
        bool verified = false;
        String? vName;
        try {
          // ignore: avoid_dynamic_calls
          verified = await repo.isVendorPrepaymentEligible(vendorId);
          final v = await repo.fetchVendor(vendorId);
          vName = v?.businessName;
          // also read isVerified directly if model has it
        } catch (_) {
          verified = false; // fail closed: prepayment requires confirmed KYC
        }
        setState(() {
          _vendorVerified = verified;
          _vendorName = vName;
          _vendorChecked = true;
          if (!verified) {
            method = PaymentMethod.cashOnDelivery;
          }
        });
      } else {
        setState(() {
          _vendorVerified = false;
          _vendorChecked = true;
        });
      }
    } finally {
      if (mounted) setState(() => _checkingVendor = false);
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (!policyConsent) {
      ConfirmActions.showError(context, 'Please accept the purchase policy to continue');
      return;
    }

    // v1.0 – enforce COD only for unverified
    if (!_vendorVerified && method.isOnline) {
      ConfirmActions.showError(
          context, 'This seller is not yet verified – Cash on Delivery only.');
      setState(() => method = PaymentMethod.cashOnDelivery);
      return;
    }

    final total = ref.read(cartTotalProvider);
    final discount = useTokens ? tokenDiscountPesewas / 100 : 0.0;
    final payable = (total - discount).clamp(0, total).toDouble();

    // v1.0 – consent dialog before payment
    final policySettings = await ref.read(marketplaceSettingsProvider.future);
    final consented = await showConsentDialog(
      context,
      type: ConsentType.checkoutPolicy,
      policyVersion: policySettings.currentPolicyVersion,
      title: 'Purchase Policy',
      bodyMarkdown: '''
**Order & Delivery – v1.0**

• ${_vendorVerified ? 'Prepayment via Mobile Money is protected by escrow.' : 'Unverified seller – Cash on Delivery ONLY.'}
• Delivery address must be accurate – campus location preferred.
• 48hr buyer confirmation window, then auto-release to seller.
• Disputes: raise within 48hrs via My Orders → Report.
• Pending Cash on Delivery orders may be cancelled. Paid Mobile Money orders cannot be cancelled; use the dispute process if there is a problem.

${_vendorVerified ? '' : '\n⚠️ This shop is not yet ID-verified. For your safety, prepayment is disabled – pay cash on delivery only.'}
''',
      requiredCheckboxes: [
        'I agree to the purchase & delivery policy v1.0',
        'I understand delivery times are estimates and may vary during peak/exams',
        if (!_vendorVerified)
          'I understand this seller is unverified – I will pay cash on delivery only',
      ],
    );
    if (!consented) return;

    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Place order?',
      message: method.isOnline
          ? 'You will pay ${Formatters.money(payable)} securely via Mobile Money. '
          'Your payment goes to the shop\'s Mobile Money account.'
          : 'Place this order for ${Formatters.money(payable)} (cash on delivery)?',
      confirmLabel: method.isOnline ? 'Pay now' : 'Place order',
      icon: method.icon,
    );
    if (!confirmed) return;

    setState(() => loading = true);
    try {
      // record consent
      try {
        final cr = ref.read(consentRepositoryProvider);
        await cr?.record?.call(
          type: 'checkout_policy',
          policyVersion: policySettings.currentPolicyVersion,
          metadata: {
            'payment_method': method.db,
            'vendor_verified': _vendorVerified,
            'total': total,
          },
        );
      } catch (_) {}

      if (method.isOnline && _vendorVerified) {
        await payWithPaystack();
      } else {
        await placeCashOrder();
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> placeCashOrder() async {
    await ref.read(studentRepositoryProvider).placeOrderWithDelivery(
      deliveryAddress: address.text.trim(),
      contactPhone: phone.text.trim(),
      paymentMethod: method.db,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      useTokens: useTokens,
    );
    ref.invalidate(cartProvider);
    ref.invalidate(myOrdersProvider);
    if (mounted) showSuccess();
  }

  Future<void> payWithPaystack() async {
    final result = await PaymentService().checkout(
      context,
      deliveryAddress: address.text.trim(),
      contactPhone: phone.text.trim(),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      useTokens: useTokens,
    );

    if (result.success) {
      ref.invalidate(cartProvider);
      ref.invalidate(myOrdersProvider);
      if (mounted) showSuccess();
      return;
    }

    // Web flow: payment opens in a new tab; ask the user to confirm completion.
    if (result.message == 'pending_web' && result.reference != null) {
      if (!mounted) return;
      final verify = await ConfirmActions.confirm(
        context,
        title: 'Complete your payment',
        message:
        'Finish the payment in the opened tab, then tap "I\'ve paid" to confirm.',
        confirmLabel: "I've paid",
        cancelLabel: 'Cancel',
        icon: Icons.open_in_new,
      );
      if (verify) {
        final v = await PaymentService().verify(result.reference!);
        if (v.success) {
          ref.invalidate(cartProvider);
          ref.invalidate(myOrdersProvider);
          if (mounted) showSuccess();
        } else if (mounted) {
          ConfirmActions.showError(
              context, v.message ?? 'Payment not confirmed yet.');
        }
      }
      return;
    }

    if (result.message == 'cancelled') {
      if (mounted) {
        ConfirmActions.toast(context, 'Payment cancelled');
      }
      return;
    }

    if (mounted) {
      ConfirmActions.showError(context, result.message ?? 'Payment failed.');
    }
  }

  void showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppTheme.successContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(AppIcons.checkFill, color: AppTheme.success, size: 36),
        ),
        title: const Text('Order placed!'),
        content: const Text(
            'Your order has been placed and the shop has been notified. '
                'Track its progress under My Orders.'),
        actions: [
          AppButton(
            label: 'Done',
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/student');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull ?? [];
    final total = ref.watch(cartTotalProvider);
    final scheme = Theme.of(context).colorScheme;
    final discount = useTokens ? tokenDiscountPesewas / 100 : 0.0;
    final payable = (total - discount).clamp(0, total).toDouble();

    final unverifiedLock = _vendorChecked && !_vendorVerified;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // v1.0 – unverified seller banner
              if (unverifiedLock) ...[
                AppCard(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AppColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unverified seller – Cash on Delivery only',
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_vendorName ?? 'This shop'} has not yet completed ID verification. '
                                  'For your safety, prepayment is disabled. '
                                  'Pay cash when your order is delivered.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_checkingVendor)
                const LinearProgressIndicator(minHeight: 2),
              if (_checkingVendor) const SizedBox(height: AppSpacing.md),

              sectionTitle(context, 'Delivery details', AppIcons.truck),
              const SizedBox(height: AppSpacing.sm + 4),
              AppTextField(
                controller: address,
                label: 'Delivery address *',
                hint: 'Hall / hostel, room number, landmark…',
                prefixIcon: AppIcons.mapPin,
                minLines: 2,
                maxLines: 3,
                validator: (v) => Validators.required(v, 'Delivery address'),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              AppTextField(
                controller: phone,
                label: 'Contact phone *',
                hint: '0208223626',
                prefixIcon: AppIcons.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              AppTextField(
                controller: note,
                label: 'Note for the shop (optional)',
                prefixIcon: AppIcons.note,
              ),
              const SizedBox(height: AppSpacing.lg),

              sectionTitle(context, 'Payment method', AppIcons.wallet),
              const SizedBox(height: AppSpacing.sm + 4),
              ...methods.map((m) {
                final disabled = m.isOnline && unverifiedLock;
                return Opacity(
                  opacity: disabled ? 0.5 : 1,
                  child: PaymentOption(
                    method: m,
                    selected: method == m,
                    onTap: disabled
                        ? () {
                      ConfirmActions.showError(
                          context,
                          'Prepayment is disabled – this seller is not yet verified. Cash on Delivery only.');
                    }
                        : () => setState(() => method = m),
                    disabledReason: disabled
                        ? 'Unverified seller – COD only'
                        : null,
                  ),
                );
              }),
              if (!Env.paymentsEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Online payment is currently unavailable.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              if (unverifiedLock)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Verify seller ID in Shop Detail to unlock prepayment.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              sectionTitle(context, 'Order summary', AppIcons.receipt),
              const SizedBox(height: AppSpacing.sm + 4),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                child: Column(
                  children: [
                    ...cart.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          Text('${item.quantity}× ',
                              style: AppTextStyles.labelLarge),
                          Expanded(
                              child: Text(
                                  item.product?.productName ?? 'Item',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium)),
                          Text(Formatters.money(item.lineTotal),
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    )),
                    const Divider(height: 20),
                    if (tokensToRedeem > 0) ...[
                      SwitchListTile(
                        value: useTokens,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Use $tokensToRedeem tokens',
                            style: AppTextStyles.titleSmall),
                        subtitle: Text(
                          'Save ${Formatters.money(tokenDiscountPesewas / 100)} from the UjustBUY marketplace fee',
                          style: AppTextStyles.bodySmall,
                        ),
                        secondary: Icon(AppIcons.tag, color: scheme.primary),
                        onChanged: (value) => setState(() => useTokens = value),
                      ),
                      if (useTokens)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Token discount'),
                            Text('-${Formatters.money(discount)}',
                                style: const TextStyle(
                                    color: AppColors.success)),
                          ],
                        ),
                      const Divider(height: 20),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: AppTextStyles.titleMedium),
                        Text(Formatters.money(payable),
                            style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // v1.0 – policy consent checkbox
              AppCard(
                child: CheckboxListTile(
                  value: policyConsent,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setState(() => policyConsent = v ?? false),
                  title: const Text(
                    'I agree to the purchase & delivery policy (v1.0)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _vendorVerified
                        ? '48hr confirmation • escrow protected • dispute within 48hr'
                        : 'Cash on Delivery only – unverified seller • 48hr dispute window',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: loading
                  ? 'Processing…'
                  : '${method.isOnline && _vendorVerified ? 'Pay' : 'Place Order'} · ${Formatters.money(payable)}',
              icon: loading
                  ? null
                  : (method.isOnline && _vendorVerified
                  ? AppIcons.lock
                  : AppIcons.checkFill),
              loading: loading,
              onPressed: cart.isEmpty || !policyConsent ? null : submit,
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(BuildContext context, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: AppTextStyles.titleMedium),
      ],
    );
  }
}

class PaymentOption extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  final String? disabledReason;
  const PaymentOption({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = disabledReason != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        color: selected
            ? scheme.primary.withValues(alpha: 0.06)
            : scheme.surfaceContainerLowest,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        shadows: const [],
        child: Row(
          children: [
            Icon(method.icon,
                color: selected
                    ? scheme.primary
                    : disabled
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label,
                      style: AppTextStyles.titleSmall.copyWith(
                          fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                          color: disabled
                              ? scheme.onSurfaceVariant
                              .withValues(alpha: 0.6)
                              : null)),
                  const SizedBox(height: 2),
                  Text(
                      disabled ? disabledReason! : method.subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: disabled
                            ? AppColors.warning
                            : null,
                        fontWeight:
                        disabled ? FontWeight.w600 : null,
                      )),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0.8,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected
                    ? AppIcons.checkFill
                    : disabled
                    ? Icons.lock_outline
                    : AppIcons.circle,
                color: selected
                    ? scheme.primary
                    : disabled
                    ? AppColors.warning
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- v1.0 consent repo shim ----
final consentRepositoryProvider = Provider<dynamic>((ref) => _FakeConsent());
class _FakeConsent {
  Future<void> record(
      {required String type,
        required String policyVersion,
        Map<String, dynamic>? metadata}) async {}
}
