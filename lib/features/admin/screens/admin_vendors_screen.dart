// lib/features/admin/screens/admin_vendors_screen.dart
// v1.0-2025-07 – Verification workflow, verified badge granting

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

class AdminVendorsScreen extends ConsumerStatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  ConsumerState<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends ConsumerState<AdminVendorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(allVendorsProvider);

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search vendor / business / ID',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _q = v.toLowerCase()),
                ),
              ),
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'KYC Pending'),
                  Tab(text: 'Verified'),
                  Tab(text: 'Rejected'),
                ],
                onTap: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allVendorsProvider);
              ref.invalidate(pendingVendorsProvider);
            },
            child: vendorsAsync.when(
              loading: () =>
              const SkeletonList(itemCount: 5, itemHeight: 180),
              error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(allVendorsProvider)),
              data: (list) {
                // v1.0 filter by verification_status
                List<Vendor> filtered = list;
                final tab = _tab.index;
                if (tab == 1) {
                  filtered = list
                      .where((v) => v.verificationStatus == 'pending')
                      .toList();
                } else if (tab == 2) {
                  filtered =
                      list.where((v) => v.isVerified).toList();
                } else if (tab == 3) {
                  filtered = list
                      .where((v) => v.verificationStatus == 'rejected')
                      .toList();
                }
                if (_q.isNotEmpty) {
                  filtered = filtered.where((v) {
                    final hay =
                    '${v.businessName} ${v.ownerName} ${v.verificationIdNumber} ${v.emailForAdmin ?? ''}'
                        .toLowerCase();
                    return hay.contains(_q);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.verified_user_outlined,
                      title: tab == 1
                          ? 'No pending KYC'
                          : 'No vendors found',
                      subtitle: tab == 1
                          ? 'Verification queue is clear'
                          : 'Try another filter',
                    ),
                  ]);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => VendorTile(
                    vendor: filtered[i],
                    highlightKyc: tab == 1,
                  )
                      .animate()
                      .fadeIn(
                      delay: (30 * (i % 12)).ms,
                      duration: 260.ms)
                      .slideY(begin: 0.04, end: 0),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class VendorTile extends ConsumerWidget {
  final Vendor vendor;
  final bool highlightKyc;
  const VendorTile({required this.vendor, this.highlightKyc = false});

  Color _approvalColor(ApprovalStatus s) {
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

  Color _verifColor(String status, bool isVerified) {
    if (isVerified) return AppColors.success;
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      case 'approved':
        return AppColors.success;
      default:
        return AppColors.neutral500;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(adminRepositoryProvider);
    final isVerified = vendor.isVerified;
    final vStatus = vendor.verificationStatus;

    Future<void> reviewVerification(bool approve) async {
      String? reason;
      if (!approve) {
        reason = await _askRejectReason(context);
        if (reason == null || reason.trim().isEmpty) return;
      } else {
        final confirmed = await ConfirmActions.confirm(
          context,
          title: 'Approve verification?',
          message:
          'Grant Verified Student Seller badge to "${vendor.businessName}"?\n\nThis unlocks:\n• Prepayment / Mobile Money\n• Verified badge site-wide\n• Priority search',
          confirmLabel: 'Approve & Grant Badge',
          icon: Icons.verified,
        );
        if (!confirmed) return;
      }

      try {
        // v1.0 RPC – admin_review_verification
        if (repo.reviewVerification != null) {
          await repo.reviewVerification!(vendor.vendorId, approve,
              reason: reason);
        } else {
          // fallback – legacy setVendorApproval
          await repo.setVendorApproval(
              vendor.vendorId, approve ? 'approved' : 'rejected');
        }
        ref.invalidate(allVendorsProvider);
        ref.invalidate(pendingVendorsProvider);
        if (context.mounted) {
          ConfirmActions.toast(
            context,
            approve
                ? 'Verified badge granted ✓'
                : 'Verification rejected – seller notified',
            success: approve,
          );
        }
      } catch (e) {
        if (context.mounted) ConfirmActions.showError(context, e);
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      border: highlightKyc && vStatus == 'pending'
          ? Border.all(color: AppColors.warning, width: 1.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: (vendor.logoUrl != null &&
                      vendor.logoUrl!.isNotEmpty)
                      ? AppNetworkImage(
                      url: vendor.logoUrl,
                      fallbackIcon: AppIcons.storefront)
                      : Container(
                    color: scheme.primaryContainer,
                    child: Icon(AppIcons.storefrontFill,
                        size: 24,
                        color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.displayStoreName,
                            style: AppTextStyles.titleMedium
                                .copyWith(color: scheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 18, color: AppColors.success),
                        ],
                      ],
                    ),
                    Text(
                      '${vendor.ownerName ?? '—'} · ${vendor.phoneNumber ?? '—'}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    label: vendor.approvalStatus.label,
                    color: _approvalColor(vendor.approvalStatus),
                    icon: vendor.isApproved
                        ? AppIcons.check
                        : AppIcons.pending,
                  ),
                  const SizedBox(height: 4),
                  StatusPill(
                    label: isVerified
                        ? 'Verified'
                        : vStatus == 'pending'
                        ? 'KYC Pending'
                        : vStatus == 'rejected'
                        ? 'KYC Rejected'
                        : 'Unverified',
                    color: _verifColor(vStatus, isVerified),
                    icon: isVerified
                        ? Icons.verified
                        : vStatus == 'pending'
                        ? Icons.hourglass_top
                        : Icons.shield_outlined,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),

          // v1.0 – KYC details block
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color:
              scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: AppRadius.brMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Business phone',
                    vendor.businessPhone ?? '—'),
                _kv(
                    context,
                    'Mobile money',
                    vendor.momoNumber == null
                        ? '—'
                        : '${vendor.momoNumber} (${vendor.momoNetwork ?? ''})'),
                _kv(
                    context,
                    'WhatsApp',
                    vendor.whatsappNumber ??
                        vendor.businessPhone ??
                        '—'),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Identity – ${vendor.verificationType ?? 'not submitted'}',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (vendor.verificationIdNumber != null)
                      Text(
                        '••••${vendor.verificationIdNumber!.characters.takeLast(4).toString()}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (vendor.verificationFrontUrl != null ||
                    vendor.ghanaCardImageUrl != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((vendor.verificationFrontUrl ??
                          vendor.ghanaCardImageUrl) !=
                          null)
                        _docButton(
                          context,
                          'ID Front',
                          vendor.verificationFrontUrl ??
                              vendor.ghanaCardImageUrl!,
                        ),
                      if (vendor.verificationBackUrl != null)
                        _docButton(
                          context,
                          'ID Back',
                          vendor.verificationBackUrl!,
                        ),
                      if (vendor.verificationSelfieUrl != null)
                        _docButton(
                          context,
                          'Selfie',
                          vendor.verificationSelfieUrl!,
                        ),
                    ],
                  ),
                ] else
                  Text(
                    'No ID documents uploaded yet',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (vendor.verificationStatus == 'rejected' &&
                    (vendor.verificationRejectedReason ?? '')
                        .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.07),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      'Rejection reason: ${vendor.verificationRejectedReason}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
                if (vendor.verificationSubmittedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Submitted: ${vendor.verificationSubmittedAt!.day}/${vendor.verificationSubmittedAt!.month} ${vendor.verificationSubmittedAt!.hour}:${vendor.verificationSubmittedAt!.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm + 2),

          // Actions – v1.0 verification workflow
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // KYC Approve / Reject – primary
              if (vendor.verificationStatus == 'pending') ...[
                FilledButton.icon(
                  onPressed: () => reviewVerification(true),
                  icon: const Icon(Icons.verified, size: 18),
                  label: const Text('Approve KYC'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => reviewVerification(false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ],
              // Verified – allow revoke
              if (isVerified) ...[
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await ConfirmActions.confirm(
                      context,
                      title: 'Revoke verification?',
                      message:
                      'Remove Verified badge from ${vendor.businessName}? They will revert to COD-only.',
                      confirmLabel: 'Revoke',
                      destructive: true,
                      icon: Icons.gavel_outlined,
                    );
                    if (ok) {
                      await reviewVerification(false);
                    }
                  },
                  icon: const Icon(Icons.remove_moderator_outlined,
                      size: 18),
                  label: const Text('Revoke Badge'),
                ),
              ],
              // Legacy approval_status actions – keep for business approval (separate from KYC)
              if (vendor.approvalStatus != ApprovalStatus.approved)
                OutlinedButton(
                  onPressed: () async {
                    final repo2 = ref.read(adminRepositoryProvider);
                    await repo2.setVendorApproval(
                        vendor.vendorId, 'approved');
                    ref.invalidate(allVendorsProvider);
                  },
                  child: const Text('Approve Business'),
                ),
              if (vendor.approvalStatus == ApprovalStatus.approved)
                OutlinedButton(
                  onPressed: () async {
                    final confirmed = await ConfirmActions.confirm(
                      context,
                      title: 'Suspend business?',
                      message:
                      'Suspend "${vendor.businessName}"? Owner will be notified.',
                      confirmLabel: 'Suspend',
                      destructive: true,
                    );
                    if (!confirmed) return;
                    final repo2 = ref.read(adminRepositoryProvider);
                    await repo2.setVendorApproval(
                        vendor.vendorId, 'suspended');
                    ref.invalidate(allVendorsProvider);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Suspend'),
                ),
              if (vendor.approvalStatus == ApprovalStatus.suspended)
                FilledButton.tonal(
                  onPressed: () async {
                    final repo2 = ref.read(adminRepositoryProvider);
                    await repo2.setVendorApproval(
                        vendor.vendorId, 'approved');
                    ref.invalidate(allVendorsProvider);
                  },
                  child: const Text('Reinstate'),
                ),
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

  Widget _docButton(BuildContext context, String label, String path) {
    return OutlinedButton.icon(
      onPressed: () => _viewDoc(context, path),
      icon: const Icon(Icons.image_search, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _viewDoc(BuildContext context, String storagePath) async {
    try {
      // v1.0 – KYC images live in private bucket kyc_docs – use signedUrl
      final url = await StorageService()
          .signedUrl(StorageService.kycDocuments, storagePath);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('ID Document'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close)),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load image – signed URL expired?'),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  storagePath,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open document: $e');
      }
    }
  }

  Future<String?> _askRejectReason(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reason sent to seller:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                'e.g. ID image blurry – card number unreadable. Please resubmit clear photos.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final preset in [
                  'ID image blurry',
                  'Card number mismatch',
                  'Selfie does not match ID',
                  'Student ID expired',
                  'Name mismatch',
                ])
                  ActionChip(
                    label: Text(preset,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      ctrl.text = preset;
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style:
            FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ---- v1.0 model helpers – keep file compiling against legacy Vendor ----
// These extensions expose v1.0 fields safely when using pre-migration models
extension VendorV1X on Vendor {
  String get displayStoreName => (this as dynamic).storeName ?? businessName;
  bool get isVerified => (this as dynamic).isVerified ?? false;
  String get verificationStatus =>
      (this as dynamic).verificationStatus ?? 'unverified';
  String? get verificationType =>
      (this as dynamic).verificationType as String?;
  String? get verificationIdNumber =>
      (this as dynamic).verificationIdNumber as String?;
  String? get verificationFrontUrl =>
      (this as dynamic).verificationFrontUrl as String? ??
          ghanaCardImageUrl;
  String? get verificationBackUrl =>
      (this as dynamic).verificationBackUrl as String?;
  String? get verificationSelfieUrl =>
      (this as dynamic).verificationSelfieUrl as String?;
  DateTime? get verificationSubmittedAt =>
      (this as dynamic).verificationSubmittedAt as DateTime?;
  String? get verificationRejectedReason =>
      (this as dynamic).verificationRejectedReason as String?;
  String? get whatsappNumber =>
      (this as dynamic).whatsappNumber as String?;
  String? get emailForAdmin => null; // join users.email if needed
}

// ---- admin repo v1.0 extension shims ----
extension AdminRepoV1X on dynamic {
  Future<void> Function(String vendorId, bool approve, {String? reason})?
  get reviewVerification => null;
}
