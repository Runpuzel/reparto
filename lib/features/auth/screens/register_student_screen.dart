import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
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
    final campuses = ref.watch(campusesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Student Sign Up')),
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
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => Validators.required(v, 'Full name'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    AsyncView<List<Campus>>(
                      value: campuses,
                      data: (list) => DropdownButtonFormField<String>(
                        value: _campusId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Campus',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: list
                            .map((c) => DropdownMenuItem(
                            value: c.campusId, child: Text(c.campusName)))
                            .toList(),
                        onChanged: (v) => setState(() => _campusId = v),
                        validator: (v) => v == null ? 'Select your campus' : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: '8+ chars, 1 number, 1 uppercase',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                          : const Text('Create Account'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
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
