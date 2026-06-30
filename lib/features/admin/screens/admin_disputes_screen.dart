import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/admin_providers.dart';

/// G4 — Disputes Management.
class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(adminDisputesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminDisputesProvider),
      child: disputes.when(
        loading: () => const SkeletonList(itemCount: 5, itemHeight: 120),
        error: (e, _) => ErrorState(
            message: '$e', onRetry: () => ref.invalidate(adminDisputesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              EmptyState(
                  icon: Icons.gavel_outlined,
                  title: 'No disputes',
                  subtitle: 'Disputes raised by buyers will appear here.'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _DisputeCard(dispute: list[i])
                .animate()
                .fadeIn(delay: (40 * (i % 12)).ms, duration: 280.ms)
                .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

class _DisputeCard extends ConsumerWidget {
  final Dispute dispute;
  const _DisputeCard({required this.dispute});

  Color _statusColor(String s) {
    switch (s) {
      case 'resolved':
        return AppColors.success;
      case 'under_review':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = dispute.status == 'resolved';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dispute.category,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
              ),
              StatusPill(
                  label: dispute.status.replaceAll('_', ' '),
                  color: _statusColor(dispute.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Order #${dispute.orderId.substring(0, 8).toUpperCase()} · '
                '${dispute.studentName ?? 'Buyer'} → ${dispute.vendorName ?? 'Seller'}'
                '${dispute.orderTotal != null ? ' · ${Formatters.money(dispute.orderTotal!)}' : ''}',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(dispute.description,
              style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface)),
          if (dispute.resolution != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Resolution: ${dispute.resolution}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.success)),
          ],
          if (!resolved) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: () => _rule(context, ref, 'refund_buyer',
                      'Full refund to buyer'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Refund Buyer'),
                ),
                OutlinedButton(
                  onPressed: () => _rule(context, ref, 'release_seller',
                      'Payment released to seller'),
                  style:
                  OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Release to Seller'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rule(BuildContext context, WidgetRef ref, String outcome,
      String note) async {
    final ok = await ConfirmActions.confirm(
      context,
      title: 'Apply ruling?',
      message: '$note. Both parties will be notified. This closes the order.',
      confirmLabel: 'Confirm ruling',
      icon: Icons.gavel_outlined,
      destructive: outcome != 'release_seller',
    );
    if (!ok) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveDispute(dispute.disputeId, outcome, note);
      ref.invalidate(adminDisputesProvider);
      if (context.mounted) {
        ConfirmActions.toast(context, 'Dispute resolved', success: true);
      }
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }
}
