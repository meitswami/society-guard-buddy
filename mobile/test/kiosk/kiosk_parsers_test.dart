// Port of web `src/lib/kiosk/kioskParsers.test.ts` (every case).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_parsers.dart';

void main() {
  group('parsePhone', () {
    test('reads digit runs and Devanagari numerals', () {
      expect(parsePhone('98765 43210'), '9876543210');
      expect(parsePhone('मेरा नंबर ९८७६५ ४३२१० है'), '9876543210');
    });

    test('reads spoken digit words in Hindi, Hinglish and English', () {
      expect(parsePhone('नौ आठ सात छह पांच चार तीन दो एक शून्य'), '9876543210');
      expect(parsePhone('nau aath saat chhe paanch char teen do ek zero'), '9876543210');
      expect(parsePhone('nine eight double seven six five four three two one'), '9877654321');
    });

    test('strips +91 / 0 prefixes and rejects non-mobile numbers', () {
      expect(parsePhone('+91 98765 43210'), '9876543210');
      expect(parsePhone('0 9876543210'), '9876543210');
      expect(parsePhone('12345'), isNull);
      expect(parsePhone('1234567890'), isNull);
    });
  });

  group('extractDigits', () {
    test('handles triple', () {
      expect(extractDigits('triple nine'), '999');
    });
  });

  group('parseSpokenNumber', () {
    test('composes hundreds', () {
      expect(parseSpokenNumber('छह सौ चार'), '604');
      expect(parseSpokenNumber('six hundred four'), '604');
      expect(parseSpokenNumber('chhe so char'), '604');
    });

    test('concatenates plain digits and ignores filler "so"', () {
      expect(parseSpokenNumber('six zero four'), '604');
      expect(parseSpokenNumber('so 604'), '604');
    });
  });

  group('parseFlat', () {
    const flats = ['A-101', 'A-604', 'B-604', 'C-1203', '702'];

    test('matches the society flat list', () {
      expect(parseFlat('A 604', flats).flat, 'A-604');
      expect(parseFlat('ए विंग छह सौ चार', flats).flat, 'A-604');
      expect(parseFlat('flat number C 1203', flats).flat, 'C-1203');
      expect(parseFlat('मुझे फ्लैट 702 में जाना है', flats).flat, '702');
      expect(parseFlat('1203', flats).flat, 'C-1203');
    });

    test('refuses ambiguous or unknown flats', () {
      expect(parseFlat('604', flats).flat, isNull);
      expect(parseFlat('999', flats).flat, isNull);
    });

    test('accepts what was heard when no flat list is loaded', () {
      expect(parseFlat('B 204', const []).flat, 'B-204');
      expect(parseFlat('फ्लैट 604 के लिए', const []).flat, '604');
    });
  });

  group('parseYesNo', () {
    test('understands Hindi, Hinglish and English', () {
      expect(parseYesNo('हाँ सही है'), isTrue);
      expect(parseYesNo('haan ji'), isTrue);
      expect(parseYesNo('yes correct'), isTrue);
      expect(parseYesNo('नहीं'), isFalse);
      expect(parseYesNo('ठीक नहीं है'), isFalse);
      expect(parseYesNo('nahi galat hai'), isFalse);
      expect(parseYesNo('pata nahi kya'), isFalse);
      expect(parseYesNo('राहुल'), isNull);
    });
  });

  group('parseName', () {
    test('drops filler words', () {
      expect(parseName('मेरा नाम राहुल शर्मा है'), 'राहुल शर्मा');
      expect(parseName('mera naam rahul sharma hai'), 'Rahul Sharma');
      expect(parseName('my name is Priya'), 'Priya');
      expect(parseName('मेरा नाम है'), isNull);
    });
  });

  group('transliterateToLatin', () {
    test('romanises common Hindi names', () {
      expect(transliterateToLatin('राहुल शर्मा'), 'Rahul Sharma');
      expect(transliterateToLatin('कमला'), 'Kamla');
      expect(transliterateToLatin('अमरनाथ'), 'Amarnath');
      expect(transliterateToLatin('मनमोहन सिंह'), 'Manmohan Singh');
      expect(transliterateToLatin('संजय'), 'Sanjay');
      expect(transliterateToLatin('प्रिया'), 'Priya');
      expect(transliterateToLatin('अर्जुन'), 'Arjun');
      expect(transliterateToLatin('गौरव'), 'Gaurav');
      expect(transliterateToLatin('राम'), 'Ram');
      expect(transliterateToLatin('Rahul'), 'Rahul');
    });
  });

  group('parseVehicleNumber', () {
    test('reads Latin and Devanagari letter names', () {
      expect(parseVehicleNumber('MH 02 AB 1234'), 'MH02AB1234');
      expect(parseVehicleNumber('एमएच 12 एबी 1234'), 'MH12AB1234');
      expect(parseVehicleNumber('डीएल 3 सी 4567'), 'DL3C4567');
      expect(parseVehicleNumber('22 BH 1234 AA'), '22BH1234AA');
      expect(parseVehicleNumber('nahi'), isNull);
    });
  });

  group('parsePurpose', () {
    test('maps keywords and delivery brands', () {
      expect(parsePurpose('amazon ka parcel hai'), const KioskPurposeMatch(KioskPurpose.delivery, company: 'Amazon'));
      expect(parsePurpose('स्विगी से खाना'), const KioskPurposeMatch(KioskPurpose.delivery, company: 'Swiggy'));
      expect(parsePurpose('प्लंबर का काम है'), const KioskPurposeMatch(KioskPurpose.maintenance));
      expect(parsePurpose('dost se milne aaya hoon')?.purpose, KioskPurpose.guest);
      expect(parsePurpose('मिलने आया हूँ'), const KioskPurposeMatch(KioskPurpose.visit));
      expect(parsePurpose('kuch nahi'), isNull);
    });
  });

  group('parseEditField', () {
    test('finds the detail to correct', () {
      expect(parseEditField('naam galat hai'), KioskEditField.name);
      expect(parseEditField('गाड़ी नंबर बदलना है'), KioskEditField.vehicle);
      expect(parseEditField('mobile number'), KioskEditField.phone);
      expect(parseEditField('फ्लैट'), KioskEditField.flat);
      expect(parseEditField('kuch nahi'), isNull);
    });
  });
}
