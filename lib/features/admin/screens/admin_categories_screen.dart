import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminCategoriesProvider),
        child: AsyncView<List<Category>>(
          value: categories,
          onRetry: () => ref.invalidate(adminCategoriesProvider),
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
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = list[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.label_outline)),
                    title: Text(c.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: (c.description != null &&
                        c.description!.isNotEmpty)
                        ? Text(c.description!)
                        : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          _editDialog(context, ref, category: c);
                        } else if (v == 'delete') {
                          _delete(context, ref, c);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Remove')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(context, ref),
        icon: const Icon(Icons.add),
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
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Category name'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: desc,
                decoration:
                const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
