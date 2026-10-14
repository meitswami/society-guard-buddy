// Port of src/lib/maintenanceReceiptNumber.test.ts
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/maintenance_receipt_number.dart';

void main() {
  group('maintenance receipt serial format', () {
    test('pads sequential numbers to 6 digits', () {
      expect(formatMaintenanceReceiptNumber(1), 'MR-000001');
      expect(formatMaintenanceReceiptNumber(186), 'MR-000186');
      expect(formatMaintenanceReceiptNumber(187), 'MR-000187');
    });

    test('file-name token keeps word chars, dots and dashes', () {
      expect(safeReceiptFileToken('MR-000187'), 'MR-000187');
      expect(safeReceiptFileToken('MR 1/2'), 'MR_1_2');
    });
  });
}
