import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/commission.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../providers/admin_providers.dart';

/// Admin configuration of global commission tiers (spec G3).
/// Money is entered in GH₵ and stored as integer pesewas.
class AdminCommissionScreen extends ConsumerWidget {
  const AdminCommissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiers = ref.watch(adminCommissionTiersProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminCommissionTiersProvider),
        child: tiers.when(
          loading: () => const SkeletonList(itemCount: 7, itemHeight: 72),
          error: (e, _) => ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(adminCommissionTiersProvider)),
          data: (list) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'These tiers apply to all new listings on your campus. '
                      'Changes do not affect orders already placed.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (list.isEmpty)
                  const EmptyState(
                      icon: Icons.tune,
                      title: 'No tiers configured',
                      subtitle: 'Add a tier to start charging commission.')
                else
                  ...list.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TierCard(tier: e.value)
                        .animate()
                        .fadeIn(
                        delay: (40 * e.key).ms, duration: 260.ms)
                        .slideY(begin: 0.04, end: 0),
                  )),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(context, ref),
        icon: Icon(AppIcons.add),
        label: const Text('Add Tier'),
      ),
    );
  }
}

class _TierCard extends ConsumerWidget {
  final CommissionTier tier;
  const _TierCard({required this.tier});

  String get _band {
    final from = Money.format(tier.priceFrom);
    if (tier.priceTo == null) return '$from and above';
    return '$from – ${Money.format(tier.priceTo!)}';
  }

  String get _charge => tier.isPercent
      ? '${(tier.percentBps! / 100).toStringAsFixed(tier.percentBps! % 100 == 0 ? 0 : 2)}% of price'
      : Money.format(tier.flatPesewas ?? 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(tier.isPercent ? AppIcons.insights : AppIcons.price,
                size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_band,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text('Commission: $_charge', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
            onSelected: (v) {
              if (v == 'edit') {
                _editDialog(context, ref, tier: tier);
              } else if (v == 'delete') {
                _delete(context, ref, tier);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(AppIcons.edit, size: 18),
                  const SizedBox(width: AppSpacing.sm + 4),
                  const Text('Edit'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(AppIcons.trash, size: 18, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _delete(
    BuildContext context, WidgetRef ref, CommissionTier tier) async {
  final ok = await ConfirmActions.confirm(
    context,
    title: 'Delete tier?',
    message: 'Remove this commission tier? Prices in this band will fall back '
        'to the next matching tier (or zero).',
    confirmLabel: 'Delete',
    icon: Icons.delete_outline,
    destructive: true,
  );
  if (!ok) return;
  try {
    await ref.read(adminRepositoryProvider).deleteCommissionTier(tier.tierId);
    ref.invalidate(adminCommissionTiersProvider);
    if (context.mounted) ConfirmActions.toast(context, 'Tier deleted');
  } catch (e) {
    if (context.mounted) ConfirmActions.showError(context, e);
  }
}

Future<void> _editDialog(BuildContext context, WidgetRef ref,
    {CommissionTier? tier}) async {
  final isEdit = tier != null;
  final from = TextEditingController(
      text: tier != null ? Money.toCedis(tier.priceFrom).toString() : '');
  final to = TextEditingController(
      text: tier?.priceTo == null ? '' : Money.toCedis(tier!.priceTo!).toString());
  final flat = TextEditingController(
      text: tier?.flatPesewas == null
          ? ''
          : Money.toCedis(tier!.flatPesewas!).toString());
  final percent = TextEditingController(
      text: tier?.percentBps == null
          ? ''
          : (tier!.percentBps! / 100).toString());
  bool usePercent = tier?.percentBps != null;
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(isEdit ? 'Edit Tier' : 'New Tier'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: from,
                  label: 'Price from (GH₵)',
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                  Money.parse(v ?? '') == null ? 'Enter an amount' : null,
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                AppTextField(
                  controller: to,
                  label: 'Price to (GH₵) — leave blank for "and above"',
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Flat GH₵')),
                    ButtonSegment(value: true, label: Text('Percent %')),
                  ],
                  selected: {usePercent},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => usePercent = s.first),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                if (usePercent)
                  AppTextField(
                    controller: percent,
                    label: 'Commission (%)',
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (!usePercent) return null;
                      final d = double.tryParse((v ?? '').trim());
                      return (d == null || d < 0) ? 'Enter a percent' : null;
                    },
                  )
                else
                  AppTextField(
                    controller: flat,
                    label: 'Commission (GH₵)',
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (usePercent) return null;
                      return Money.parse(v ?? '') == null
                          ? 'Enter an amount'
                          : null;
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref.read(adminRepositoryProvider).upsertCommissionTier(
                  tierId: tier?.tierId,
                  campusId: null, // global tier
                  priceFrom: Money.parse(from.text)!,
                  priceTo: to.text.trim().isEmpty
                      ? null
                      : Money.parse(to.text),
                  flatPesewas:
                  usePercent ? null : Money.parse(flat.text),
                  percentBps: usePercent
                      ? ((double.tryParse(percent.text.trim()) ?? 0) * 100)
                      .round()
                      : null,
                );
                ref.invalidate(adminCommissionTiersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ConfirmActions.showError(ctx, e);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    ),
  );
}
