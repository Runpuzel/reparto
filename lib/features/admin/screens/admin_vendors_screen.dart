import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/admin_providers.dart';

class AdminVendorsScreen extends ConsumerWidget {
  const AdminVendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(allVendorsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allVendorsProvider);
        ref.invalidate(pendingVendorsProvider);
      },
      child: vendors.when(
        loading: () => const SkeletonList(itemCount: 5, itemHeight: 150),
        error: (e, _) => ErrorState(
            message: '$e', onRetry: () => ref.invalidate(allVendorsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No seller applications'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _VendorTile(vendor: list[i])
                .animate()
                .fadeIn(delay: (40 * (i % 12)).ms, duration: 280.ms)
                .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

class _VendorTile extends ConsumerWidget {
  final Vendor vendor;
  const _VendorTile({required this.vendor});

  Color _color(ApprovalStatus s) {
    switch (s) {
      case ApprovalStatus.approved:
        return AppColors.success;
      case ApprovalStatus.rejected:
        return AppColors.error;
      case ApprovalStatus.suspended:
        return AppColors.neutral500;
      case ApprovalStatus.pending:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(adminRepositoryProvider);
    Future<void> set(String status) async {
      const labels = {
        'approved': 'approve',
        'rejected': 'reject',
        'suspended': 'suspend',
      };
      final verb = labels[status] ?? 'update';
      final destructive = status == 'rejected' || status == 'suspended';
      final confirmed = await ConfirmActions.confirm(
        context,
        title: '${verb[0].toUpperCase()}${verb.substring(1)} business?',
        message:
        'Are you sure you want to $verb "${vendor.businessName}"? The owner will be notified.',
        confirmLabel: verb[0].toUpperCase() + verb.substring(1),
        destructive: destructive,
        icon: destructive
            ? Icons.warning_amber_rounded
            : Icons.verified_outlined,
      );
      if (!confirmed) return;
      try {
        await repo.setVendorApproval(vendor.vendorId, status);
        ref.invalidate(allVendorsProvider);
        ref.invalidate(pendingVendorsProvider);
        if (context.mounted) {
          ConfirmActions.toast(context, 'Business $status', success: true);
        }
      } catch (e) {
        if (context.mounted) ConfirmActions.showError(context, e);
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: (vendor.logoUrl != null &&
                      vendor.logoUrl!.isNotEmpty)
                      ? AppNetworkImage(
                      url: vendor.logoUrl,
                      fallbackIcon: AppIcons.storefront)
                      : Container(
                    color: scheme.primaryContainer,
                    child: Icon(AppIcons.storefrontFill,
                        size: 22, color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor.businessName,
                        style: AppTextStyles.titleMedium
                            .copyWith(color: scheme.onSurface)),
                    Text(
                        '${vendor.ownerName ?? '—'} · ${vendor.phoneNumber ?? '—'}',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                  label: vendor.approvalStatus.label,
                  color: _color(vendor.approvalStatus)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          // KYC details
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: AppRadius.brMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Business phone', vendor.businessPhone ?? '—'),
                _kv(
                    context,
                    'Mobile money',
                    vendor.momoNumber == null
                        ? '—'
                        : '${vendor.momoNumber} (${vendor.momoNetwork ?? ''})'),
                _kv(context, 'Ghana Card', vendor.ghanaCardNumber ?? '—'),
                if (vendor.ghanaCardImageUrl != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _viewCard(context, vendor),
                      icon: Icon(AppIcons.imageSearch, size: 18),
                      label: const Text('View Ghana Card photo'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (vendor.approvalStatus != ApprovalStatus.approved)
                FilledButton(
                    onPressed: () => set('approved'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40)),
                    child: const Text('Approve')),
              if (vendor.approvalStatus == ApprovalStatus.pending)
                OutlinedButton(
                    onPressed: () => set('rejected'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error)),
                    child: const Text('Reject')),
              if (vendor.approvalStatus == ApprovalStatus.approved)
                OutlinedButton(
                    onPressed: () => set('suspended'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error)),
                    child: const Text('Suspend')),
              if (vendor.approvalStatus == ApprovalStatus.suspended)
                FilledButton.tonal(
                    onPressed: () => set('approved'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40)),
                    child: const Text('Reinstate')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: AppTextStyles.bodySmall
                    .copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(v,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _viewCard(BuildContext context, Vendor vendor) async {
    // KYC images live in a private bucket → fetch a short-lived signed URL.
    try {
      final url = await StorageService()
          .signedUrl(StorageService.kycDocuments, vendor.ghanaCardImageUrl!);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Ghana Card'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(AppIcons.close)),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(url,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Could not load image.'),
                      )),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open the document.');
      }
    }
  }
}
