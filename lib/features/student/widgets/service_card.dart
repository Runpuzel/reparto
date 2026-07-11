import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../models/models.dart';

class ServiceCard extends StatelessWidget {
  final Service service;
  final bool showVendor;

  const ServiceCard({
    super.key,
    required this.service,
    this.showVendor = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = service.gallery.isNotEmpty ? service.gallery.first : null;
    final icon = AppIcons.serviceCategory(service.category.db);

    return AppCard(
      onTap: () => context.push('/student/service/${service.serviceId}'),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brLg,
            child: SizedBox(
              width: 64,
              height: 64,
              child: cover != null
                  ? AppNetworkImage(url: cover, fallbackIcon: icon)
                  : Container(
                      color: scheme.primaryContainer,
                      child: Icon(
                        icon,
                        color: scheme.onPrimaryContainer,
                        size: 26,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                _CategoryTag(label: service.category.label, icon: icon),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      service.priceLabel,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showVendor && service.vendorName != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '- ${service.vendorName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(AppIcons.caretRight, color: scheme.onSurfaceVariant, size: 18),
        ],
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _CategoryTag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
