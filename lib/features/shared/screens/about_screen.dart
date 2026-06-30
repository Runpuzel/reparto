import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_actions.dart';

/// Shows app version and developer / publisher information.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.sm + 4),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.brXl,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Image.asset(
                    'assets/ujustbuy_logo.jpeg',
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: AppRadius.brFull,
                  ),
                  child: Text(
                    'Version ${AppConstants.appVersion} (${AppConstants.buildNumber})',
                    style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 12.5, color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
          const SizedBox(height: AppSpacing.xl),
          Text('Developer',
              style: AppTextStyles.titleSmall
                  .copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(context,
                    icon: AppIcons.user,
                    label: 'Full name',
                    value: AppConstants.devName),
                const Divider(height: 1),
                _tile(context,
                    icon: AppIcons.business,
                    label: 'Business name',
                    value: AppConstants.devBusinessName),
                const Divider(height: 1),
                _tile(context,
                    icon: AppIcons.phoneBusiness,
                    label: 'Business number',
                    value: AppConstants.devPhone,
                    onTap: () =>
                        _launch(context, 'tel:${AppConstants.devPhone}')),
                const Divider(height: 1),
                _tile(context,
                    icon: AppIcons.email,
                    label: 'Business email',
                    value: AppConstants.devEmail,
                    onTap: () =>
                        _launch(context, 'mailto:${AppConstants.devEmail}')),
                const Divider(height: 1),
                _tile(context,
                    icon: AppIcons.chat,
                    label: 'WhatsApp support',
                    value: 'Chat with the developer',
                    onTap: () => _launch(context,
                        'https://wa.me/${AppConstants.devWhatsApp}')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
                '© ${DateTime.now().year} ${AppConstants.devBusinessName}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
        required String label,
        required String value,
        VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: AppTextStyles.bodySmall),
      subtitle: Text(value,
          style: AppTextStyles.titleSmall
              .copyWith(color: Theme.of(context).colorScheme.onSurface)),
      trailing: onTap != null ? Icon(AppIcons.openInNew, size: 18) : null,
      onTap: onTap,
    );
  }

  Future<void> _launch(BuildContext context, String url) async {
    try {
      final ok =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ConfirmActions.showError(context, 'Could not open this on your device.');
      }
    } catch (_) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open this on your device.');
      }
    }
  }
}
