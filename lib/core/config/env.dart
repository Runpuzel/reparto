import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised access to environment configuration loaded from `env.txt` or `.env`.
class Env {
  static String _get(String key) =>
      dotenv.maybeGet(key) ?? String.fromEnvironment(key);

  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');

  /// Web OAuth client id for Google sign-in (used by google_sign_in on web).
  static String get googleWebClientId => _get('GOOGLE_WEB_CLIENT_ID');

  /// Whether to attempt Firebase init for push notifications.
  static bool get pushEnabled => _get('ENABLE_PUSH').toLowerCase() == 'true';

  /// Whether Paystack checkout is enabled (else fall back to free checkout).
  static bool get paymentsEnabled =>
      _get('ENABLE_PAYMENTS').toLowerCase() == 'true';

  /// Paystack Secret Key (Note: In production, secret keys should ideally be 
  /// kept in the backend/Supabase secrets, not the frontend).
  static String get paystackSecretKey => _get('PAYSTACK_SECRET_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
          !supabaseUrl.contains('YOUR-PROJECT') &&
          supabaseAnonKey.isNotEmpty &&
          !supabaseAnonKey.contains('YOUR-ANON-KEY');
}
