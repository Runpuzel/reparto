import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/admin_providers.dart';

class AdminCampusesScreen extends ConsumerWidget {
  const AdminCampusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campuses = ref.watch(allCampusesProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allCampusesProvider),
        child: AsyncView<List<Campus>>(
          value: campuses,
          onRetry: () => ref.invalidate(allCampusesProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                    icon: Icons.school_outlined, title: 'No campuses yet'),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = list[i];
                final active = c.status == 'active';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.school),
                    title: Text(c.campusName),
                    subtitle: Text(c.location ?? '—'),
                    trailing: Switch(
                      value: active,
                      onChanged: (v) async {
                        await ref.read(adminRepositoryProvider).setCampusStatus(
                            c.campusId, v ? 'active' : 'inactive');
                        ref.invalidate(allCampusesProvider);
                        ref.invalidate(campusesProvider);
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
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
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Campus Name')),
            const SizedBox(height: 12),
            TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Location')),
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
                  location.text.trim().isEmpty ? null : location.text.trim());
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
