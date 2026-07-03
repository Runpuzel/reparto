// lib/features/admin/screens/admin_services_screen.dart
// Phase 3 – Admin Services Screen (IMPROVED)
// v2.0-2025-07 – Card-based layout, shimmer loading, animations, full moderation

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

class AdminServicesScreen extends ConsumerStatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  ConsumerState<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends ConsumerState<AdminServicesScreen> {
  String _status = 'all';
  String _q = '';
  String _verification = 'all';
  String _category = 'all';
  final Set<String> _selected = {};
  Service? _drawerService;

  // Fee settings state
  final _feeCtrl = TextEditingController(text: '0');
  final _durationCtrl = TextEditingController(text: '30');
  final _freeDaysCtrl = TextEditingController(text: '14');
  bool _freeMode = true;
  bool _savingFee = false;

  @override
  void dispose() {
    _feeCtrl.dispose();
    _durationCtrl.dispose();
    _freeDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(adminServicesProvider(
      AdminServiceQuery(status: _status, q: _q, verification: _verification),
    ));
    final kpisAsync = ref.watch(adminServiceKpisProvider);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 1000;

      final filterContent = _FilterContent(
        status: _status,
        onStatusChanged: (v) => setState(() => _status = v),
        verification: _verification,
        onVerificationChanged: (v) => setState(() => _verification = v),
        category: _category,
        onCategoryChanged: (v) => setState(() => _category = v),
        onQueryChanged: (v) => setState(() => _q = v),
        freeMode: _freeMode,
        onFreeModeChanged: (v) => setState(() {
          _freeMode = v;
          _feeCtrl.text = v ? '0' : '30';
        }),
        feeCtrl: _feeCtrl,
        durationCtrl: _durationCtrl,
        freeDaysCtrl: _freeDaysCtrl,
        savingFee: _savingFee,
        onSaveFee: _saveFee,
        onRunCron: _runCron,
      );

      return Scaffold(
        drawer: isMobile ? Drawer(child: filterContent) : null,
        body: Stack(
          children: [
            Row(
              children: [
                if (!isMobile) ...[
                  SizedBox(width: 320, child: filterContent),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: Column(
                    children: [
                  // Toolbar
                  _buildToolbar(context, isMobile, servicesAsync),

                  // KPI Row
                  _buildKpiSection(kpisAsync, isMobile),

                  // Bulk action bar
                  if (_selected.isNotEmpty)
                    _BulkActionBar(
                      count: _selected.length,
                      onAction: _bulk,
                    ),

                  // Main list
                  Expanded(
                    child: servicesAsync.when(
                      loading: () =>
                          const SkeletonList(itemCount: 5, itemHeight: 140),
                      error: (e, _) => ErrorState(
                          error: e,
                          onRetry: () =>
                              ref.invalidate(adminServicesProvider)),
                      data: (list) {
                        // Apply client-side category filter
                        final filtered = _category == 'all'
                            ? list
                            : list
                                .where((s) => s.category.db == _category)
                                .toList();

                        if (filtered.isEmpty) {
                          return const EmptyState(
                            icon: Icons.design_services_outlined,
                            title: 'No services found',
                            subtitle:
                                'Try adjusting your search or filters',
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(adminServicesProvider);
                            ref.invalidate(adminServiceKpisProvider);
                          },
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.all(AppSpacing.sm + 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) => _ServiceTile(
                              service: filtered[i],
                              isSelected:
                                  _selected.contains(filtered[i].serviceId),
                              onSelect: (val) => setState(() => val
                                  ? _selected.add(filtered[i].serviceId)
                                  : _selected
                                      .remove(filtered[i].serviceId)),
                              onRowAction: _rowAction,
                              onView: (s) =>
                                  setState(() => _drawerService = s),
                            )
                                .animate()
                                .fadeIn(
                                    delay: (30 * (i % 12)).ms,
                                    duration: 260.ms)
                                .slideY(begin: 0.04, end: 0),
                          ),
                        );
                      },
                    ),
                  ),
                    ],
                  ),
                ),
              ],
            ),
            if (_drawerService != null)
              Positioned.fill(
                child: _ServiceDrawer(
                  service: _drawerService!,
                  onClose: () => setState(() => _drawerService = null),
                  onAction: _rowAction,
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildToolbar(BuildContext context, bool isMobile,
      AsyncValue<List<Service>> servicesAsync) {
    final count = servicesAsync.valueOrNull?.length;
    final allIds =
        servicesAsync.valueOrNull?.map((s) => s.serviceId).toSet() ?? {};
    final allSelected =
        allIds.isNotEmpty && _selected.containsAll(allIds);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
                builder: (ctx) => IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    )),
          Expanded(
            child: Text(
              'Service Management',
              style: AppTextStyles.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null && !compact) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: AppRadius.brFull,
              ),
              child: Text(
                '$count',
                style: AppTextStyles.labelMedium.copyWith(
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
          if (allIds.isNotEmpty && !compact)
            Tooltip(
              message: allSelected ? 'Deselect all' : 'Select all visible',
              child: IconButton(
                icon: Icon(
                  allSelected
                      ? Icons.deselect
                      : Icons.select_all,
                  size: 20,
                ),
                onPressed: () => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected.addAll(allIds);
                  }
                }),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(adminServicesProvider);
              ref.invalidate(adminServiceKpisProvider);
            },
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildKpiSection(AsyncValue<ServiceKpis> kpisAsync, bool isMobile) {
    return kpisAsync.when(
      data: (k) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: isMobile
            ? Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _KpiChip(
                      label: 'Active',
                      value: '${k.active}',
                      color: AppColors.success),
                  _KpiChip(
                      label: 'Pending',
                      value: '${k.pendingAuth}',
                      color: AppColors.warning),
                  _KpiChip(
                      label: 'Expired',
                      value: '${k.expired}',
                      color: AppColors.error),
                  _KpiChip(
                      label: 'Revenue MTD',
                      value: Formatters.money(k.revenueMtd),
                      color: AppColors.info),
                ],
              )
            : Row(
                children: [
                  _kpi('Active', '${k.active}', AppColors.success,
                      Icons.check_circle_outline),
                  const SizedBox(width: 12),
                  _kpi('Pending Auth', '${k.pendingAuth}', AppColors.warning,
                      Icons.hourglass_top),
                  const SizedBox(width: 12),
                  _kpi('Expired', '${k.expired}', AppColors.error,
                      Icons.timer_off_outlined),
                  const SizedBox(width: 12),
                  _kpi('Revenue MTD', Formatters.money(k.revenueMtd),
                      AppColors.info, Icons.trending_up),
                ],
              ),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AppShimmer(
          child: Row(
            children: List.generate(
              4,
              (_) => const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SkeletonBox(height: 72, radius: AppRadius.lg),
                ),
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) =>
      Expanded(
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 2),
                    Text(value,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: color, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _saveFee() async {
    setState(() => _savingFee = true);
    try {
      final fee = double.tryParse(_feeCtrl.text) ?? 0;
      final repo = ref.read(adminRepositoryProvider);
      final ok = await ConfirmActions.confirm(
        context,
        title: fee == 0 ? 'Enable Free Mode?' : 'Apply Fee Settings?',
        message:
            'This will update platform listing policies for all campus services.',
      );
      if (!ok) return;
      await repo.updatePlatformSettings({
        'service_auth_fee': _freeMode ? 0 : fee,
        'service_auth_duration_days':
            int.tryParse(_durationCtrl.text) ?? 30,
        'service_free_listing_days':
            int.tryParse(_freeDaysCtrl.text) ?? 14,
      });
      if (mounted) {
        ConfirmActions.toast(context, 'Global settings saved',
            success: true);
      }
      ref.invalidate(adminServiceKpisProvider);
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _savingFee = false);
    }
  }

  Future<void> _runCron() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final count = await repo.expireUnpaidServices();
      if (mounted) {
        ConfirmActions.toast(
            context, 'Check complete. $count services expired.',
            success: true);
      }
      ref.invalidate(adminServicesProvider);
      ref.invalidate(adminServiceKpisProvider);
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    }
  }

  Future<void> _rowAction(String action, Service s) async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      switch (action) {
        case 'view':
          setState(() => _drawerService = s);
          break;
        case 'extend':
          await repo.extendServiceExpiration(s.serviceId, 7);
          if (mounted) {
            ConfirmActions.toast(context, 'Extended by 7 days',
                success: true);
          }
          break;
        case 'authorize':
          final ok = await ConfirmActions.confirm(context,
              title: 'Authorize Manually?',
              message: 'Activate this service without fee?',
              icon: Icons.verified);
          if (!ok) return;
          await repo.authorizeService(
              s.serviceId, true, 'Admin Manual Action');
          if (mounted) {
            ConfirmActions.toast(context, 'Service Authorized',
                success: true);
          }
          break;
        case 'hide':
          final ok = await ConfirmActions.confirm(context,
              title: 'Hide from Search?',
              message:
                  'This service will no longer appear in student search results.',
              icon: Icons.visibility_off);
          if (!ok) return;
          await repo.setServiceStatus(s.serviceId, 'hidden');
          if (mounted) {
            ConfirmActions.toast(context, 'Service hidden', success: true);
          }
          break;
        case 'delete':
          final ok = await ConfirmActions.confirm(context,
              title: 'Delete Listing?',
              message: 'Permanently remove this service?',
              destructive: true,
              icon: Icons.delete_forever);
          if (ok) await repo.deleteService(s.serviceId);
          break;
      }
      ref.invalidate(adminServicesProvider);
      ref.invalidate(adminServiceKpisProvider);
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    }
  }

  Future<void> _bulk(String action) async {
    final repo = ref.read(adminRepositoryProvider);
    final ids = _selected.toList();
    try {
      switch (action) {
        case 'authorize':
          final ok = await ConfirmActions.confirm(context,
              title: 'Bulk Authorize ${ids.length} services?',
              message: 'All selected services will be activated.',
              icon: Icons.verified);
          if (!ok) return;
          await repo.bulkAuthorizeServices(ids, true);
          break;
        case 'extend':
          await repo.bulkExtendServices(ids, 7);
          break;
        case 'hide':
          final ok = await ConfirmActions.confirm(context,
              title: 'Hide ${ids.length} services?',
              message:
                  'Selected services will be hidden from student search.');
          if (!ok) return;
          for (final id in ids) {
            await repo.setServiceStatus(id, 'hidden');
          }
          break;
        case 'delete':
          final ok = await ConfirmActions.confirm(context,
              title: 'Delete ${ids.length} services?',
              message: 'This action is permanent and cannot be undone.',
              destructive: true,
              icon: Icons.delete_forever);
          if (!ok) return;
          for (final id in ids) {
            await repo.deleteService(id);
          }
          break;
      }
      setState(() => _selected.clear());
      ref.invalidate(adminServicesProvider);
      ref.invalidate(adminServiceKpisProvider);
      if (mounted) {
        ConfirmActions.toast(context, 'Bulk $action complete',
            success: true);
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    }
  }
}

// =============================================================================
// KPI Chip (mobile compact)
// =============================================================================

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brFull,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(color: color)),
          const SizedBox(width: 6),
          Text(value,
              style: AppTextStyles.labelMedium
                  .copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// =============================================================================
// Filter Panel
// =============================================================================

class _FilterContent extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;
  final String verification;
  final ValueChanged<String> onVerificationChanged;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;
  final bool freeMode;
  final ValueChanged<bool> onFreeModeChanged;
  final TextEditingController feeCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController freeDaysCtrl;
  final bool savingFee;
  final VoidCallback onSaveFee;
  final VoidCallback onRunCron;

  const _FilterContent({
    required this.status,
    required this.onStatusChanged,
    required this.verification,
    required this.onVerificationChanged,
    required this.category,
    required this.onCategoryChanged,
    required this.onQueryChanged,
    required this.freeMode,
    required this.onFreeModeChanged,
    required this.feeCtrl,
    required this.durationCtrl,
    required this.freeDaysCtrl,
    required this.savingFee,
    required this.onSaveFee,
    required this.onRunCron,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: 8),
        Text('Filters', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Search',
          hint: 'Title, vendor, or description',
          prefixIcon: Icons.search,
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 20),

        // Status filter
        Text('Status', style: AppTextStyles.labelSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in const [
              'all',
              'active',
              'pending_auth',
              'expired',
              'authorized'
            ])
              ChoiceChip(
                label: Text(s.replaceAll('_', ' ')),
                selected: status == s,
                onSelected: (sel) => onStatusChanged(s),
              )
          ],
        ),
        const SizedBox(height: 20),

