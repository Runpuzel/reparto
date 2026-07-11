import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_install_service.dart';
import '../theme/app_icons.dart';

class AppInstallButton extends StatelessWidget {
  const AppInstallButton({super.key});

  @override
  Widget build(BuildContext context) {
    const downloadBlue = Color(0xFF1976D2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: 'Install app',
        style: IconButton.styleFrom(
          backgroundColor: downloadBlue.withValues(alpha: 0.14),
          foregroundColor: downloadBlue,
          fixedSize: const Size(44, 44),
          iconSize: 23,
        ),
        icon: const Icon(AppIcons.download),
        onPressed: () async {
          if (!kIsWeb) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Open UjustBUY in your browser to install it.'),
              ),
            );
            return;
          }

          final status = await promptAppInstall();
          if (!context.mounted) return;

          final message = switch (status) {
            AppInstallStatus.accepted => 'Installing UjustBUY...',
            AppInstallStatus.installed => 'UjustBUY is already installed.',
            AppInstallStatus.dismissed => 'Install dismissed.',
            AppInstallStatus.unavailable =>
              'Use your browser menu and choose Add to Home screen.',
            AppInstallStatus.failed =>
              'Could not start install. Use your browser menu and choose Add to Home screen.',
          };

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    );
  }
}
