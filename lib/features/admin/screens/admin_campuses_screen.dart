import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/admin_providers.dart';

class AdminCampusesScreen extends ConsumerWidget {
  const AdminCampusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campuses = ref.watch(allCampusesProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allCampusesProvider),
        child: campuses.when(
          loading: () => const SkeletonList(itemCount: 6, itemHeight: 72),
          error: (e, _) => ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(allCampusesProvider)),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                    icon: Icons.school_outlined, title: 'No campuses yet'),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = list[i];
                final active = c.status == 'active';
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Icon(AppIcons.campusFill, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.campusName,
                                style: AppTextStyles.titleSmall
                                    .copyWith(color: scheme.onSurface)),
                            const SizedBox(height: 2),
                            Text(c.location ?? '—',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      Switch(
                        value: active,
                        onChanged: (v) async {
                          await ref
                              .read(adminRepositoryProvider)
                              .setCampusStatus(
                              c.campusId, v ? 'active' : 'inactive');
                          ref.invalidate(allCampusesProvider);
                          ref.invalidate(campusesProvider);
                        },
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: (30 * (i % 14)).ms, duration: 260.ms)
                    .slideY(begin: 0.04, end: 0);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: Icon(AppIcons.add),
        label: const Text('Add Campus'),
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final location = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Campus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: name, label: 'Campus Name'),
            const SizedBox(height: AppSpacing.sm + 4),
            AppTextField(controller: location, label: 'Location'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await ref.read(adminRepositoryProvider).createCampus(
                  name.text.trim(),
                  location.text.trim().isEmpty
                      ? null
                      : location.text.trim());
              ref.invalidate(allCampusesProvider);
              ref.invalidate(campusesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
