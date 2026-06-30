import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_icons.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// H1 — Sign-In Prompt (interstitial bottom sheet).
///
/// Shown whenever a guest taps an action that requires an account
/// (contact seller, buy, save, sell, etc.). It overlays the current screen,
/// preserving context. Returns `true` if the user chose to sign in / register
/// (so callers can resume the attempted action after auth resolves).
class SignInPrompt {
  const SignInPrompt._();

  /// [action] is a short phrase completing "You need an account to …",
  /// e.g. "contact sellers", "buy items", "save listings", "post listings".
  static Future<bool> show(BuildContext context, {required String action}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SignInSheet(action: action),
    );
    return result ?? false;
  }
}

class _SignInSheet extends StatelessWidget {
  final String action;
  const _SignInSheet({required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.lock, size: 42, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Sign in to continue',
                style: AppTextStyles.headlineSmall
                    .copyWith(color: scheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text('You need an account to $action.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign In',
              icon: AppIcons.signIn,
              onPressed: () {
                Navigator.pop(context, true);
                context.push('/login');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Create Account',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(context, true);
                context.push('/register/student');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue Browsing'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience: returns true if the user is allowed to proceed (signed in),
/// otherwise shows the prompt and returns false. [isGuest] is provided by the
/// caller (it knows the auth state via Riverpod).
Future<bool> requireAuth(
    BuildContext context, {
      required bool isGuest,
      required String action,
    }) async {
  if (!isGuest) return true;
  await SignInPrompt.show(context, action: action);
  return false;
}
