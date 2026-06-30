import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_actions.dart';

/// "Forgot Passcode" — the user enters their account email, then we hand them
/// off to the developer on WhatsApp to recover access.
class ForgotPasscodeScreen extends StatefulWidget {
  const ForgotPasscodeScreen({super.key});

  @override
  State<ForgotPasscodeScreen> createState() => _ForgotPasscodeScreenState();
}

class _ForgotPasscodeScreenState extends State<ForgotPasscodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _email.text.trim();
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Contact support?',
      message:
      'We will open WhatsApp so you can message the developer to reset your passcode for "$email".',
      confirmLabel: 'Open WhatsApp',
      icon: Icons.chat_outlined,
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    final message = Uri.encodeComponent(
        'Hello ${AppConstants.devName}, I forgot my ${AppConstants.appName} '
            'passcode. My account email is: $email. Please help me reset it.');
    final url = 'https://wa.me/${AppConstants.devWhatsApp}?text=$message';

    try {
      final ok =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ConfirmActions.showError(
            context, 'Could not open WhatsApp. Is it installed?');
      }
    } catch (_) {
      if (mounted) {
        ConfirmActions.showError(
            context, 'Could not open WhatsApp. Is it installed?');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Passcode')),
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
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: AppRadius.brXl,
                        ),
                        child: Icon(AppIcons.lockReset,
                            size: 36, color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Reset your passcode',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: scheme.onSurface)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enter the email linked to your account. We will connect '
                          'you with our support team on WhatsApp to help you regain '
                          'access.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      controller: _email,
                      label: 'Account email',
                      prefixIcon: AppIcons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _loading
                          ? 'Opening WhatsApp…'
                          : 'Contact Support',
                      icon: _loading ? null : AppIcons.whatsapp,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Text(
                        'Support: ${AppConstants.devPhone}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
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
