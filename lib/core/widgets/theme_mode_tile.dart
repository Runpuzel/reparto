import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart';

/// A card with a segmented control to switch between System / Light / Dark.
class ThemeModeTile extends ConsumerWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_6_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text('Appearance',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark')),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => notifier.set(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact icon button that cycles theme modes — handy in app bars.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final icon = switch (mode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };
    return IconButton(
      tooltip: 'Toggle theme',
      icon: Icon(icon),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
