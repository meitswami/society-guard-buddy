import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/js_compat.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/split_math.dart';

/// Port of `src/lib/equalSplitAmounts.test.ts` (+ extra edge cases).
void main() {
  group('computeEqualSplitAmounts', () {
    test('sums exactly to total when equal split does not divide evenly', () {
      final flats = List.generate(29, (i) => '${100 + i}');
      final rows = computeEqualSplitAmounts(150000, flats);
      final sum = round2(rows.fold<double>(0, (s, r) => s + r.amount));
      expect(sum, 150000);
      expect(rows[0].amount, 5172.41);
      expect(rows[28].amount, 5172.52);
    });

    test('returns equal shares when total divides evenly', () {
      final flats = List.generate(29, (i) => '$i');
      final rows = computeEqualSplitAmounts(9251, flats);
      final sum = round2(rows.fold<double>(0, (s, r) => s + r.amount));
      expect(sum, 9251);
      expect(rows.every((r) => r.amount == 319), isTrue);
    });

    test('empty flat list gives no rows', () {
      expect(computeEqualSplitAmounts(1000, const []), isEmpty);
    });

    test('keeps flat order and puts the remainder on the last row', () {
      final rows = computeEqualSplitAmounts(100, const ['A', 'B', 'C']);
      expect(rows.map((r) => r.flatNumber).toList(), ['A', 'B', 'C']);
      expect(rows.map((r) => r.amount).toList(), [33.33, 33.33, 33.34]);
    });

    test('single flat gets the whole total', () {
      final rows = computeEqualSplitAmounts(1234.56, const ['101']);
      expect(rows.single.amount, 1234.56);
    });
  });

  group('adjustSplitRemainder', () {
    test('fixes a small rounding gap on the last amount', () {
      final adjusted = adjustSplitRemainder(150000, List.filled(29, 5172.41));
      expect(round2(adjusted.fold<double>(0, (a, b) => a + b)), 150000);
      expect(adjusted[28], 5172.52);
    });

    test('returns the same amounts when they already sum to total', () {
      final amounts = [10.0, 20.0, 30.0];
      expect(adjustSplitRemainder(60, amounts), same(amounts));
    });

    test('handles an over-allocation by reducing the last line', () {
      expect(adjustSplitRemainder(100, [33.34, 33.34, 33.34]), [33.34, 33.34, 33.32]);
    });

    test('empty input stays empty', () {
      expect(adjustSplitRemainder(100, const []), isEmpty);
    });

    test('rescaling splits on an edited total (ExpenseSplitter.saveExpenseEdit)', () {
      // 1000 split 3 ways → edited to 1250.
      final old = computeEqualSplitAmounts(1000, const ['1', '2', '3']).map((r) => r.amount).toList();
      const ratio = 1250 / 1000;
      final scaled = adjustSplitRemainder(1250, [for (final a in old) round2(a * ratio)]);
      expect(round2(scaled.fold<double>(0, (a, b) => a + b)), 1250);
      expect(scaled, [416.66, 416.66, 416.68]);
    });
  });
}
