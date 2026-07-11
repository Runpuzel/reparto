import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../models/models.dart';

class ServiceCard extends StatelessWidget {
  final Service service;
  final bool showVendor;

  const ServiceCard({super.key, required this.service, this.showVendor = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = service.gallery.isNotEmpty ? service.gallery.first : null;
    final icon = AppIcons.serviceCategory(service.category.db);

    return AppCard(
      onTap: () => context.push('/student/service/${service.serviceId}'),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      borderRadius: AppRadius.brLg,
      shadows: AppShadows.level1,
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.82)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brMd,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover != null
                      ? AppNetworkImage(url: cover, fallbackIcon: icon)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.primaryContainer,
                                scheme.secondaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: scheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                  if (service.gallery.length > 1)
                    Positioned(
                      left: AppSpacing.xs,
                      top: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          borderRadius: AppRadius.brFull,
                        ),
                        child: Icon(
                          AppIcons.images,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryTag(label: service.category.label, icon: icon),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
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
                          service.vendorName!,
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
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.caretRight, color: scheme.primary, size: 19),
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.62),
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: scheme.onSecondaryContainer,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
