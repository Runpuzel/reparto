import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Where do you study?',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'You will only see vendors and products from this campus.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AsyncView<List<Campus>>(
                    value: campuses,
                    data: (list) => Column(
                      children: list
                          .map((c) => Card(
                        child: RadioListTile<String>(
                          value: c.campusId,
                          groupValue: _campusId,
                          onChanged: (v) =>
                              setState(() => _campusId = v),
                          title: Text(c.campusName),
                          subtitle:
                          c.location != null ? Text(c.location!) : null,
                        ),
                      ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (_campusId == null || _loading) ? null : _save,
                    child: _loading
                        ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white))
                        : const Text('Continue'),
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
