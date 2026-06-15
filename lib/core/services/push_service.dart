import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/supabase_client.dart';

/// Top-level background handler (must be a top-level or static function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the OS displays the notification. Hook analytics here if needed.
}

/// Manages FCM registration, token persistence, foreground display and taps.
class PushService {
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  /// Set from main.dart so notification taps can navigate.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Set true in main.dart once Firebase.initializeApp() succeeds.
  static bool firebaseReady = false;

  static bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'reparto_default',
    'JustBUY Notifications',
    description: 'Order updates and account notices',
    importance: Importance.high,
  );

  /// The VAPID key required for web push. Pass via --dart-define or .env and
  /// wire it through if you target web. Leave null for mobile-only.
  static String? webVapidKey;

  /// Last error encountered, surfaced in the in-app diagnostic.
  static String? lastError;

  /// Call after Firebase.initializeApp() and after the user is signed in.
  /// Safe to call multiple times.
  static Future<void> init() async {
    if (!firebaseReady) {
      debugPrint('PushService.init skipped: Firebase not initialized '
          '(missing config or ENABLE_PUSH=false).');
      return;
    }
    try {
      // Firebase must be initialized first (done in main.dart). If it isn't,
      // FirebaseMessaging.instance will throw — caught below.
      final messaging = FirebaseMessaging.instance;

      if (!_initialized) {
        // Permissions (iOS + Android 13+ + web)
        final settings = await messaging.requestPermission(
            alert: true, badge: true, sound: true);
        debugPrint(
            'PushService: permission = ${settings.authorizationStatus}');

        // Local notifications (foreground display + tap handling).
        // Skip on web — flutter_local_notifications is mobile/desktop only.
        if (!kIsWeb) {
          const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          const iosInit = DarwinInitializationSettings();
          await _local.initialize(
            const InitializationSettings(android: androidInit, iOS: iosInit),
            onDidReceiveNotificationResponse: (resp) => _openNotifications(),
          );
          await _local
              .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(_channel);
        }

        // Foreground messages -> show a local notification.
        FirebaseMessaging.onMessage.listen(_showForeground);

        // Tapped a push while app was in background.
        FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotifications());

        // Opened from terminated state via a push.
        final initialMsg = await messaging.getInitialMessage();
        if (initialMsg != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _openNotifications());
        }

        _initialized = true;
      }

      // iOS needs the APNs token before an FCM token can be issued.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.getAPNSToken();
      }

      // Persist the token and keep it fresh (every login).
      final token =
      await messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
      debugPrint('PushService: FCM token = '
          '${token == null ? 'NULL' : '${token.substring(0, 12)}…'}');
      if (token != null) {
        await _saveToken(token);
      } else {
        lastError = 'FCM returned a null token. On web, set a VAPID key; '
            'on Android, ensure google-services.json + Google Play services.';
      }
      messaging.onTokenRefresh.listen(_saveToken);
    } catch (e, st) {
      lastError = e.toString();
      debugPrint('PushService.init failed: $e\n$st');
    }
  }

  /// Force a token fetch + save and return a human-readable status. Handy for
  /// an in-app "Test notifications" / diagnostics button.
  static Future<String> debugStatus() async {
    if (currentAuthUser == null) return 'Not signed in.';
    try {
      final messaging = FirebaseMessaging.instance;
      final perm = await messaging.requestPermission();
      final token =
      await messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
      if (token == null) {
        return 'Permission: ${perm.authorizationStatus.name}. '
            'No FCM token (lastError: ${lastError ?? 'none'}).';
      }
      await _saveToken(token);
      return 'OK — token saved (${token.substring(0, 12)}…). '
          'Permission: ${perm.authorizationStatus.name}.';
    } catch (e) {
      return 'Failed: $e';
    }
  }

  static void _openNotifications() {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;
    // Use GoRouter's extension via Navigator-agnostic push.
    try {
      // ignore: use_build_context_synchronously
      _go(ctx, '/notifications');
    } catch (_) {}
  }

  // Indirection so we don't hard-depend on go_router here.
  static void Function(BuildContext, String)? router;
  static void _go(BuildContext ctx, String route) {
    router?.call(ctx, route);
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    // Local notifications plugin is not initialized on web.
    if (kIsWeb) return;
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> _saveToken(String token) async {
    final uid = currentAuthUser?.id;
    if (uid == null) {
      debugPrint('PushService: cannot save token, no signed-in user.');
      return;
    }
    final platform = kIsWeb
        ? 'web'
        : (defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : (defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : 'other'));
    try {
      // `token` is the primary key, so onConflict on it keeps one row/device
      // and re-points it to the current user if they switch accounts.
      await supabase.from('device_tokens').upsert({
        'token': token,
        'user_id': uid,
        'platform': platform,
      }, onConflict: 'token');
      debugPrint('PushService: token saved for $uid ($platform).');
      lastError = null;
    } catch (e) {
      lastError = 'Saving token failed: $e';
      debugPrint('PushService: $lastError');
    }
  }

  /// Remove this device's token on sign-out.
  static Future<void> clearToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await supabase.from('device_tokens').delete().eq('token', token);
      }
    } catch (_) {}
  }
}
