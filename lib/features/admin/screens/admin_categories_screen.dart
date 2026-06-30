import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/admin_providers.dart';

/// Admin management of product categories (add / edit / remove + description).
class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminCategoriesProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminCategoriesProvider),
        child: categories.when(
          loading: () => const SkeletonList(itemCount: 6, itemHeight: 72),
          error: (e, _) => ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(adminCategoriesProvider)),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  subtitle: 'Add categories to organise products.',
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = list[i];
                final hasDesc =
                    c.description != null && c.description!.isNotEmpty;
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Icon(AppIcons.tag, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.categoryName,
                                style: AppTextStyles.titleSmall
                                    .copyWith(color: scheme.onSurface)),
                            if (hasDesc) ...[
                              const SizedBox(height: 2),
                              Text(c.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color: scheme.onSurfaceVariant),
                        onSelected: (v) {
                          if (v == 'edit') {
                            _editDialog(context, ref, category: c);
                          } else if (v == 'delete') {
                            _delete(context, ref, c);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(AppIcons.edit, size: 18),
                              const SizedBox(width: AppSpacing.sm + 4),
                              const Text('Edit'),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(AppIcons.trash,
                                  size: 18, color: AppColors.error),
                              const SizedBox(width: AppSpacing.sm + 4),
                              Text('Remove',
                                  style: TextStyle(color: AppColors.error)),
                            ]),
                          ),
                        ],
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
        onPressed: () => _editDialog(context, ref),
        icon: Icon(AppIcons.add),
        label: const Text('Add Category'),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove category?'),
        content: Text(
            'Remove "${c.categoryName}"? Products keep working but lose this category.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(c.categoryId);
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
      if (context.mounted) ConfirmActions.toast(context, 'Category removed');
    } catch (e) {
      if (context.mounted) ConfirmActions.showError(context, e);
    }
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref,
      {Category? category}) async {
    final isEdit = category != null;
    final name = TextEditingController(text: category?.categoryName ?? '');
    final desc = TextEditingController(text: category?.description ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'New Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: name,
                label: 'Category name',
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              AppTextField(
                controller: desc,
                label: 'Description (optional)',
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(adminRepositoryProvider);
              try {
                if (isEdit) {
                  await repo.updateCategory(
                      category.categoryId,
                      name.text.trim(),
                      desc.text.trim().isEmpty ? null : desc.text.trim());
                } else {
                  await repo.createCategory(name.text.trim(),
                      desc.text.trim().isEmpty ? null : desc.text.trim());
                }
                ref.invalidate(adminCategoriesProvider);
                ref.invalidate(categoriesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ConfirmActions.showError(ctx, e);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }
}
