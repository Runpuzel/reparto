import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../../../core/theme/app_theme.dart';
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
  StreamSubscription<GoogleSignInAccount?>? _subscription;
  bool _loading = false;
  String? _handledAccountId;

  @override
  void initState() {
    super.initState();
    final googleSignIn = ref.read(authRepositoryProvider).googleSignIn;
    _subscription = googleSignIn.onCurrentUserChanged.listen(
      _handleAccount,
      onError: _handleError,
    );
    googleSignIn.signInSilently().then(_handleAccount).catchError((Object e) {
      if (!_isSignInRequired(e)) _handleError(e);
      return null;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _GoogleButtonShell(child: _GoogleSpinner());
    }

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = constraints.maxWidth
              .clamp(200.0, 400.0)
              .round();
          return Semantics(
            button: true,
            label: 'Continue with Google',
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: google_web.renderButton(
                  configuration: google_web.GSIButtonConfiguration(
                    type: google_web.GSIButtonType.standard,
                    theme: google_web.GSIButtonTheme.outline,
                    size: google_web.GSIButtonSize.large,
                    text: google_web.GSIButtonText.continueWith,
                    shape: google_web.GSIButtonShape.rectangular,
                    logoAlignment: google_web.GSIButtonLogoAlignment.left,
                    minimumWidth: buttonWidth,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAccount(GoogleSignInAccount? account) async {
    if (account == null || _loading || _handledAccountId == account.id) return;
    _handledAccountId = account.id;
    setState(() => _loading = true);

    try {
      await ref.read(authRepositoryProvider).signInWithGoogleAccount(account);
      widget.onSignedIn();
    } catch (e) {
      _handledAccountId = null;
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleError(Object error) {
    if (!mounted || _isSignInRequired(error)) return;
    widget.onError(error);
  }

  bool _isSignInRequired(Object error) {
    return error is PlatformException &&
        error.code == GoogleSignIn.kSignInRequiredError;
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
