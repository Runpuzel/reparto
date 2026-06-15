import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts any thrown error into a short, user-understandable message.
///
/// Use everywhere instead of `e.toString()` so users never see raw stack
/// traces, exception class names or SQL/Postgres jargon.
class AppError {
  static String friendly(Object? error) {
    if (error == null) return 'Something went wrong. Please try again.';

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
      return 'Your password does not meet the requirements.';
    }
    if (m.contains('network') || m.contains('socket')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Sign-in failed. Please try again.';
  }

  static String _postgrest(PostgrestException e) {
    final msg = e.message;
    // Surface custom RAISE EXCEPTION messages from our RPCs (they are written
    // to be human readable, e.g. "Delivery address is required").
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
    // If the message looks like a clean sentence, show it; else generic.
    if (_looksHumanReadable(cleaned)) return cleaned;
    return 'Something went wrong. Please try again.';
  }

  static String _fromRawString(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection closed') ||
        lower.contains('clientexception')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }
    if (lower.contains('not verified') || lower.contains('payment')) {
      return _stripPgPrefix(raw);
    }

    final cleaned = _stripPgPrefix(raw);
    if (_looksHumanReadable(cleaned) && cleaned.length < 140) return cleaned;
    return 'Something went wrong. Please try again.';
  }

  /// Removes common prefixes like "Exception: ", "PostgrestException(message: ".
  static String _stripPgPrefix(String s) {
    var out = s.trim();
    out = out.replaceFirst(RegExp(r'^Exception:\s*'), '');
    // "PostgrestException(message: X, code: ...)" -> X
    final m = RegExp(r'message:\s*(.+?)(?:,\s*code:|,\s*details:|\))')
        .firstMatch(out);
    if (m != null) out = m.group(1)!.trim();
    // Drop trailing "(SQLSTATE ...)" style noise.
    out = out.replaceFirst(RegExp(r'\s*\(SQLSTATE.*\)$'), '');
    return out.trim();
  }

  static bool _looksHumanReadable(String s) {
    if (s.isEmpty) return false;
    // Avoid showing things that still look technical.
    final bad = ['null', 'exception', 'stacktrace', '#0', 'dart:', 'package:'];
    final lower = s.toLowerCase();
    if (bad.any(lower.contains)) return false;
    return true;
  }
}