        // Category filter
        Text('Category', style: AppTextStyles.labelSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: category == 'all',
              onSelected: (_) => onCategoryChanged('all'),
            ),
            for (final c in ServiceCategory.values)
              ChoiceChip(
                label: Text(c.label),
                selected: category == c.db,
                onSelected: (_) => onCategoryChanged(c.db),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Vendor verification filter
        DropdownButtonFormField<String>(
          initialValue: verification,
          decoration: const InputDecoration(labelText: 'Vendor Status'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Vendors')),
            DropdownMenuItem(
                value: 'verified', child: Text('Verified Only')),
            DropdownMenuItem(
                value: 'unverified', child: Text('Unverified')),
          ],
          onChanged: (v) => onVerificationChanged(v ?? 'all'),
        ),

        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),

        // Platform Policies
        Text('Platform Policies', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Free Mode Launch')),
                  Switch(value: freeMode, onChanged: onFreeModeChanged),
                ],
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: feeCtrl,
                label: 'Auth Fee (GHS)',
                keyboardType: TextInputType.number,
                enabled: !freeMode,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: AppTextField(
                          controller: durationCtrl,
                          label: 'Auth Days',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AppTextField(
                          controller: freeDaysCtrl,
                          label: 'Free Days',
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Update Policies',
                loading: savingFee,
                onPressed: onSaveFee,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Utility Tools
        Text('Utility Tools', style: AppTextStyles.labelSmall),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.brMd,
              ),
              child: const Icon(Icons.timer_outlined,
                  size: 18, color: AppColors.warning),
            ),
            title: const Text('Execute Expiry Check'),
            subtitle: Text(
              'Forces database review of expired services',
              style: AppTextStyles.bodySmall,
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.neutral400),
            onTap: onRunCron,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

// =============================================================================
// Service Tile (card-based, replaces DataTable rows)
// =============================================================================

class _ServiceTile extends StatelessWidget {
  final Service service;
  final bool isSelected;
  final ValueChanged<bool> onSelect;
  final Function(String, Service) onRowAction;
  final ValueChanged<Service> onView;

