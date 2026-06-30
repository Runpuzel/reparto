import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/auth_providers.dart';

class RegisterStudentScreen extends ConsumerStatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  ConsumerState<RegisterStudentScreen> createState() =>
      _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends ConsumerState<RegisterStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _campusId;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_campusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your campus')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUpStudent(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        campusId: _campusId!,
      );
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account created! Check your email to verify.'),
        backgroundColor: Colors.green,
      ));
      context.go('/login');
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final campuses = ref.watch(campusesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Sign Up')),
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
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: AppRadius.brLg,
                        ),
                        child: Icon(AppIcons.student,
                            size: 32, color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Create your student account',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: scheme.onSurface)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Join your campus marketplace in seconds',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      controller: _name,
                      label: 'Full Name',
                      prefixIcon: AppIcons.user,
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validators.required(v, 'Full name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      prefixIcon: AppIcons.email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView<List<Campus>>(
                      value: campuses,
                      data: (list) => DropdownButtonFormField<String>(
                        value: _campusId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Campus',
                          prefixIcon: Icon(AppIcons.campus, size: 20),
                        ),
                        items: list
                            .map((c) => DropdownMenuItem(
                            value: c.campusId, child: Text(c.campusName)))
                            .toList(),
                        onChanged: (v) => setState(() => _campusId = v),
                        validator: (v) =>
                        v == null ? 'Select your campus' : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      helper: '8+ chars, 1 number, 1 uppercase',
                      prefixIcon: AppIcons.lock,
                      obscureText: _obscure,
                      suffixIcon: _obscure ? AppIcons.eyeOff : AppIcons.eye,
                      onSuffixTap: () => setState(() => _obscure = !_obscure),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _loading ? 'Creating account…' : 'Create Account',
                      icon: _loading ? null : AppIcons.check,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ]
                      .animate(interval: 55.ms)
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
