import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/auth_providers.dart';

class GoogleAuthButton extends ConsumerStatefulWidget {
  final VoidCallback onSignedIn;
  final ValueChanged<Object> onError;

  const GoogleAuthButton({
    super.key,
    required this.onSignedIn,
    required this.onError,
  });

  @override
  ConsumerState<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends ConsumerState<GoogleAuthButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _GoogleButtonShell(child: _GoogleSpinner());
    }

    return GoogleButton(onPressed: _signIn);
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      widget.onSignedIn();
    } catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _GoogleButtonShell extends StatelessWidget {
  final Widget child;

  const _GoogleButtonShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: child,
    );
  }
}

class _GoogleSpinner extends StatelessWidget {
  const _GoogleSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
