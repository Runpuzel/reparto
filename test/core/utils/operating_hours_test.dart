import 'package:flutter_test/flutter_test.dart';
import 'package:reparto/core/utils/operating_hours.dart';

void main() {
  group('OperatingHours', () {
    test('opens at the configured opening time', () {
      final open = OperatingHours.isOpenAt(
        now: DateTime.utc(2026, 7, 13, 8),
        openingTime: '08:00:00',
        closingTime: '20:00:00',
      );

      expect(open, isTrue);
    });

    test('closes at the configured closing time', () {
      final open = OperatingHours.isOpenAt(
        now: DateTime.utc(2026, 7, 13, 20),
        openingTime: '08:00:00',
        closingTime: '20:00:00',
      );

      expect(open, isFalse);
    });

    test('rejects missing, invalid, and reversed hours', () {
      expect(
        OperatingHours.isOpenAt(
          now: DateTime.utc(2026, 7, 13, 12),
          openingTime: null,
          closingTime: '20:00:00',
        ),
        isFalse,
      );
      expect(
        OperatingHours.isOpenAt(
          now: DateTime.utc(2026, 7, 13, 12),
          openingTime: '20:00:00',
          closingTime: '08:00:00',
        ),
        isFalse,
      );
    });

    test('formats database times for display', () {
      expect(OperatingHours.display('08:05:00'), '8:05 AM');
      expect(OperatingHours.display('20:30:00'), '8:30 PM');
      expect(OperatingHours.display(null), '--:--');
    });
  });
}
