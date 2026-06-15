import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
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
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Text(AppConstants.appName,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    )),
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version ${AppConstants.appVersion} (${AppConstants.buildNumber})',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Developer',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _tile(context,
                    icon: Icons.person_outline,
                    label: 'Full name',
                    value: AppConstants.devName),
                const Divider(height: 1),
                _tile(context,
                    icon: Icons.business_outlined,
                    label: 'Business name',
                    value: AppConstants.devBusinessName),
                const Divider(height: 1),
                _tile(context,
                    icon: Icons.call_outlined,
                    label: 'Business number',
                    value: AppConstants.devPhone,
                    onTap: () => _launch(context, 'tel:${AppConstants.devPhone}')),
                const Divider(height: 1),
                _tile(context,
                    icon: Icons.email_outlined,
                    label: 'Business email',
                    value: AppConstants.devEmail,
                    onTap: () =>
                        _launch(context, 'mailto:${AppConstants.devEmail}')),
                const Divider(height: 1),
                _tile(context,
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp support',
                    value: 'Chat with the developer',
                    onTap: () => _launch(context,
                        'https://wa.me/${AppConstants.devWhatsApp}')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('© ${DateTime.now().year} ${AppConstants.devBusinessName}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
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
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: onTap != null ? const Icon(Icons.open_in_new, size: 18) : null,
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
