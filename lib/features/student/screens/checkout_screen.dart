import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/payment_service.dart';
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
import '../../../models/models.dart';
import '../providers/student_providers.dart';

/// Collects delivery address, contact phone and payment method, shows an order
/// summary, then places the order (cash on delivery) or runs Paystack checkout.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  late PaymentMethod _method = Env.paymentsEnabled
      ? PaymentMethod.mobileMoney
      : PaymentMethod.cashOnDelivery;
  bool _loading = false;

  /// Payment methods available given configuration.
  List<PaymentMethod> get _methods => [
    PaymentMethod.cashOnDelivery,
    if (Env.paymentsEnabled) PaymentMethod.mobileMoney,
  ];

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final total = ref.read(cartTotalProvider);
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Place order?',
      message: _method.isOnline
          ? 'You will pay ${Formatters.money(total)} securely via Mobile Money. '
          'Your payment goes to the shop\'s Mobile Money account.'
          : 'Place this order for ${Formatters.money(total)} (cash on delivery)?',
      confirmLabel: _method.isOnline ? 'Pay now' : 'Place order',
      icon: _method.icon,
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      if (_method.isOnline) {
        await _payWithPaystack();
      } else {
        await _placeCashOrder();
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _placeCashOrder() async {
    await ref.read(studentRepositoryProvider).placeOrderWithDelivery(
      deliveryAddress: _address.text.trim(),
      contactPhone: _phone.text.trim(),
      paymentMethod: _method.db,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    ref.invalidate(cartProvider);
    ref.invalidate(myOrdersProvider);
    if (mounted) _showSuccess();
  }

  Future<void> _payWithPaystack() async {
    final result = await PaymentService().checkout(
      context,
      deliveryAddress: _address.text.trim(),
      contactPhone: _phone.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    if (result.success) {
      ref.invalidate(cartProvider);
      ref.invalidate(myOrdersProvider);
      if (mounted) _showSuccess();
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
          if (mounted) _showSuccess();
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

  void _showSuccess() {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _sectionTitle(context, 'Delivery details', AppIcons.truck),
              const SizedBox(height: AppSpacing.sm + 4),
              AppTextField(
                controller: _address,
                label: 'Delivery address *',
                hint: 'Hall / hostel, room number, landmark…',
                prefixIcon: AppIcons.mapPin,
                minLines: 2,
                maxLines: 3,
                validator: (v) => Validators.required(v, 'Delivery address'),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              AppTextField(
                controller: _phone,
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
                controller: _note,
                label: 'Note for the shop (optional)',
                prefixIcon: AppIcons.note,
              ),
              const SizedBox(height: AppSpacing.lg),
              _sectionTitle(context, 'Payment method', AppIcons.wallet),
              const SizedBox(height: AppSpacing.sm + 4),
              ..._methods.map((m) => _PaymentOption(
                method: m,
                selected: _method == m,
                onTap: () => setState(() => _method = m),
              )),
              if (!Env.paymentsEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Online payment is currently unavailable.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              _sectionTitle(context, 'Order summary', AppIcons.receipt),
              const SizedBox(height: AppSpacing.sm + 4),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                child: Column(
                  children: [
                    ...cart.map((item) => Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: AppTextStyles.titleMedium),
                        Text(Formatters.money(total),
                            style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                      ],
                    ),
                  ],
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
              label: _loading
                  ? 'Processing…'
                  : '${_method.isOnline ? 'Pay' : 'Place Order'} · ${Formatters.money(total)}',
              icon: _loading
                  ? null
                  : (_method.isOnline ? AppIcons.lock : AppIcons.checkFill),
              loading: _loading,
              onPressed: cart.isEmpty ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: AppTextStyles.titleMedium),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label,
                      style: AppTextStyles.titleSmall.copyWith(
                          fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(method.subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0.8,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected ? AppIcons.checkFill : AppIcons.circle,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
