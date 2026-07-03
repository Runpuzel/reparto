import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

class AdminDisputesScreen extends ConsumerStatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  ConsumerState<AdminDisputesScreen> createState() =>
      _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends ConsumerState<AdminDisputesScreen> {
  String _status = 'active';
  String _query = '';
  String? _busyId;

  Future<void> _refresh() async {
    ref.invalidate(adminDisputesProvider);
    ref.invalidate(adminDisputeKpisProvider);
  }

  @override
  Widget build(BuildContext context) {
    final disputes = ref.watch(adminDisputesProvider);
    final kpis = ref.watch(adminDisputeKpisProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: disputes.when(
        loading: () => const SkeletonList(itemCount: 5, itemHeight: 180),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: _refresh,
        ),
        data: (items) {
          final filtered = items.where(_matches).toList();
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DisputeHeader(
                  kpis: kpis.valueOrNull,
                  status: _status,
                  onStatusChanged: (value) => setState(() => _status = value),
                  onQueryChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.gavel_outlined,
                    title: items.isEmpty ? 'No disputes' : 'No matching disputes',
                    subtitle: items.isEmpty
                        ? 'New buyer disputes will appear in this review queue.'
                        : 'Adjust the status filter or search terms.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final dispute = filtered[index];
                      return _DisputeCard(
                        dispute: dispute,
                        busy: _busyId == dispute.disputeId,
                        onReview: () => _markUnderReview(dispute),
                        onRule: (outcome) => _rule(dispute, outcome),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _matches(Dispute dispute) {
    final statusMatches = _status == 'all' ||
        (_status == 'active'
            ? !dispute.isResolved
            : dispute.status == _status);
    if (!statusMatches) return false;
    if (_query.isEmpty) return true;
    return dispute.category.toLowerCase().contains(_query) ||
        dispute.description.toLowerCase().contains(_query) ||
        dispute.orderId.toLowerCase().contains(_query) ||
        (dispute.studentName ?? '').toLowerCase().contains(_query) ||
        (dispute.vendorName ?? '').toLowerCase().contains(_query);
  }

  Future<void> _markUnderReview(Dispute dispute) async {
    setState(() => _busyId = dispute.disputeId);
    try {
      await ref
          .read(adminRepositoryProvider)
          .markDisputeUnderReview(dispute.disputeId);
      await _refresh();
      if (mounted) {
        ConfirmActions.toast(context, 'Dispute moved to review', success: true);
      }
    } catch (error) {
      if (mounted) ConfirmActions.showError(context, error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _rule(Dispute dispute, String outcome) async {
    final note = await _showRulingDialog(context, outcome);
    if (note == null || !mounted) return;
    setState(() => _busyId = dispute.disputeId);
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveDispute(dispute.disputeId, outcome, note);
      await _refresh();
      if (mounted) {
        ConfirmActions.toast(context, 'Ruling applied', success: true);
      }
    } catch (error) {
      if (mounted) ConfirmActions.showError(context, error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _DisputeHeader extends StatelessWidget {
  const _DisputeHeader({
    required this.kpis,
    required this.status,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  final DisputeKpis? kpis;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispute review queue', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Review evidence, track active cases, and record final rulings.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip('Open', kpis?.open ?? 0, AppColors.warning),
                _SummaryChip(
                    'Under review', kpis?.underReview ?? 0, AppColors.info),
                _SummaryChip(
                    'Resolved', kpis?.resolved ?? 0, AppColors.success),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search order, buyer, seller, or issue',
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(
                      value: 'under_review', label: Text('Under review')),
                  ButtonSegment(value: 'resolved', label: Text('Resolved')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {status},
                onSelectionChanged: (value) => onStatusChanged(value.first),
              ),
            ),
          ],
        ),
      );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label  $value',
            style: AppTextStyles.labelMedium.copyWith(color: color)),
      );
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.busy,
    required this.onReview,
    required this.onRule,
  });

  final Dispute dispute;
  final bool busy;
  final VoidCallback onReview;
  final ValueChanged<String> onRule;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(dispute.status);
    final orderCode = dispute.orderId.length >= 8
        ? dispute.orderId.substring(0, 8).toUpperCase()
        : dispute.orderId.toUpperCase();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dispute.category, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 3),
                    Text('Order #$orderCode', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: dispute.statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Meta(Icons.person_outline, dispute.studentName ?? 'Buyer'),
              _Meta(Icons.storefront_outlined,
                  dispute.vendorName ?? 'Unknown seller'),
              if (dispute.orderTotal != null)
                _Meta(Icons.payments_outlined,
                    Formatters.money(dispute.orderTotal!)),
              _Meta(Icons.schedule, _age(dispute.createdAt)),
              if (dispute.evidence.isNotEmpty)
                _Meta(Icons.attach_file,
                    '${dispute.evidence.length} evidence file${dispute.evidence.length == 1 ? '' : 's'}'),
            ],
          ),
          const Divider(height: 24),
          Text(dispute.description, style: AppTextStyles.bodyMedium),
          if (dispute.resolution != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Final ruling',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.success)),
                  const SizedBox(height: 4),
                  if (dispute.resolutionOutcome != null) ...[
                    Text(
                      dispute.resolutionOutcome == 'refund_buyer'
                          ? 'Buyer refunded'
                          : 'Payment released to seller',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(dispute.resolution!),
                  if (dispute.resolvedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(Formatters.dateTime(dispute.resolvedAt!),
                        style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
          ],
          if (!dispute.isResolved) ...[
            const SizedBox(height: 14),
            if (busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (dispute.status == 'open')
                    OutlinedButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Start review'),
                    ),
                  FilledButton.icon(
                    onPressed: () => onRule('refund_buyer'),
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Refund buyer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onRule('release_seller'),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('Release seller'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'resolved' => AppColors.success,
        'under_review' => AppColors.info,
        _ => AppColors.warning,
      };

  String _age(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return 'Raised today';
    if (days == 1) return 'Raised yesterday';
    return 'Raised $days days ago';
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      );
}

Future<String?> _showRulingDialog(
    BuildContext context, String outcome) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final refund = outcome == 'refund_buyer';
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(refund ? 'Refund buyer' : 'Release payment to seller'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Ruling note',
              hintText: 'Explain the evidence and reason for this decision.',
              alignLabelWithHint: true,
            ),
            validator: (value) => (value ?? '').trim().length < 10
                ? 'Enter at least 10 characters'
                : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Apply ruling'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
