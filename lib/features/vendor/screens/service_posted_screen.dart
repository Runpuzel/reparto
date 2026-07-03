// lib/features/vendor/screens/service_posted_screen.dart
// v1.5 – Fixed: Undefined currentVendorProvider import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/consent_dialog.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import 'vendor_products_screen.dart';

/// Fetches a specific service from the current vendor's list.
final serviceByIdProvider = FutureProvider.family<Service?, String>((ref, id) async {
  final list = await ref.watch(myServicesProvider.future);
  return list.where((s) => s.serviceId == id).firstOrNull;
});

class ServicePostedScreen extends ConsumerStatefulWidget {
  final String serviceId;
  const ServicePostedScreen({super.key, required this.serviceId});

  @override
  ConsumerState<ServicePostedScreen> createState() => _ServicePostedScreenState();
}

class _ServicePostedScreenState extends ConsumerState<ServicePostedScreen> {
  bool _updatingStatus = false;

  Future<void> _shareToWhatsApp(String title, String id) async {
    final link = 'https://ujustbuy.com/s/$id';
    final text = Uri.encodeComponent('Hi! Check out my service on UjustBUY: $title\n\nBook here: $link');
    final url = 'https://wa.me/?text=$text';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _copyLink(title, id);
      }
    } catch (_) {
      await _copyLink(title, id);
    }
  }

  Future<void> _copyLink(String title, String id) async {
    final link = 'https://ujustbuy.com/s/$id';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ConfirmActions.toast(context, 'Link copied to clipboard');
    }
  }

  Future<void> _toggleVisibility(Service s) async {
    setState(() => _updatingStatus = true);
    try {
      final newStatus = s.status == 'available' ? 'hidden' : 'available';
      await ref.read(vendorRepositoryProvider).updateServiceStatus(s.serviceId, newStatus);
      ref.invalidate(myServicesProvider);
      if (mounted) {
        ConfirmActions.toast(context, newStatus == 'available' ? 'Service is now live' : 'Service hidden');
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(serviceByIdProvider(widget.serviceId));
    final platformAsync = ref.watch(platformSettingsProvider);
    final vendor = ref.watch(currentVendorProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/vendor'),
          ),
        ],
      ),
      body: AsyncView<Service?>(
        value: serviceAsync,
        onRetry: () => ref.invalidate(myServicesProvider),
        data: (s) {
          if (s == null) {
            return EmptyState(
              icon: Icons.search_off,
              title: 'Service not found',
              action: FilledButton(
                onPressed: () => context.go('/vendor'),
                child: const Text('Back to Dashboard'),
              ),
            );
          }

          final settings = platformAsync.valueOrNull;
          final authFee = settings?.serviceAuthFee ?? 30.0;
          final freeMode = settings?.isFreeMode ?? (authFee == 0);

          final expiresAt = s.isAuthorized 
              ? (s.authorizationExpiresAt ?? s.createdAt.add(const Duration(days: 30)))
              : (s.expiresAt ?? s.createdAt.add(const Duration(days: 14)));
          
          final daysLeft = expiresAt.difference(DateTime.now()).inDays;
          final isExpired = daysLeft < 0 && !freeMode;
          final isExpiringSoon = daysLeft <= 3 && daysLeft >= 0 && !freeMode;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // 1. REACH SCORE & STATS
              _ReachScoreHeader(service: s, vendor: vendor),
              const SizedBox(height: AppSpacing.lg),

              // 2. STATUS CARD
              _ServiceStatusCard(
                service: s,
                isExpired: isExpired,
                isExpiringSoon: isExpiringSoon,
                freeMode: freeMode,
                daysLeft: daysLeft,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. VISUAL PREVIEW
              _SectionTitle(text: 'Marketplace Preview'),
              const SizedBox(height: AppSpacing.sm),
              _InteractivePreview(service: s, isExpired: isExpired),
              const SizedBox(height: AppSpacing.lg),

              // 4. PLAN & BILLING
              _SectionTitle(text: 'Listing Plan & Billing'),
              const SizedBox(height: AppSpacing.sm),
              _BillingSection(
                service: s,
                freeMode: freeMode,
                expiresAt: expiresAt,
                daysLeft: daysLeft,
                isExpired: isExpired,
                isExpiringSoon: isExpiringSoon,
                authFee: authFee,
                onAuthorize: () async {
                  final ok = await showConsentDialog(
                    context,
                    type: ConsentType.paymentAuth,
                    policyVersion: 'v1.0-2025-07',
                    title: 'Upgrade to Authorized',
                    bodyMarkdown: '''
### Boost Your Service (GHS $authFee)
- **Top Ranking:** Appear first in campus searches.
- **Trust:** Blue badge shown to students.
- **Safety:** listing won't auto-hide for 30 days.
''',
                    requiredCheckboxes: ['I agree to the non-refundable authorization fee'],
                    ref: ref,
                  );
                  if (ok && context.mounted) {
                    ConfirmActions.toast(context, 'Payment system launching in Phase 4');
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 5. VISIBILITY & PROMOTION
              _SectionTitle(text: 'Growth & Visibility'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Show in Marketplace', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isExpired 
                        ? 'Disabled: Listing Expired' 
                        : (s.status == 'available' ? 'Students can book your service' : 'Listing is currently hidden')),
                      value: s.status == 'available' && !isExpired,
                      onChanged: (isExpired || _updatingStatus) ? null : (_) => _toggleVisibility(s),
                      secondary: Icon(
                        s.status == 'available' && !isExpired ? Icons.visibility : Icons.visibility_off,
                        color: s.status == 'available' && !isExpired ? scheme.primary : scheme.outline,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.share_outlined, color: Colors.green),
                      title: const Text('Share to WhatsApp'),
                      subtitle: const Text('Directly promote to campus groups'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _shareToWhatsApp(s.title, s.serviceId),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 6. MANAGEMENT BUTTONS
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Edit Info',
                      icon: AppIcons.edit,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push('/vendor/service-form', extra: s),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        final ok = await ConfirmActions.confirm(
                          context,
                          title: 'Remove Listing?',
                          message: 'This will permanently delete "${s.title}".',
                          destructive: true,
                        );
                        if (ok) {
                          await ref.read(vendorRepositoryProvider).deleteService(s.serviceId);
                          ref.invalidate(myServicesProvider);
                          if (context.mounted) context.go('/vendor');
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), 
      style: AppTextStyles.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.primary, 
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ReachScoreHeader extends StatelessWidget {
  final Service service;
  final Vendor? vendor;
  const _ReachScoreHeader({required this.service, required this.vendor});

  @override
  Widget build(BuildContext context) {
    int score = 30;
    if (service.imageUrl != null) score += 30;
    if ((service.description?.length ?? 0) > 40) score += 20;
    if (vendor?.isVerified ?? false) score += 20;

    final color = score > 80 ? AppColors.success : (score > 50 ? AppColors.warning : AppColors.error);

    return AppCard(
      child: Row(
        children: [
          _ScoreIndicator(score: score, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reach Score', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Score: $score/100', style: AppTextStyles.titleMedium.copyWith(color: color, fontWeight: FontWeight.w900)),
                if (score < 100)
                  Text(score < 50 ? 'Improve your listing to get more views.' : 'Almost perfect! Verify ID for max trust.', style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SmallStat(label: 'Views', value: '142'),
        ],
      ),
    );
  }
}

class _ServiceStatusCard extends StatelessWidget {
  final Service service;
  final bool isExpired;
  final bool isExpiringSoon;
  final bool freeMode;
  final int daysLeft;

  const _ServiceStatusCard({
    required this.service,
    required this.isExpired,
    required this.isExpiringSoon,
    required this.freeMode,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.success;
    String title = 'Listing is Live';
    IconData icon = Icons.check_circle;

    if (isExpired) {
      color = AppColors.error;
      title = 'Listing Expired';
      icon = Icons.error_outline;
    } else if (service.status == 'hidden') {
      color = AppColors.neutral500;
      title = 'Currently Hidden';
      icon = Icons.visibility_off;
    } else if (isExpiringSoon) {
      color = AppColors.warning;
      title = 'Expiring Soon';
      icon = Icons.timer_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium.copyWith(color: color, fontWeight: FontWeight.w900)),
                Text(isExpired ? 'Students cannot see this service.' : 'Students can see and book this service.', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractivePreview extends StatelessWidget {
  final Service service;
  final bool isExpired;
  const _InteractivePreview({required this.service, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => context.push('/student/service/${service.serviceId}'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Stack(
            children: [
              SizedBox(height: 160, width: double.infinity, child: AppNetworkImage(url: service.imageUrl, fallbackIcon: AppIcons.services)),
              Positioned(top: 12, right: 12, child: _PulseStatus(isLive: service.status == 'available' && !isExpired)),
              if (service.isAuthorized) 
                Positioned(top: 12, left: 12, child: _MiniBadge(label: 'AUTHORIZED', color: scheme.primary)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: Text(service.title, style: AppTextStyles.titleSmall, maxLines: 1)),
                Text(service.priceLabel, style: AppTextStyles.titleSmall.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: const Center(child: Text('Tap to view Student Page', style: TextStyle(fontSize: 11, color: Colors.grey))),
          ),
        ],
      ),
    );
  }
}

class _BillingSection extends StatelessWidget {
  final Service service;
  final bool freeMode;
  final DateTime expiresAt;
  final int daysLeft;
  final bool isExpired;
  final bool isExpiringSoon;
  final double authFee;
  final VoidCallback onAuthorize;

  const _BillingSection({
    required this.service,
    required this.freeMode,
    required this.expiresAt,
    required this.daysLeft,
    required this.isExpired,
    required this.isExpiringSoon,
    required this.authFee,
    required this.onAuthorize,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _BillingRow(
            label: 'Listing Plan',
            value: service.isAuthorized ? 'Authorized (Paid)' : (freeMode ? 'Unlimited (Free Mode)' : 'Standard Trial'),
            badge: service.isAuthorized ? 'PAID' : 'FREE',
            color: service.isAuthorized ? AppColors.success : AppColors.warning,
            icon: service.isAuthorized ? Icons.verified : Icons.card_membership_outlined,
          ),
          const Divider(height: 24),
          _BillingRow(
            label: isExpired ? 'Expired On' : 'Visibility Expires',
            value: freeMode ? 'No Expiration' : '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
            subtitle: freeMode ? 'Active for Marketplace Launch' : (isExpired ? 'Listing hidden' : '$daysLeft days left'),
            color: isExpired ? AppColors.error : (isExpiringSoon ? AppColors.warning : null),
            icon: Icons.event_available_outlined,
          ),
          if (!service.isAuthorized) ...[
            const SizedBox(height: 16),
            AppButton(
              label: isExpired ? 'Renew Now – GHS $authFee' : 'Go Authorized – GHS $authFee',
              icon: Icons.bolt,
              onPressed: onAuthorize,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreIndicator extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreIndicator({required this.score, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48, width: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(value: score / 100, strokeWidth: 6, color: color, backgroundColor: color.withValues(alpha: 0.1)),
          Center(child: Text('$score', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: AppTextStyles.labelSmall)]);
  }
}

class _PulseStatus extends StatelessWidget {
  final bool isLive;
  const _PulseStatus({required this.isLive});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: isLive ? AppColors.success : Colors.black87, borderRadius: AppRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(isLive ? 'LIVE' : 'OFFLINE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.brSm),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _BillingRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? badge;
  final Color? color;
  final IconData icon;

  const _BillingRow({required this.label, required this.value, this.subtitle, this.badge, this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: color ?? scheme.onSurfaceVariant, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              Row(
                children: [
                  Text(value, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold, color: color)),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: (color ?? scheme.primary).withValues(alpha: 0.1), borderRadius: AppRadius.brSm),
                      child: Text(badge!, style: TextStyle(color: color ?? scheme.primary, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) Text(subtitle!, style: AppTextStyles.labelSmall.copyWith(color: color)),
            ],
          ),
        ),
      ],
    );
  }
}
