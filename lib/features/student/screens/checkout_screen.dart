import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_actions.dart';
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
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        title: const Text('Order placed!'),
        content: const Text(
            'Your order has been placed and the shop has been notified. '
                'Track its progress under My Orders.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/student');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull ?? [];
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(
                  context, 'Delivery details', Icons.local_shipping_outlined),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Delivery address *',
                  hintText: 'Hall / hostel, room number, landmark…',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => Validators.required(v, 'Delivery address'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Contact phone *',
                  hintText: '0208223626',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Note for the shop (optional)',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Payment method', Icons.payment_outlined),
              const SizedBox(height: 12),
              ..._methods.map((m) => _PaymentOption(
                method: m,
                selected: _method == m,
                onTap: () => setState(() => _method = m),
              )),
              if (!Env.paymentsEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Online payment is currently unavailable.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 24),
              _sectionTitle(
                  context, 'Order summary', Icons.receipt_long_outlined),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      ...cart.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('${item.quantity}× ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Expanded(
                                child: Text(
                                    item.product?.productName ?? 'Item',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Text(Formatters.money(item.lineTotal)),
                          ],
                        ),
                      )),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(Formatters.money(total),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color:
                                  Theme.of(context).colorScheme.primary)),
                        ],
                      ),
                    ],
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
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: (_loading || cart.isEmpty) ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
                  : Icon(_method.isOnline
                  ? Icons.lock_outline
                  : Icons.check_circle_outline),
              label: Text(_loading
                  ? 'Processing…'
                  : '${_method.isOnline ? 'Pay' : 'Place Order'} · ${Formatters.money(total)}'),
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
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? scheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(method.icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.label,
                        style: TextStyle(
                            fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(method.subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
