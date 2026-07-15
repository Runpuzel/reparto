import 'package:flutter_test/flutter_test.dart';
import 'package:reparto/core/utils/cod_commission.dart';

void main() {
  group('CodCommission', () {
    test('calculates the configured percentage in pesewas', () {
      expect(
        CodCommission.requiredFeePesewas(
          grossPesewas: 10000,
          ratePercent: 5,
        ),
        500,
      );
    });

    test('zero balance cannot cover a positive marketplace fee', () {
      expect(
        CodCommission.hasSufficientBalance(
          availablePesewas: 0,
          requiredFeePesewas: 500,
        ),
        isFalse,
      );
    });

    test('deducts a valid buyer-funded platform discount', () {
      expect(
        CodCommission.requiredFeePesewas(
          grossPesewas: 10000,
          ratePercent: 5,
          discountPesewas: 200,
        ),
        300,
      );
    });

    test('never returns a negative required fee', () {
      expect(
        CodCommission.requiredFeePesewas(
          grossPesewas: 10000,
          ratePercent: 5,
          discountPesewas: 1000,
        ),
        0,
      );
    });
  });
}
