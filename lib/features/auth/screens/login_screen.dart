import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';
import '../widgets/google_auth_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppError.friendly(e)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children:
                      [
                            const SizedBox(height: AppSpacing.md),
                            // Brand logo on a soft card for a polished first impression.
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  borderRadius: AppRadius.brXl,
                                  border: Border.all(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/ujustbuy_logo.jpeg',
                                  height: 72,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Welcome back 👋',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs + 2),
                            Text(
                              'Sign in to your campus marketplace',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppTextField(
                              controller: _email,
                              label: 'Email',
                              prefixIcon: AppIcons.email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _password,
                              label: 'Password',
                              prefixIcon: AppIcons.lock,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              suffixIcon: _obscure
                                  ? AppIcons.eyeOff
                                  : AppIcons.eye,
                              onSuffixTap: () =>
                                  setState(() => _obscure = !_obscure),
                              onSubmitted: (_) => _signIn(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.push('/forgot-passcode'),
                                child: const Text('Forgot passcode?'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: _loading ? 'Signing in…' : 'Sign in',
                              icon: _loading ? null : AppIcons.signIn,
                              loading: _loading,
                              onPressed: _signIn,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: scheme.outlineVariant),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: Text(
                                    'or',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: scheme.outlineVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            GoogleAuthButton(
                              onSignedIn: () =>
                                  ref.invalidate(currentUserProvider),
                              onError: _showError,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            const _SignupRow(),
                          ]
                          .animate(interval: 60.ms)
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.04, end: 0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupRow extends StatelessWidget {
  const _SignupRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('New here? '),
            TextButton(
              onPressed: () => context.push('/register/student'),
              child: const Text('Create student account'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Become a Student Seller',
          icon: AppIcons.storefront,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.push('/register/vendor'),
        ),
      ],
    );
  }
}
