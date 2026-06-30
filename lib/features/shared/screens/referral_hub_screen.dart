import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/shared_providers.dart';

/// F7 — Referral Hub. Token balance, referral link, how-it-works, redemptions
/// and token history.
class ReferralHubScreen extends ConsumerWidget {
  const ReferralHubScreen({super.key});

  String _link(String code) => 'https://ujustbuy.app/i/$code';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final balance = ref.watch(tokenBalanceProvider).valueOrNull ?? 0;
    final history = ref.watch(tokenHistoryProvider);
    final code = user?.referralCode ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Earn Tokens')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tokenBalanceProvider);
          ref.invalidate(tokenHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: AppRadius.brLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your token balance',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Colors.white70)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('🪙 $balance Tokens',
                      style: AppTextStyles.displayMedium
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tokens expire 6 months after you earn them.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70)),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: AppSpacing.lg),

            // Referral link
            Text('Your referral link', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(_link(code),
                      style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Copy Link',
                          icon: AppIcons.copy,
                          variant: AppButtonVariant.secondary,
                          onPressed: code.isEmpty
                              ? null
                              : () async {
                            await Clipboard.setData(
                                ClipboardData(text: _link(code)));
                            if (context.mounted) {
                              ConfirmActions.toast(context, 'Link copied');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: AppButton(
                          label: 'Share',
                          icon: AppIcons.whatsapp,
                          onPressed:
                          code.isEmpty ? null : () => _share(context, code),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Enter a referral code (for users who didn't arrive via a link)
            AppCard(
              onTap: () => _enterCode(context, ref),
              child: Row(
                children: [
                  Icon(AppIcons.tag, color: scheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Have a referral code?',
                            style: AppTextStyles.titleSmall
                                .copyWith(color: scheme.onSurface)),
                        Text('Enter a friend\'s code to claim your bonus',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  Icon(AppIcons.caretRight, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // How it works
            Text('How it works', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: const [
                  _Step(n: 1, text: 'Share your link with a campus friend.'),
                  _Step(n: 2, text: 'They register and you both get tokens.'),
                  _Step(
                      n: 3,
                      text:
                      'When they complete their first purchase, you get 3 more tokens.'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Redemptions
            Text('Redeem tokens', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _RedeemCard(
              icon: AppIcons.flash,
              title: 'Listing Boost',
              subtitle: '3 days top placement',
              cost: 10,
              balance: balance,
              onRedeem: () => ConfirmActions.toast(context,
                  'Open a listing → Boost with tokens to redeem.'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RedeemCard(
              icon: AppIcons.price,
              title: 'Commission Discount',
              subtitle: 'Waive commission on one listing',
              cost: 5,
              balance: balance,
              onRedeem: () => ConfirmActions.toast(context,
                  'Open a listing → Use tokens to waive its commission.'),
            ),
            const SizedBox(height: AppSpacing.lg),

            // History
            Text('Token history', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(tokenHistoryProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.toll_outlined,
                    title: 'No token activity yet',
                    subtitle: 'Invite a friend to start earning.',
                  );
                }
                return Column(
                  children: list
                      .map((t) => Padding(
                    padding:
                    const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _HistoryTile(txn: t),
                  ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _enterCode(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter referral code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g., A1B2C3D4'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Claim')),
        ],
      ),
    );
    if (entered == null || entered.isEmpty) return;
    try {
      final ok =
      await ref.read(tokensRepositoryProvider).claimReferral(entered);
      ref.invalidate(tokenBalanceProvider);
      ref.invalidate(tokenHistoryProvider);
      if (context.mounted) {
        if (ok) {
          ConfirmActions.toast(context, 'Referral claimed! Tokens added.',
              success: true);
        } else {
          ConfirmActions.showError(context,
              'That code is invalid, already used, or your own.');
        }
      }
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }

  Future<void> _share(BuildContext context, String code) async {
    final msg = Uri.encodeComponent(
        "Hey! I'm using ${AppConstants.appName} to buy and sell stuff on "
            "campus. Join me using my link: ${_link(code)}");
    final url = 'https://wa.me/?text=$msg';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open WhatsApp.');
      }
    }
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text('$n', style: AppTextStyles.labelSmall),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: scheme.onSurface))),
        ],
      ),
    );
  }
}

class _RedeemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int cost;
  final int balance;
  final VoidCallback onRedeem;
  const _RedeemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.balance,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canRedeem = balance >= cost;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                Text('$subtitle · $cost tokens',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          AppButton(
            label: canRedeem ? 'Redeem' : 'Need ${cost - balance} more',
            expand: false,
            variant: AppButtonVariant.secondary,
            onPressed: canRedeem ? onRedeem : null,
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TokenTransaction txn;
  const _HistoryTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final earn = txn.isEarn;
    final color = txn.isExpired
        ? scheme.onSurfaceVariant
        : (earn ? AppColors.success : AppColors.error);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          Icon(earn ? AppIcons.plus : AppIcons.minus, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.reason,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                Text(
                    txn.isExpired
                        ? 'Expired · ${Formatters.dateTime(txn.createdAt)}'
                        : Formatters.dateTime(txn.createdAt),
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text('${earn ? '+' : ''}${txn.delta}',
              style: AppTextStyles.titleSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
