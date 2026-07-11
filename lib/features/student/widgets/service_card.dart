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

class ServiceCard extends StatefulWidget {
  final Service service;
  final bool showVendor;

  const ServiceCard({super.key, required this.service, this.showVendor = true});

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  late final PageController _imageController;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ServiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.serviceId != widget.service.serviceId ||
        oldWidget.service.gallery.length != widget.service.gallery.length) {
      _imageIndex = 0;
      if (_imageController.hasClients) {
        _imageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final service = widget.service;
    final gallery = service.gallery;
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
              child: _ServiceCardGallery(
                controller: _imageController,
                fallbackIcon: icon,
                images: gallery,
                index: _imageIndex,
                onChanged: (i) => setState(() => _imageIndex = i),
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
                    if (widget.showVendor && service.vendorName != null) ...[
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

class _ServiceCardGallery extends StatelessWidget {
  final PageController controller;
  final IconData fallbackIcon;
  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  const _ServiceCardGallery({
    required this.controller,
    required this.fallbackIcon,
    required this.images,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (images.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.secondaryContainer.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(fallbackIcon, color: scheme.onPrimaryContainer, size: 28),
      );
    }

    if (images.length == 1) {
      return AppNetworkImage(url: images.first, fallbackIcon: fallbackIcon);
    }

    final safeIndex = index.clamp(0, images.length - 1).toInt();
    final dotCount = images.length > 5 ? 5 : images.length;
    final activeDot = images.length <= 5
        ? safeIndex
        : (safeIndex * (dotCount - 1) / (images.length - 1)).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (_, i) =>
              AppNetworkImage(url: images[i], fallbackIcon: fallbackIcon),
        ),
        Positioned(
          top: AppSpacing.xs,
          right: AppSpacing.xs,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.54),
              borderRadius: AppRadius.brFull,
            ),
            child: Text(
              '${safeIndex + 1}/${images.length}',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.xs,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              dotCount,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: i == activeDot ? 10 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: i == activeDot
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.62),
                  borderRadius: AppRadius.brFull,
                ),
              ),
            ),
          ),
        ),
      ],
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
