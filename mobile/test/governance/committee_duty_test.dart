import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/committee_logic.dart';

void main() {
  group('committeeDuty', () {
    test('parseSupervisorNames splits on commas and semicolons', () {
      expect(parseSupervisorNames(' Ram , Shyam;;Sita ;'), ['Ram', 'Shyam', 'Sita']);
      expect(parseSupervisorNames('  '), isEmpty);
    });

    test('formatSupervisorNames joins non-empty names', () {
      expect(formatSupervisorNames(['Ram', '', 'Sita']), 'Ram, Sita');
    });

    test('dutiesPeriodLabel', () {
      expect(dutiesPeriodLabel(periodFrom: '2026-04-01', periodTo: '2027-03-31'), '2026-04-01 → 2027-03-31');
      expect(dutiesPeriodLabel(periodFrom: '2026-04-01T00:00:00Z'), '2026-04-01 → Ongoing');
      expect(dutiesPeriodLabel(periodFrom: '2026-04-01', hi: true), '2026-04-01 → जारी');
    });

    test('presets match the web list', () {
      expect(standardDutyPresets.length, 10);
      expect(standardDutyPresets.first, 'Maintenance & Repairs');
      expect(standardDutyPresets.last, 'Event Coordination');
    });
  });

  group('validateDutyRows', () {
    test('requires a start date and a valid range', () {
      expect(validateDutyRows(periodFrom: '', periodTo: '', forms: []).error?.$1, 'Period start date (From) is required');
      expect(
        validateDutyRows(periodFrom: '2026-04-01', periodTo: '2026-03-01', forms: []).error?.$1,
        'Period end date must be on or after start date',
      );
    });

    test('requires at least one labelled duty with supervisors', () {
      expect(
        validateDutyRows(periodFrom: '2026-04-01', periodTo: '', forms: [DutyFormRow()]).error?.$1,
        'Add at least one duty with a label',
      );
      expect(
        validateDutyRows(periodFrom: '2026-04-01', periodTo: '', forms: [DutyFormRow(dutyLabel: 'Parking')]).error?.$1,
        'Supervisor name is required for "Parking"',
      );
    });

    test('keeps original indexes as sort order and skips blank rows', () {
      final res = validateDutyRows(
        periodFrom: '2026-04-01',
        periodTo: '',
        forms: [
          DutyFormRow(dutyLabel: ' ', supervisorNames: 'x'),
          DutyFormRow(dutyLabel: ' Parking ', supervisorNames: 'Ram, Sita'),
        ],
      );
      expect(res.error, isNull);
      expect(res.rows.single.dutyLabel, 'Parking');
      expect(res.rows.single.supervisors, ['Ram', 'Sita']);
      expect(res.rows.single.sortOrder, 1);
    });
  });
}
