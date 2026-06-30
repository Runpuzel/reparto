import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// D1 — Service Detail.
class ServiceDetailScreen extends ConsumerWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceProvider(serviceId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Service')),
      body: serviceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(serviceProvider(serviceId))),
        data: (s) {
          if (s == null) {
            return const EmptyState(
                icon: Icons.handyman_outlined, title: 'Service not found');
          }
          final gallery = s.gallery;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: gallery.isNotEmpty
                          ? AppNetworkImage(
                          url: gallery.first, fallbackIcon: AppIcons.scissors)
                          : Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(AppIcons.scissors,
                            size: 64, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _tag(context, s.category.label, AppIcons.services),
                              const SizedBox(width: AppSpacing.sm),
                              _tag(context, s.priceLabel, AppIcons.price,
                                  accent: true),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(s.title,
                              style: AppTextStyles.headlineSmall
                                  .copyWith(color: scheme.onSurface)),
                          const SizedBox(height: AppSpacing.lg),
                          _section(context, 'About this service'),
                          const SizedBox(height: AppSpacing.xs + 2),
                          Text(
                            (s.description != null &&
                                s.description!.isNotEmpty)
                                ? s.description!
                                : 'No description provided.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (s.availability != null &&
                              s.availability!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _section(context, 'Availability'),
                            const SizedBox(height: AppSpacing.xs + 2),
                            _iconLine(context, AppIcons.clock, s.availability!),
                          ],
                          if (s.location != null && s.location!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _section(context, 'Location'),
                            const SizedBox(height: AppSpacing.xs + 2),
                            _iconLine(context, AppIcons.mapPin, s.location!),
                          ],
                          if (s.vendorName != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            AppCard(
                              onTap: () => context
                                  .push('/student/shop/${s.vendorId}'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: scheme.primaryContainer,
                                    child: Icon(AppIcons.storefrontFill,
                                        color: scheme.onPrimaryContainer,
                                        size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(s.vendorName!,
                                        style: AppTextStyles.titleSmall
                                            .copyWith(color: scheme.onSurface)),
                                  ),
                                  Icon(AppIcons.caretRight,
                                      size: 18, color: scheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _ActionBar(service: s),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String t) => Text(t,
      style: AppTextStyles.titleMedium
          .copyWith(color: Theme.of(context).colorScheme.onSurface));

  Widget _iconLine(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: scheme.onSurface))),
      ],
    );
  }

  Widget _tag(BuildContext context, String label, IconData icon,
      {bool accent = false}) {
    final scheme = Theme.of(context).colorScheme;
    final bg = accent
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.secondaryContainer.withValues(alpha: 0.6);
    final fg = accent ? scheme.primary : scheme.onSecondaryContainer;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final Service service;
  const _ActionBar({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Contact on WhatsApp',
                  icon: AppIcons.whatsapp,
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    if (isGuest) {
                      await SignInPrompt.show(context,
                          action: 'contact sellers');
                      return;
                    }
                    await _whatsapp(context, ref);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                // Booking & pay (D3) arrives with the escrow phase (P6).
                child: AppButton(
                  label: 'Booking soon',
                  icon: AppIcons.clock,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _whatsapp(BuildContext context, WidgetRef ref) async {
    final vendor =
    await ref.read(studentRepositoryProvider).fetchVendor(service.vendorId);
    final phone = vendor?.businessPhone ?? vendor?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'This seller has no contact number.');
      }
      return;
    }
    final intl = phone.startsWith('0') ? '233${phone.substring(1)}' : phone;
    final msg = Uri.encodeComponent(
        "Hi, I'm interested in ${service.title} on UjustBUY");
    final url = 'https://wa.me/$intl?text=$msg';
    try {
      final ok =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ConfirmActions.showError(context, 'Could not open WhatsApp.');
      }
    } catch (_) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open WhatsApp.');
      }
    }
  }
}
