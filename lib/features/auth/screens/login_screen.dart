import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/auth_providers.dart';

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
  bool _googleLoading = false;

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
      await ref.read(authRepositoryProvider).signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      ref.invalidate(currentUserProvider);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      ref.invalidate(currentUserProvider);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Hero header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            AppConstants.appName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Sign in to your campus marketplace',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-passcode'),
                        child: const Text('Forgot passcode?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const _Spinner()
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                    ]),
                    const SizedBox(height: 18),
                    _googleLoading
                        ? const Center(child: _Spinner(dark: true))
                        : GoogleButton(onPressed: _google),
                    const SizedBox(height: 28),
                    _SignupRow(),
                  ],
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
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text("New here? "),
            TextButton(
              onPressed: () => context.push('/register/student'),
              child: const Text('Create student account'),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/register/vendor'),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Register as a vendor'),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  final bool dark;
  const _Spinner({this.dark = false});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    width: 22,
    child: CircularProgressIndicator(
      strokeWidth: 2.4,
      color: dark ? Theme.of(context).colorScheme.primary : Colors.white,
    ),
  );
}
