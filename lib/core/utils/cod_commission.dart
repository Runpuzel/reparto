/// Exact client-side preview of the server's Cash on Delivery fee calculation.
class CodCommission {
  const CodCommission._();

  static int requiredFeePesewas({
    required int grossPesewas,
    required num ratePercent,
    int discountPesewas = 0,
  }) {
    if (grossPesewas < 0) {
      throw ArgumentError.value(grossPesewas, 'grossPesewas');
    }
    if (ratePercent < 0 || ratePercent > 100) {
      throw ArgumentError.value(ratePercent, 'ratePercent');
    }
    if (discountPesewas < 0) {
      throw ArgumentError.value(discountPesewas, 'discountPesewas');
    }

    final normalFee = (grossPesewas * ratePercent / 100).round();
    final discountedFee = normalFee - discountPesewas;
    return discountedFee > 0 ? discountedFee : 0;
  }

  static bool hasSufficientBalance({
    required int availablePesewas,
    required int requiredFeePesewas,
  }) =>
      availablePesewas >= requiredFeePesewas;
}
