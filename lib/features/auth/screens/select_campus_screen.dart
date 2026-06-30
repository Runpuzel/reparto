import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/auth_providers.dart';

/// Shown to users (e.g. Google sign-in) who have no campus yet.
class SelectCampusScreen extends ConsumerStatefulWidget {
  const SelectCampusScreen({super.key});

  @override
  ConsumerState<SelectCampusScreen> createState() => _SelectCampusScreenState();
}

class _SelectCampusScreenState extends ConsumerState<SelectCampusScreen> {
  String? _campusId;
  bool _loading = false;

  Future<void> _save() async {
    if (_campusId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).setCampus(_campusId!);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final campuses = ref.watch(campusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Campus'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Where do you study?',
                      style: AppTextStyles.headlineSmall
                          .copyWith(color: scheme.onSurface)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You will only see sellers and products from this campus.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AsyncView<List<Campus>>(
                    value: campuses,
                    data: (list) => Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          Padding(
                            padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                            child: _CampusTile(
                              campus: list[i],
                              selected: _campusId == list[i].campusId,
                              onTap: () => setState(
                                      () => _campusId = list[i].campusId),
                            )
                                .animate()
                                .fadeIn(
                                delay: (i * 50).ms, duration: 300.ms)
                                .slideY(begin: 0.05, end: 0),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _loading ? 'Saving…' : 'Continue',
                    icon: _loading ? null : AppIcons.arrowRight,
                    loading: _loading,
                    onPressed: _campusId == null ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampusTile extends StatelessWidget {
  const _CampusTile({
    required this.campus,
    required this.selected,
    required this.onTap,
  });

  final Campus campus;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerLowest,
      border: Border.all(
        color: selected ? scheme.primary : scheme.outlineVariant,
        width: selected ? 1.6 : 1,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(
              AppIcons.campus,
              size: 22,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(campus.campusName,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: scheme.onSurface)),
                if (campus.location != null) ...[
                  const SizedBox(height: 2),
                  Text(campus.location!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          AnimatedScale(
            scale: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Icon(AppIcons.check, color: scheme.primary, size: 24),
          ),
        ],
      ),
    );
  }
}
