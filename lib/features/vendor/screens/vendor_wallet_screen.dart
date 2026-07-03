import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../data/vendor_repository.dart';
import '../providers/vendor_providers.dart';

class VendorWalletScreen extends ConsumerStatefulWidget {
  const VendorWalletScreen({super.key});

  @override
  ConsumerState<VendorWalletScreen> createState() => _VendorWalletScreenState();
}

class _VendorWalletScreenState extends ConsumerState<VendorWalletScreen> {
  final _amount = TextEditingController(text: '50');
  String? _pendingReference;
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(vendorWalletProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(vendorWalletProvider),
      child: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(vendorWalletProvider),
        ),
        data: (data) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('COD commission wallet', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Commission is reserved when you confirm a Cash on Delivery order and charged only after delivery.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _BalancePanel(wallet: data),
            const SizedBox(height: 16),
            _TopUpPanel(
              controller: _amount,
              loading: _loading,
              pendingReference: _pendingReference,
              onTopUp: _startTopUp,
              onVerify: _verifyTopUp,
            ),
            const SizedBox(height: 24),
            Text('Activity', style: AppTextStyles.titleMedium),
            const SizedBox(height: 10),
            if (data.transactions.isEmpty)
              const _EmptyActivity()
            else
              ...data.transactions.map(_TransactionTile.new),
          ],
        ),
      ),
    );
  }

  Future<void> _startTopUp() async {
    final cedis = double.tryParse(_amount.text.trim());
    if (cedis == null || cedis < 5) {
      ConfirmActions.showError(context, 'Enter at least GH5.');
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await supabase.functions.invoke(
        'wallet-topup-initialize',
        body: {'amount_pesewas': Money.fromCedis(cedis)},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final reference = data['reference'] as String?;
      final url = data['authorization_url'] as String?;
      if (reference == null || url == null) {
        throw data['error'] ?? 'Could not initialize top-up';
      }
      setState(() => _pendingReference = reference);
      final opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!opened) throw 'Could not open secure payment';
    } catch (error) {
      if (mounted) ConfirmActions.showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyTopUp() async {
    final reference = _pendingReference;
    if (reference == null) return;
    setState(() => _loading = true);
    try {
      final response = await supabase.functions.invoke(
        'wallet-topup-verify',
        body: {'reference': reference},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['status'] != 'paid') {
        throw data['message'] ?? data['error'] ?? 'Payment is not complete';
      }
      _pendingReference = null;
      ref.invalidate(vendorWalletProvider);
      if (mounted) {
        ConfirmActions.toast(context, 'Wallet funded', success: true);
      }
    } catch (error) {
      if (mounted) ConfirmActions.showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.wallet});
  final VendorWallet wallet;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            _BalanceValue('Available', Money.format(wallet.availablePesewas)),
            _BalanceValue('Reserved', Money.format(wallet.reservedPesewas)),
          ],
        ),
      );
}

class _BalanceValue extends StatelessWidget {
  const _BalanceValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            Text(value, style: AppTextStyles.headlineSmall),
          ],
        ),
      );
}

class _TopUpPanel extends StatelessWidget {
  const _TopUpPanel({
    required this.controller,
    required this.loading,
    required this.pendingReference,
    required this.onTopUp,
    required this.onVerify,
  });
  final TextEditingController controller;
  final bool loading;
  final String? pendingReference;
  final VoidCallback onTopUp;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add funds', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Amount', prefixText: 'GH '),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: pendingReference == null
                  ? 'Continue to secure payment'
                  : 'I have completed payment',
              icon: pendingReference == null
                  ? Icons.open_in_new
                  : Icons.verified_outlined,
              loading: loading,
              onPressed: pendingReference == null ? onTopUp : onVerify,
            ),
          ],
        ),
      );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);
  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.kind == 'topup' || transaction.kind == 'release';
    final color = incoming ? AppColors.success : AppColors.warning;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(incoming ? Icons.south_west : Icons.north_east,
            color: color, size: 18),
      ),
      title: Text(transaction.description),
      subtitle: Text(transaction.createdAt.toString().split('.').first),
      trailing: Text(
        '${incoming ? '+' : '-'}${Money.format(transaction.amountPesewas)}',
        style: AppTextStyles.labelMedium.copyWith(color: color),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('Wallet activity will appear here.'),
      );
}
