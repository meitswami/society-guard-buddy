import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/document_logic.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 10);

  test('categories match the web order and labels', () {
    expect(SocietyDocCategory.values.map((c) => c.value),
        ['bylaws', 'minutes', 'notices', 'reports', 'forms', 'other']);
    expect(SocietyDocCategory.notices.labelEn, 'Notices & circulars');
    expect(SocietyDocCategory.parse('unknown'), SocietyDocCategory.other);
  });

  test('reveal window', () {
    final until =
        now.add(const Duration(milliseconds: 14200)).toIso8601String();
    expect(isRevealActive(until, now), isTrue);
    expect(revealSecondsLeft(until, now), 15, reason: 'ceil like Math.ceil');
    final past = now.subtract(const Duration(seconds: 1)).toIso8601String();
    expect(isRevealActive(past, now), isFalse);
    expect(revealSecondsLeft(past, now), 0);
    expect(isRevealActive(null, now), isFalse);
    expect(revealSecondsLeft('', now), 0);
    expect(revealDurations.map((d) => d.seconds), [15, 30, 60]);
  });

  test('image detection', () {
    expect(isImageDoc(mimeType: 'image/png', fileName: 'x.bin'), isTrue);
    expect(isImageDoc(fileName: 'photo.JPEG'), isTrue);
    expect(isImageDoc(mimeType: 'application/pdf', fileName: 'a.pdf'), isFalse);
    expect(viewerIsPdf(mimeType: null, url: 'https://x/y/Doc.PDF?token=1'),
        isTrue);
    expect(viewerIsImage(mimeType: null, url: 'https://x/a.webp?t=1'), isTrue);
    expect(viewerIsImage(mimeType: 'application/pdf', url: 'https://x/a.png'),
        isFalse);
  });

  test('upload validation', () {
    expect(
        validateSocietyDocUpload(
                title: ' ', mimeType: 'application/pdf', size: 1)
            ?.$1,
        'Enter a document title');
    expect(
        validateSocietyDocUpload(
                title: 'Bylaws', mimeType: 'image/gif', size: 1)
            ?.$1,
        'Only PDF and image files (PNG, JPEG, WebP) are allowed');
    expect(
        validateSocietyDocUpload(
                title: 'Bylaws',
                mimeType: 'application/pdf',
                size: societyDocMaxBytes + 1)
            ?.$1,
        'File must be 15 MB or smaller');
    expect(
        validateSocietyDocUpload(
            title: 'Bylaws', mimeType: 'image/webp', size: societyDocMaxBytes),
        isNull);
  });

  test('storage path is society/doc/sanitized-name', () {
    expect(societyDocStoragePath('s1', 'd1', 'Bye laws (2026).pdf'),
        's1/d1/Bye_laws__2026_.pdf');
  });

  test('poll document kinds', () {
    expect(PollDocKind.values.map((k) => k.value),
        ['circular', 'letter', 'personal', 'society', 'other']);
    expect(pollDocKindLabel('personal'), 'Personal letter');
    expect(pollDocKindLabel('legacy_kind'), 'legacy_kind');
    expect(pollDocKindLabel('circular', hi: true), 'परिपत्र');
  });
}
