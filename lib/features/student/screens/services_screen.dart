import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../providers/student_providers.dart';
import '../widgets/service_card.dart';

/// Student services browse. Category chips plus a vertical service list.
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
                AppSpacing.sm + 4,
                AppSpacing.sm,
                AppSpacing.sm + 4,
                0,
              ),
              children: [
                _chip(
                  context,
                  ref,
                  label: 'All',
                  value: null,
                  selected: selected == null,
                ),
                ...ServiceCategory.values.map(
                  (category) => _chip(
                    context,
                    ref,
                    label: category.label,
                    value: category,
                    selected: selected == category,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: services.when(
              loading: () => const SkeletonList(itemCount: 6, itemHeight: 96),
              error: (e, _) => ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(servicesProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 100),
                      EmptyState(
                        icon: Icons.handyman_outlined,
                        title: 'No services yet',
                        subtitle:
                            'Student services on your campus will appear here.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm + 4,
                    AppSpacing.sm,
                    AppSpacing.sm + 4,
                    AppSpacing.md,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => ServiceCard(service: list[i])
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

  Widget _chip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required ServiceCategory? value,
    required bool selected,
  }) {
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
