import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/superadmin/logic/totp.dart';

/// Vectors generated with the web's own `otplib@13.4.0` (`generateSync`, `verifySync`
/// with `epochTolerance: 30`, `generateURI`) plus RFC 6238 Appendix B (SHA-1).
void main() {
  const rfcSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // "12345678901234567890"
  const s2 = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';

  group('Base32', () {
    test('round-trips and matches RFC 4648', () {
      expect(Base32.encode('12345678901234567890'.codeUnits), rfcSecret);
      expect(String.fromCharCodes(Base32.decode(rfcSecret)!), '12345678901234567890');
      expect(Base32.encode('foobar'.codeUnits), 'MZXW6YTBOI');
      expect(String.fromCharCodes(Base32.decode('MZXW6YTBOI======')!), 'foobar');
    });

    test('decode upper-cases like otplib and rejects bad characters', () {
      expect(Base32.decode(s2.toLowerCase()), Base32.decode(s2));
      expect(Base32.decode('ABC1'), isNull);
      expect(Base32.decode('AB CD'), isNull);
    });
  });

  group('generateTotpCode (otplib generateSync)', () {
    test('RFC 6238 SHA-1 vectors (6 digits)', () {
      const expected = {
        59: '287082',
        1111111109: '081804',
        1111111111: '050471',
        1234567890: '005924',
        2000000000: '279037',
        20000000000: '353130',
      };
      expected.forEach((t, code) => expect(generateTotpCode(rfcSecret, epochSeconds: t), code, reason: 't=$t'));
    });

    test('otplib vectors for a 20-byte secret', () {
      const expected = {
        0: '702218',
        29: '702218',
        30: '503347',
        1700000000: '406058',
        1760000000: '325812',
        1760000015: '793635',
        1760000029: '793635',
        1760000030: '793635',
      };
      expected.forEach((t, code) => expect(generateTotpCode(s2, epochSeconds: t), code, reason: 't=$t'));
      expect(generateTotpCode(s2.toLowerCase(), epochSeconds: 1760000000), '325812');
    });

    test('secrets shorter than 16 bytes are rejected (otplib SecretTooShortError)', () {
      expect(generateTotpCode('JBSWY3DPEHPK3PXP', epochSeconds: 0), isNull);
    });
  });

  group('verifyTotpCode (epochTolerance 30)', () {
    const base = 1760000010; // exactly on a step boundary
    String codeAt(int t) => generateTotpCode(s2, epochSeconds: t)!;

    test('accepts the previous, current and next step only', () {
      const valid = {
        -90: false,
        -61: false,
        -60: false,
        -31: false,
        -30: true,
        -1: true,
        0: true,
        29: true,
        30: true,
        31: true,
        59: true,
        60: false,
        61: false,
        90: false,
      };
      valid.forEach((off, ok) {
        expect(verifyTotpCode(s2, codeAt(base + off), epochSeconds: base), ok, reason: 'offset $off');
      });
    });

    test('late in a window', () {
      const base2 = 1760000029;
      const valid = {-60: false, -59: false, -31: true, -30: true, 0: true, 1: true, 30: true, 31: true, 60: false, 61: false};
      valid.forEach((off, ok) {
        expect(verifyTotpCode(s2, codeAt(base2 + off), epochSeconds: base2), ok, reason: 'offset $off');
      });
    });

    test('token format: whitespace stripped, exactly 6 digits', () {
      expect(verifyTotpCode(s2, '793 635', epochSeconds: 1760000015), isTrue);
      expect(verifyTotpCode(s2, ' 793635 ', epochSeconds: 1760000015), isTrue);
      expect(verifyTotpCode(s2, '79363', epochSeconds: 1760000015), isFalse);
      expect(verifyTotpCode(s2, '7936355', epochSeconds: 1760000015), isFalse);
      expect(verifyTotpCode(s2, '79363a', epochSeconds: 1760000015), isFalse);
      expect(verifyTotpCode('not base32!', '793635', epochSeconds: 1760000015), isFalse);
      expect(verifyTotpCode('JBSWY3DPEHPK3PXP', '123456'), isFalse);
    });
  });

  group('secret and URI', () {
    test('generateTotpSecret: 32 Base32 chars, 20 bytes, verifiable', () {
      final secret = generateTotpSecret(Random(42));
      expect(secret.length, 32);
      expect(RegExp(r'^[A-Z2-7]{32}$').hasMatch(secret), isTrue);
      expect(Base32.decode(secret)!.length, 20);
      final code = generateTotpCode(secret, epochSeconds: 1760000000)!;
      expect(verifyTotpCode(secret, code, epochSeconds: 1760000000), isTrue);
    });

    test('buildTotpKeyUri matches otplib generateURI', () {
      expect(
        buildTotpKeyUri(s2, 'SUPERADMIN'),
        'otpauth://totp/Society%20Guard%20Buddy:SUPERADMIN?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=Society%20Guard%20Buddy',
      );
      expect(
        buildTotpKeyUri(s2, "A B!*'()~_.-@#&=?/+é"),
        "otpauth://totp/Society%20Guard%20Buddy:A%20B!*'()~_.-%40%23%26%3D%3F%2F%2B%C3%A9?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=Society%20Guard%20Buddy",
      );
    });

    test('QR image URL like the web', () {
      expect(
        totpQrImageUrl('otpauth://totp/x?secret=A', size: 180),
        'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=otpauth%3A%2F%2Ftotp%2Fx%3Fsecret%3DA',
      );
    });

    test('seconds remaining in the window', () {
      expect(totpSecondsRemaining(epochSeconds: 1760000010), 30);
      expect(totpSecondsRemaining(epochSeconds: 1760000039), 1);
    });
  });
}
