import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load config. We use `env.txt` (no leading dot) because web hosts like
  // Netlify don't serve dotfiles such as `.env`. Fall back to `.env` for
  // local dev, then to --dart-define if neither is present.
  try {
    await dotenv.load(fileName: 'env.txt');
  } catch (_) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {/* fall back to --dart-define */}
  }

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // Optional push notifications (requires Firebase config files and
    // ENABLE_PUSH=true in .env).
    if (Env.pushEnabled) {
      try {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: Env.firebaseWebApiKey,
              appId: Env.firebaseWebAppId,
              messagingSenderId: Env.firebaseMessagingSenderId,
              projectId: Env.firebaseProjectId,
              authDomain: Env.firebaseAuthDomain,
              storageBucket: Env.firebaseStorageBucket,
            ),
          );
          PushService.webVapidKey = Env.firebaseWebVapidKey;
        } else {
          await Firebase.initializeApp();
        }
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
        // Let push taps navigate via GoRouter.
        PushService.router = (ctx, route) => ctx.push(route);
        PushService.firebaseReady = true;
        debugPrint('Firebase initialized — push enabled.');
      } catch (e) {
        // Most common cause: missing google-services.json / GoogleService-Info.
        debugPrint('Firebase init failed (push disabled): $e');
      }
    } else {
      debugPrint('Push disabled: set ENABLE_PUSH=true in .env to enable.');
    }

    runApp(const ProviderScope(child: UjustBuyApp()));
  } else {
    runApp(const ProviderScope(child: _MisconfiguredApp()));
  }
}

class UjustBuyApp extends ConsumerWidget {
  const UjustBuyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// Shown when SUPABASE_URL / ANON_KEY are not provided.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_suggest, size: 64, color: Colors.orange),
                SizedBox(height: 16),
                Text('UjustBUY is not configured',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Add SUPABASE_URL and SUPABASE_ANON_KEY to your env.txt file '
                      '(copy from .env.example) and rebuild the app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
