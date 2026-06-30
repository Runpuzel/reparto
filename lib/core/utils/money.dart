import '../constants/app_constants.dart';

/// Integer-pesewas money utilities.
///
/// All *calculation* is done in **integer pesewas** to eliminate floating-point
/// accumulation errors (GH₵ 2.00 == 200 pesewas). Storage in Supabase remains
/// `numeric(12,2)` cedis, which is already exact decimal — so this layer is the
/// safe, non-destructive way to satisfy the spec's "store/compute in pesewas"
/// rule without a risky live financial column migration.
///
/// Conversion boundary:
///   • DB / API → app:  [fromCedis] (numeric cedis → int pesewas)
///   • app → display:   [format] (int pesewas → "GH₵ 12.50")
///   • app → Paystack:  pesewas are already the subunit Paystack expects.
class Money {
  const Money._();

  /// Convert a cedis value (as stored in `numeric(12,2)`) to integer pesewas.
  /// Rounds to the nearest pesewa to absorb any binary-float noise from JSON.
  static int fromCedis(num cedis) => (cedis * 100).round();

  /// Convert integer pesewas back to a cedis double (for legacy APIs/widgets
  /// that still expect cedis). Prefer passing pesewas around instead.
  static double toCedis(int pesewas) => pesewas / 100;

  /// Parse a user-typed price string (e.g. "12.5", "12.50", "12") to pesewas.
  /// Returns null when the input isn't a valid non-negative amount.
  static int? parse(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  /// Multiply a unit price (pesewas) by a quantity — exact integer math.
  static int lineTotal(int unitPesewas, int quantity) => unitPesewas * quantity;

  /// Sum a list of pesewa amounts — exact integer math.
  static int sum(Iterable<int> pesewas) =>
      pesewas.fold<int>(0, (a, b) => a + b);

  /// Format integer pesewas for display, e.g. 1250 → "GH₵ 12.50".
  static String format(int pesewas) {
    final cedis = pesewas ~/ 100;
    final rem = (pesewas % 100).abs();
    final sign = pesewas < 0 ? '-' : '';
    final cedisStr = cedis.abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
    );
    return '$sign${AppConstants.currencySymbol}$cedisStr.${rem.toString().padLeft(2, '0')}';
  }
}
