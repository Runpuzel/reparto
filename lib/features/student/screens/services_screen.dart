import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';

/// D2 — Services Browse. Category chips + a vertical list of service cards.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final selected = ref.watch(serviceCategoryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(servicesProvider),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 4, AppSpacing.sm, AppSpacing.sm + 4, 0),
              children: [
                _chip(context, ref, label: 'All', value: null, selected: selected == null),
                ...ServiceCategory.values.map((c) => _chip(context, ref,
                    label: c.label, value: c, selected: selected == c)),
              ],
            ),
          ),
          Expanded(
            child: services.when(
              loading: () => const SkeletonList(itemCount: 6, itemHeight: 96),
              error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(servicesProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 100),
                    EmptyState(
                      icon: Icons.handyman_outlined,
                      title: 'No services yet',
                      subtitle:
                      'Student services on your campus will appear here.',
                    ),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm + 4,
                      AppSpacing.sm, AppSpacing.sm + 4, AppSpacing.md),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _ServiceCard(service: list[i])
                      .animate()
                      .fadeIn(delay: (40 * (i % 12)).ms, duration: 280.ms)
                      .slideY(begin: 0.05, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref,
      {required String label,
        required ServiceCategory? value,
        required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) =>
        ref.read(serviceCategoryProvider.notifier).state = value,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = service.gallery.isNotEmpty ? service.gallery.first : null;
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
                  ? AppNetworkImage(url: cover, fallbackIcon: AppIcons.scissors)
                  : Container(
                color: scheme.primaryContainer,
                child: Icon(AppIcons.scissors,
                    color: scheme.onPrimaryContainer, size: 26),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                const SizedBox(height: 3),
                _CategoryTag(label: service.category.label),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(service.priceLabel,
                        style: AppTextStyles.titleSmall.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800)),
                    if (service.vendorName != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text('· ${service.vendorName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: scheme.onSurfaceVariant)),
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
  const _CategoryTag({required this.label});

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
          Icon(AppIcons.services, size: 11, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: scheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}
