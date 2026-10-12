import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/voting_charter.dart';

void main() {
  late Map<String, dynamic> translations;

  setUpAll(() {
    translations = jsonDecode(File('assets/i18n/translations.json').readAsStringSync()) as Map<String, dynamic>;
  });

  Map<String, String>? rowOf(String key) {
    final r = translations[key];
    if (r is! Map) return null;
    return {'en': (r['en'] ?? '').toString(), 'hi': (r['hi'] ?? '').toString()};
  }

  test('six program steps in member journey order', () {
    expect(electionProgramSteps.length, 6);
    expect(electionProgramSteps.first.stepKey, 'votingCharter.program.s1.title');
    expect(electionProgramSteps.last.pointKeys, ['votingCharter.docs.p1', 'votingCharter.docs.p3', 'votingCharter.committee.p4']);
    expect(electionProgramSteps.expand((s) => s.pointKeys).length, 18);
  });

  test('every charter key exists in both languages in the shared translations', () {
    for (final key in allVotingCharterKeys()) {
      final row = rowOf(key);
      expect(row, isNotNull, reason: key);
      expect(row!['en'], isNotEmpty, reason: '$key en');
      expect(row['hi'], isNotEmpty, reason: '$key hi');
    }
    for (final s in votingCharterSections) {
      expect(rowOf(s.headingKey), isNotNull, reason: s.headingKey);
    }
  });

  test('charterTextFromRow falls back like the web charterText', () {
    expect(charterTextFromRow(null, 'k', hi: true), 'k');
    expect(charterTextFromRow({'en': 'E', 'hi': 'H'}, 'k', hi: true), 'H');
    expect(charterTextFromRow({'en': 'E', 'hi': ' '}, 'k', hi: true), 'E');
    expect(charterTextFromRow({'en': '', 'hi': 'H'}, 'k', hi: false), 'H');
    expect(charterTextFromRow({'en': '', 'hi': ''}, 'k', hi: false), 'k');
    expect(charterTextFromRow(rowOf(votingCharterTitleKey), votingCharterTitleKey, hi: false),
        'Election of the 7-member Management Committee');
  });

  test('pdf filename slug', () {
    final now = DateTime.utc(2026, 10, 12);
    expect(votingCharterPdfFilename('Green Valley CHS Ltd.', hi: false, now: now),
        'voting-charter-en-green-valley-chs-ltd-2026-10-12.pdf');
    expect(votingCharterPdfFilename(null, hi: true, now: now), 'voting-charter-hi-society-2026-10-12.pdf');
    expect(votingCharterPdfFilename('हरित सोसायटी', hi: true, now: now), 'voting-charter-hi-society-2026-10-12.pdf');
    final long = votingCharterPdfFilename('a' * 60, hi: false, now: now);
    expect(long, 'voting-charter-en-${'a' * 40}-2026-10-12.pdf');
  });
}