  const _ServiceTile({
    required this.service,
    required this.isSelected,
    required this.onSelect,
    required this.onRowAction,
    required this.onView,
  });

  Color _statusColor(Service s) {
    if (s.isExpired) return AppColors.error;
    if (s.isAuthorized) return AppColors.success;
    if (s.isExpiringSoon) return AppColors.warning;
    return AppColors.neutral500;
  }

  String _statusLabel(Service s) {
    if (s.isExpired) return 'Expired';
    if (s.isAuthorized) return 'Authorized';
    if (s.isExpiringSoon) return 'Expiring Soon';
    if (s.status == 'hidden') return 'Hidden';
    return s.status.toUpperCase();
  }

  IconData _statusIcon(Service s) {
    if (s.isExpired) return Icons.timer_off_outlined;
    if (s.isAuthorized) return Icons.verified;
    if (s.isExpiringSoon) return Icons.warning_amber;
    if (s.status == 'hidden') return Icons.visibility_off;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = service;
    final days = s.daysLeft;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      border: isSelected
          ? Border.all(color: scheme.primary, width: 1.6)
          : s.isExpiringSoon && !s.isAuthorized
              ? Border.all(color: AppColors.warning, width: 1.2)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: checkbox + image + info + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection checkbox
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (v) => onSelect(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),

              // Thumbnail
              GestureDetector(
                onTap: () => onView(s),
                child: ClipRRect(
                  borderRadius: AppRadius.brMd,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: AppNetworkImage(
                      url: s.imageUrl,
                      fallbackIcon: Icons.design_services_outlined,
                      iconSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title + vendor
              Expanded(
                child: GestureDetector(
                  onTap: () => onView(s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: AppTextStyles.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.vendorName ?? '—',
                              style: AppTextStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (s.vendorIsVerified == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                size: 14, color: AppColors.success),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status + price column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    label: _statusLabel(s),
                    color: _statusColor(s),
                    icon: _statusIcon(s),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.priceLabel,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Info chips row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: AppRadius.brMd,
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _metadataItem(
                  context,
                  Icons.category_outlined,
                  s.category.label,
                ),
                _metadataItem(
                  context,
                  Icons.schedule,
                  s.expiresAt == null
                      ? 'No expiry'
                      : days < 0
                          ? 'Expired ${-days}d ago'
                          : '${days}d left',
                  color: days < 3 ? AppColors.error : null,
                ),
                _metadataItem(
                  context,
                  s.isAuthorized
                      ? Icons.workspace_premium
                      : Icons.lock_open_outlined,
                  s.isAuthorized ? 'Paid' : 'Free',
                  color: s.isAuthorized ? AppColors.success : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Actions row
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _tileAction(context, 'Full Details', Icons.open_in_new,
                  () => onRowAction('view', s)),
              _tileAction(context, 'Extend +7d', Icons.more_time,
                  () => onRowAction('extend', s)),
              if (!s.isAuthorized)
                _tileAction(context, 'Authorize', Icons.verified,
                    () => onRowAction('authorize', s),
                    filled: true),
              _tileAction(context, 'Hide', Icons.visibility_off,
                  () => onRowAction('hide', s)),
              _tileAction(context, 'Delete', Icons.delete_outline,
                  () => onRowAction('delete', s),
                  destructive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metadataItem(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effectiveColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 11.5,
            color: color,
            fontWeight: color == null ? null : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _tileAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
    bool filled = false,
  }) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? AppColors.error : null,
        side: destructive
            ? const BorderSide(color: AppColors.error)
            : null,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// =============================================================================
// Bulk Action Bar
// =============================================================================

class _BulkActionBar extends StatelessWidget {
  final int count;
  final ValueChanged<String> onAction;
  const _BulkActionBar({required this.count, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: AppRadius.brLg,
        border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checklist, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '$count selected',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          _barBtn('Extend', Icons.more_time, () => onAction('extend')),
          _barBtn('Authorize', Icons.verified, () => onAction('authorize'),
              filled: true),
          _barBtn('Hide', Icons.visibility_off, () => onAction('hide')),
          _barBtn('Delete', Icons.delete_outline, () => onAction('delete'),
              destructive: true),
        ],
      ),
    );
  }

  Widget _barBtn(String label, IconData icon, VoidCallback onTap,
      {bool filled = false, bool destructive = false}) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? AppColors.error : null,
        side: destructive
            ? const BorderSide(color: AppColors.error)
            : null,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

// =============================================================================
// Detail Drawer (improved)
// =============================================================================

class _ServiceDrawer extends ConsumerWidget {
  final Service service;
  final VoidCallback onClose;
  final Function(String, Service) onAction;
  const _ServiceDrawer({
    required this.service,
    required this.onClose,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = service;
    final scheme = Theme.of(context).colorScheme;
    final days = s.daysLeft;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerRight,
        child: Material(
      elevation: 8,
      child: SizedBox(
        width: constraints.maxWidth > 420 ? 420 : constraints.maxWidth,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: AppTextStyles.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.vendorName ?? 'Unknown',
                                style: AppTextStyles.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (s.vendorIsVerified == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 14, color: AppColors.success),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Image
                  if (s.imageUrl != null)
                    ClipRRect(
                      borderRadius: AppRadius.brLg,
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: AppNetworkImage(url: s.imageUrl!),
                      ),
                    ),
                  if (s.imageUrl != null) const SizedBox(height: 16),

                  // Status pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(
                        label: s.isAuthorized
                            ? 'Authorized'
                            : 'Not Authorized',
                        color: s.isAuthorized
                            ? AppColors.success
                            : AppColors.neutral500,
                        icon: s.isAuthorized
                            ? Icons.verified
                            : Icons.shield_outlined,
                      ),
                      StatusPill(
                        label: s.isExpired
                            ? 'Expired'
                            : s.isExpiringSoon
                                ? 'Expiring Soon'
                                : s.status.toUpperCase(),
                        color: s.isExpired
                            ? AppColors.error
                            : s.isExpiringSoon
                                ? AppColors.warning
                                : AppColors.success,
                        icon: s.isExpired
                            ? Icons.timer_off_outlined
                            : s.isExpiringSoon
                                ? Icons.warning_amber
                                : Icons.check_circle_outline,
                      ),
                      StatusPill(
                        label: s.category.label,
                        color: scheme.primary,
                        icon: Icons.category_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Key-value details
                  _DetailBlock(children: [
                    _kv(context, 'Base Price', s.priceLabel),
                    _kv(context, 'Listing Status',
                        s.status.toUpperCase()),
                    _kv(
                        context,
                        'Expires On',
                        s.expiresAt
                                ?.toLocal()
                                .toString()
                                .split(' ')[0] ??
                            'N/A'),
                    _kv(
                        context,
                        'Days Left',
                        s.expiresAt == null
                            ? 'No expiry'
                            : days < 0
                                ? 'Expired ${-days} days ago'
                                : '$days days'),
                    _kv(context, 'Created',
                        Formatters.dateTime(s.createdAt)),
                    if (s.location != null)
                      _kv(context, 'Location', s.location!),
                    if (s.availability != null)
                      _kv(context, 'Availability', s.availability!),
                  ]),
                  const SizedBox(height: 16),

                  // Authorization details
                  if (s.isAuthorized) ...[
                    Text('AUTHORIZATION',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: scheme.primary)),
                    const SizedBox(height: 8),
                    _DetailBlock(children: [
                      _kv(
                          context,
                          'Fee Paid',
                          s.authorizationFeePaid != null
                              ? Formatters.money(s.authorizationFeePaid!)
                              : 'Manual'),
                      if (s.authorizationPaidAt != null)
                        _kv(context, 'Paid At',
                            Formatters.dateTime(s.authorizationPaidAt!)),
                      if (s.authorizationExpiresAt != null)
                        _kv(
                            context,
                            'Auth Expires',
                            s.authorizationExpiresAt!
                                .toLocal()
                                .toString()
                                .split(' ')[0]),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  Text('DESCRIPTION',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: scheme.primary)),
                  const SizedBox(height: 8),
                  Text(s.description ?? 'No description.',
                      style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 24),

                  // Quick actions
                  Text('ACTIONS',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: scheme.primary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onAction('extend', s),
                        icon: const Icon(Icons.more_time, size: 18),
                        label: const Text('Extend +7d'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                      if (!s.isAuthorized)
                        FilledButton.icon(
                          onPressed: () => onAction('authorize', s),
                          icon: const Icon(Icons.verified, size: 18),
                          label: const Text('Authorize'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => onAction('hide', s),
                        icon: const Icon(Icons.visibility_off, size: 18),
                        label: const Text('Hide'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Moderation section
                  Text('MODERATION',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error)),
                  const SizedBox(height: 12),
                  AppCard(
                    color: AppColors.error.withValues(alpha: 0.04),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Content moderation controls',
                                style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Flag Content',
                          variant: AppButtonVariant.secondary,
                          icon: Icons.flag_outlined,
                          onPressed: () {
                            ConfirmActions.toast(
                                context, 'Service flagged for review');
                          },
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Emergency Takedown',
                          icon: Icons.gavel,
                          onPressed: () async {
                            final ok = await ConfirmActions.confirm(
                              context,
                              title: 'Confirm Emergency Takedown',
                              message:
                                  'This will immediately hide "${s.title}" from all students. The vendor will be notified.',
                              destructive: true,
                              icon: Icons.gavel,
                            );
                            if (ok) {
                              onAction('hide', s);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => onAction('delete', s),
                          icon: const Icon(Icons.delete_forever,
                              size: 18, color: AppColors.error),
                          label: const Text('Permanently Delete',
                              style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, 44),
                            side:
                                const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
}

class _DetailBlock extends StatelessWidget {
  final List<Widget> children;
  const _DetailBlock({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
