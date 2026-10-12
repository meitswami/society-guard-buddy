import { describe, expect, it } from 'vitest';
import {
  extractDigits,
  parseEditField,
  parseFlat,
  parseName,
  parsePhone,
  parsePurpose,
  parseSpokenNumber,
  parseVehicleNumber,
  parseYesNo,
  transliterateToLatin,
} from './kioskParsers';

describe('parsePhone', () => {
  it('reads digit runs and Devanagari numerals', () => {
    expect(parsePhone('98765 43210')).toBe('9876543210');
    expect(parsePhone('मेरा नंबर ९८७६५ ४३२१० है')).toBe('9876543210');
  });

  it('reads spoken digit words in Hindi, Hinglish and English', () => {
    expect(parsePhone('नौ आठ सात छह पांच चार तीन दो एक शून्य')).toBe('9876543210');
    expect(parsePhone('nau aath saat chhe paanch char teen do ek zero')).toBe('9876543210');
    expect(parsePhone('nine eight double seven six five four three two one')).toBe('9877654321');
  });

  it('strips +91 / 0 prefixes and rejects non-mobile numbers', () => {
    expect(parsePhone('+91 98765 43210')).toBe('9876543210');
    expect(parsePhone('0 9876543210')).toBe('9876543210');
    expect(parsePhone('12345')).toBeNull();
    expect(parsePhone('1234567890')).toBeNull();
  });
});

describe('extractDigits', () => {
  it('handles triple', () => {
    expect(extractDigits('triple nine')).toBe('999');
  });
});

describe('parseSpokenNumber', () => {
  it('composes hundreds', () => {
    expect(parseSpokenNumber('छह सौ चार')).toBe('604');
    expect(parseSpokenNumber('six hundred four')).toBe('604');
    expect(parseSpokenNumber('chhe so char')).toBe('604');
  });

  it('concatenates plain digits and ignores filler "so"', () => {
    expect(parseSpokenNumber('six zero four')).toBe('604');
    expect(parseSpokenNumber('so 604')).toBe('604');
  });
});

describe('parseFlat', () => {
  const flats = ['A-101', 'A-604', 'B-604', 'C-1203', '702'];

  it('matches the society flat list', () => {
    expect(parseFlat('A 604', flats).flat).toBe('A-604');
    expect(parseFlat('ए विंग छह सौ चार', flats).flat).toBe('A-604');
    expect(parseFlat('flat number C 1203', flats).flat).toBe('C-1203');
    expect(parseFlat('मुझे फ्लैट 702 में जाना है', flats).flat).toBe('702');
    expect(parseFlat('1203', flats).flat).toBe('C-1203');
  });

  it('refuses ambiguous or unknown flats', () => {
    expect(parseFlat('604', flats).flat).toBeNull();
    expect(parseFlat('999', flats).flat).toBeNull();
  });

  it('accepts what was heard when no flat list is loaded', () => {
    expect(parseFlat('B 204', []).flat).toBe('B-204');
    expect(parseFlat('फ्लैट 604 के लिए', []).flat).toBe('604');
  });
});

describe('parseYesNo', () => {
  it('understands Hindi, Hinglish and English', () => {
    expect(parseYesNo('हाँ सही है')).toBe(true);
    expect(parseYesNo('haan ji')).toBe(true);
    expect(parseYesNo('yes correct')).toBe(true);
    expect(parseYesNo('नहीं')).toBe(false);
    expect(parseYesNo('ठीक नहीं है')).toBe(false);
    expect(parseYesNo('nahi galat hai')).toBe(false);
    expect(parseYesNo('pata nahi kya')).toBe(false);
    expect(parseYesNo('राहुल')).toBeNull();
  });
});

describe('parseName', () => {
  it('drops filler words', () => {
    expect(parseName('मेरा नाम राहुल शर्मा है')).toBe('राहुल शर्मा');
    expect(parseName('mera naam rahul sharma hai')).toBe('Rahul Sharma');
    expect(parseName('my name is Priya')).toBe('Priya');
    expect(parseName('मेरा नाम है')).toBeNull();
  });
});

describe('transliterateToLatin', () => {
  it('romanises common Hindi names', () => {
    expect(transliterateToLatin('राहुल शर्मा')).toBe('Rahul Sharma');
    expect(transliterateToLatin('कमला')).toBe('Kamla');
    expect(transliterateToLatin('अमरनाथ')).toBe('Amarnath');
    expect(transliterateToLatin('मनमोहन सिंह')).toBe('Manmohan Singh');
    expect(transliterateToLatin('संजय')).toBe('Sanjay');
    expect(transliterateToLatin('प्रिया')).toBe('Priya');
    expect(transliterateToLatin('अर्जुन')).toBe('Arjun');
    expect(transliterateToLatin('गौरव')).toBe('Gaurav');
    expect(transliterateToLatin('राम')).toBe('Ram');
    expect(transliterateToLatin('Rahul')).toBe('Rahul');
  });
});

describe('parseVehicleNumber', () => {
  it('reads Latin and Devanagari letter names', () => {
    expect(parseVehicleNumber('MH 02 AB 1234')).toBe('MH02AB1234');
    expect(parseVehicleNumber('एमएच 12 एबी 1234')).toBe('MH12AB1234');
    expect(parseVehicleNumber('डीएल 3 सी 4567')).toBe('DL3C4567');
    expect(parseVehicleNumber('22 BH 1234 AA')).toBe('22BH1234AA');
    expect(parseVehicleNumber('nahi')).toBeNull();
  });
});

describe('parsePurpose', () => {
  it('maps keywords and delivery brands', () => {
    expect(parsePurpose('amazon ka parcel hai')).toEqual({ purpose: 'Delivery', company: 'Amazon' });
    expect(parsePurpose('स्विगी से खाना')).toEqual({ purpose: 'Delivery', company: 'Swiggy' });
    expect(parsePurpose('प्लंबर का काम है')).toEqual({ purpose: 'Maintenance' });
    expect(parsePurpose('dost se milne aaya hoon')?.purpose).toBe('Guest');
    expect(parsePurpose('मिलने आया हूँ')).toEqual({ purpose: 'Visit' });
    expect(parsePurpose('kuch nahi')).toBeNull();
  });
});

describe('parseEditField', () => {
  it('finds the detail to correct', () => {
    expect(parseEditField('naam galat hai')).toBe('name');
    expect(parseEditField('गाड़ी नंबर बदलना है')).toBe('vehicle');
    expect(parseEditField('mobile number')).toBe('phone');
    expect(parseEditField('फ्लैट')).toBe('flat');
    expect(parseEditField('kuch nahi')).toBeNull();
  });
});
