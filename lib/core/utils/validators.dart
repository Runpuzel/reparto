/// Form field validators shared across auth screens.
class Validators {
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email';
  }

  static String? required(String? v, [String field = 'This field']) {
    return (v == null || v.trim().isEmpty) ? '$field is required' : null;
  }

  /// At least 8 chars, one number, one uppercase letter (per spec).
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least one number';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include one uppercase letter';
    return null;
  }

  /// Ghana phone number: must start with 0 and be exactly 10 digits.
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (!digits.startsWith('0')) return 'Number must start with 0';
    if (digits.length != 10) return 'Enter a 10-digit number (e.g. 0208223626)';
    return null;
  }

  /// Ghana mobile money number: must start with 0 and be exactly 10 digits.
  static String? momo(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile money number is required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (!digits.startsWith('0')) return 'Number must start with 0';
    if (digits.length != 10) return 'Enter a 10-digit number (e.g. 0208223626)';
    return null;
  }
}
