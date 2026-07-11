import 'app_install_service_stub.dart'
    if (dart.library.html) 'app_install_service_web.dart'
    as platform;

enum AppInstallStatus { accepted, dismissed, installed, unavailable, failed }

Future<AppInstallStatus> promptAppInstall() async {
  final status = await platform.promptAppInstall();
  return switch (status) {
    'accepted' => AppInstallStatus.accepted,
    'dismissed' => AppInstallStatus.dismissed,
    'installed' => AppInstallStatus.installed,
    'unavailable' => AppInstallStatus.unavailable,
    _ => AppInstallStatus.failed,
  };
}
