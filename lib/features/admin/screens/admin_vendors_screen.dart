import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
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
      child: AsyncView<List<Vendor>>(
        value: vendors,
        onRetry: () => ref.invalidate(allVendorsProvider),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No vendor applications'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _VendorTile(vendor: list[i]),
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
        return Colors.green;
      case ApprovalStatus.rejected:
        return Colors.redAccent;
      case ApprovalStatus.suspended:
        return Colors.grey;
      case ApprovalStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        icon: destructive ? Icons.warning_amber_rounded : Icons.verified_outlined,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage:
                  (vendor.logoUrl != null && vendor.logoUrl!.isNotEmpty)
                      ? NetworkImage(vendor.logoUrl!)
                      : null,
                  child: (vendor.logoUrl == null || vendor.logoUrl!.isEmpty)
                      ? const Icon(Icons.storefront, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor.businessName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('${vendor.ownerName ?? '—'} · ${vendor.phoneNumber ?? '—'}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(
                    label: vendor.approvalStatus.label,
                    color: _color(vendor.approvalStatus)),
              ],
            ),
            const SizedBox(height: 10),
            // KYC details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, 'Business phone', vendor.businessPhone ?? '—'),
                  _kv(context, 'Mobile money',
                      vendor.momoNumber == null
                          ? '—'
                          : '${vendor.momoNumber} (${vendor.momoNetwork ?? ''})'),
                  _kv(context, 'Ghana Card', vendor.ghanaCardNumber ?? '—'),
                  if (vendor.ghanaCardImageUrl != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _viewCard(context, vendor),
                        icon: const Icon(Icons.image_search, size: 18),
                        label: const Text('View Ghana Card photo'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (vendor.approvalStatus != ApprovalStatus.approved)
                  FilledButton(
                      onPressed: () => set('approved'),
                      style:
                      FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                      child: const Text('Approve')),
                if (vendor.approvalStatus == ApprovalStatus.pending)
                  OutlinedButton(
                      onPressed: () => set('rejected'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: Colors.redAccent),
                      child: const Text('Reject')),
                if (vendor.approvalStatus == ApprovalStatus.approved)
                  OutlinedButton(
                      onPressed: () => set('suspended'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: Colors.redAccent),
                      child: const Text('Suspend')),
                if (vendor.approvalStatus == ApprovalStatus.suspended)
                  FilledButton.tonal(
                      onPressed: () => set('approved'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38)),
                      child: const Text('Reinstate')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      icon: const Icon(Icons.close)),
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
