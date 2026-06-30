import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

/// E1 — "What would you like to post?" type chooser (bottom sheet).
Future<void> showSellChooser(BuildContext context, WidgetRef ref) async {
  // Active-service count gate (spec: non-Student-Sellers cap at 2; here we use
  // it to warn — Student Sellers are unlimited, but the count check is cheap
  // and informative for everyone).
  int activeServices = 0;
  try {
    final vendor = await ref.read(currentVendorProvider.future);
    if (vendor != null) {
      activeServices =
      await ref.read(vendorRepositoryProvider).activeServiceCount(vendor.vendorId);
    }
  } catch (_) {/* non-fatal; default 0 */}

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _SellChooserSheet(activeServices: activeServices),
  );
}

class _SellChooserSheet extends StatelessWidget {
  final int activeServices;
  const _SellChooserSheet({required this.activeServices});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final serviceLimitReached = activeServices >= 2;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.sm, bottom: AppSpacing.md),
              child: Text('What would you like to post?',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: scheme.onSurface)),
            ),
            _Option(
              icon: AppIcons.bag,
              title: 'Sell a Product',
              subtitle:
              'List something to sell — books, electronics, clothes, and more.',
              onTap: () {
                Navigator.pop(context);
                context.push('/vendor/product-form');
              },
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            _Option(
              icon: AppIcons.services,
              title: 'Offer a Service',
              subtitle: serviceLimitReached
                  ? 'You have 2 active services. Remove one to add another.'
                  : 'Offer your skills — tutoring, barbering, repairs, and more.',
              disabled: serviceLimitReached,
              onTap: () {
                Navigator.pop(context);
                context.push('/vendor/service-form');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppRadius.brLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled
              ? () => ConfirmActions.toast(
              context, 'Daily/active limit reached for this type.')
              : onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: AppTextStyles.titleSmall
                                  .copyWith(color: scheme.onSurface)),
                          if (disabled) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(AppIcons.lock,
                                size: 14, color: scheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.bodySmall),
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
}
