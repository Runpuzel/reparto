import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import 'confirm_actions.dart';

/// A profile card that surfaces app version + developer/publisher details with
/// tappable actions (call, email, WhatsApp).
class DeveloperInfoCard extends StatelessWidget {
  const DeveloperInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('About & Developer',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v${AppConstants.appVersion}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _row(context,
                icon: Icons.person_outline,
                label: 'Developer',
                value: AppConstants.devName),
            _row(context,
                icon: Icons.business_outlined,
                label: 'Business',
                value: AppConstants.devBusinessName),
            _row(context,
                icon: Icons.call_outlined,
                label: 'Business number',
                value: AppConstants.devPhone,
                onTap: () => _launch(context, 'tel:${AppConstants.devPhone}')),
            _row(context,
                icon: Icons.email_outlined,
                label: 'Business email',
                value: AppConstants.devEmail,
                onTap: () =>
                    _launch(context, 'mailto:${AppConstants.devEmail}')),
            _row(context,
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                value: 'Chat with the developer',
                onTap: () => _launch(
                    context, 'https://wa.me/${AppConstants.devWhatsApp}')),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                child: Text(
                  '© ${DateTime.now().year} ${AppConstants.devBusinessName} · '
                      'Version ${AppConstants.appVersion} (${AppConstants.buildNumber})',
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context,
      {required IconData icon,
        required String label,
        required String value,
        VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 1),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 16, color: scheme.primary),
          ],
        ),
      ),
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
