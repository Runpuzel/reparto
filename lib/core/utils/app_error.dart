import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts any thrown error into a short, user-understandable message.
///
/// Use everywhere instead of `e.toString()` so users never see raw stack
/// traces, exception class names or SQL/Postgres jargon.
class AppError {
  static const String offlineMessage =
      'You are offline. Please check your internet connection and try again.';

  static const String genericMessage =
      'Something went wrong. Please try again later.';

  static String friendly(Object? error) {
    if (error == null) return genericMessage;

    if (isOffline(error)) return offlineMessage;

    // --- Supabase / Postgres -------------------------------------------------
    if (error is AuthException) {
      return _auth(error.message);
    }
    if (error is PostgrestException) {
      return _postgrest(error);
    }
    if (error is StorageException) {
      return 'We could not upload your file. Please try again.';
    }

    final raw = error.toString();
    return _fromRawString(raw);
  }

  static bool isOffline(Object? error) {
    if (error == null) return false;
    final raw = error.toString().toLowerCase();

    // Common Flutter/Dart/Supabase offline indicators
    return raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection closed') ||
        raw.contains('clientexception') ||
        raw.contains('connection reset') ||
        raw.contains('software caused connection abort') ||
        raw.contains('connection refused') ||
        raw.contains('handshake_exception') ||
        (raw.contains('network') &&
            (raw.contains('error') ||
                raw.contains('fail') ||
                raw.contains('unavailable') ||
                raw.contains('issue'))) ||
        // Supabase specific offline states
        raw.contains('postgresterror(message: , code: 0') ||
        raw.contains('null check operator used on a null value') &&
            raw.contains('auth');
  }

  static String _auth(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (m.contains('password')) {
      return 'Your password does not meet the security requirements.';
    }
    if (m.contains('user not found')) {
      return 'No account found with this email.';
    }
    if (m.contains('passed nonce') && m.contains('id_token')) {
      return 'Google sign-in nonce validation failed. Enable Skip nonce check in the Supabase Google provider settings.';
    }
    if (m.contains('unacceptable audience') ||
        m.contains('invalid audience') ||
        (m.contains('audience') && m.contains('id_token'))) {
      return 'Google sign-in does not match the client IDs configured in Supabase.';
    }
    if (m.contains('provider is not enabled') ||
        m.contains('unsupported provider')) {
      return 'Google sign-in is not enabled in Supabase.';
    }
    if (m.contains('deleted_client')) {
      return 'This Google sign-in client was deleted. Update the app and Supabase to use the active client.';
    }
    if (m.contains('invalid_client')) {
      return 'The Google Web client ID or secret configured in Supabase is invalid.';
    }
    if (m.contains('missing id token') ||
        m.contains('invalid id token') ||
        m.contains('bad id token')) {
      return 'Google did not provide a valid sign-in token. Please try again.';
    }
    if (m.contains('authorized javascript origins') ||
        m.contains('not configured for this web address') ||
        m.contains('unregistered_origin') ||
        m.contains('origin is not allowed') ||
        m.contains('given origin')) {
      return 'Google sign-in is not configured for this web address. Add this site origin in Google Cloud Console.';
    }
    return 'Sign-in failed. Please try again.';
  }

  static String _postgrest(PostgrestException e) {
    final msg = e.message;
    // Surface custom RAISE EXCEPTION messages from our RPCs
    final cleaned = _stripPgPrefix(msg);

    final lower = cleaned.toLowerCase();
    if (lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        e.code == '42501') {
      return 'You do not have permission to do that.';
    }
    if (lower.contains('duplicate key') || e.code == '23505') {
      return 'That item already exists.';
    }
    if (lower.contains('foreign key') || e.code == '23503') {
      return 'This action references something that no longer exists.';
    }
    if (lower.contains('insufficient stock')) {
      return cleaned; // already friendly from our RPC
    }

    // Check if it's a code 0 (usually network/offline)
    if (e.code == '0' || e.code == null) return offlineMessage;

    // If the message looks like a clean sentence, show it; else generic.
    if (_looksHumanReadable(cleaned)) return cleaned;
    return genericMessage;
  }

  static String _fromRawString(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }
    if (lower.contains('unregistered_origin') ||
        lower.contains('origin is not allowed') ||
        lower.contains('given origin') ||
        lower.contains('authorized javascript origins') ||
        lower.contains('not a registered origin')) {
      return 'Google sign-in is not configured for this web address. Add this site origin in Google Cloud Console.';
    }
    if (lower.contains('not verified') || lower.contains('payment')) {
      return _stripPgPrefix(raw);
    }

    final cleaned = _stripPgPrefix(raw);
    if (_looksHumanReadable(cleaned) && cleaned.length < 140) return cleaned;
    return genericMessage;
  }

  /// Removes common prefixes like "Exception: ", "PostgrestException(message: ".
  static String _stripPgPrefix(String s) {
    var out = s.trim();
    out = out.replaceFirst(RegExp(r'^Exception:\s*'), '');
    // "PostgrestException(message: X, code: ...)" -> X
    final m = RegExp(
      r'message:\s*(.+?)(?:,\s*code:|,\s*details:|\))',
    ).firstMatch(out);
    if (m != null) out = m.group(1)!.trim();
    // Drop trailing "(SQLSTATE ...)" style noise.
    out = out.replaceFirst(RegExp(r'\s*\(SQLSTATE.*\)$'), '');
    return out.trim();
  }

  static bool _looksHumanReadable(String s) {
    if (s.isEmpty) return false;
    // Avoid showing things that still look technical.
    final bad = [
      'null',
      'exception',
      'stacktrace',
      '#0',
      'dart:',
      'package:',
      'postgresql',
      'supabase',
      'flutter',
    ];
    final lower = s.toLowerCase();
    if (bad.any(lower.contains)) return false;
    // Sentence should start with a letter and not look like a class name
    if (!RegExp(r'^[a-zA-Z]').hasMatch(s)) return false;
    return true;
  }
}
