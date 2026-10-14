/// Rule-based understanding of what a visitor says at the AI kiosk — 1:1 port of
/// web `src/lib/kiosk/kioskParsers.ts`.
/// Works on Hindi (Devanagari), Hinglish (romanised Hindi) and English transcripts
/// coming from the speech recogniser. Pure functions — no Flutter / platform APIs.
library;

const String _devanagariDigits = '०१२३४५६७८९';

/// Spoken digit words → digit. Keys are lowercase / Devanagari.
const Map<String, String> _digitWords = {
  // English
  'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
  'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
  // Hinglish
  'shunya': '0', 'shoonya': '0', 'sunya': '0', 'jiro': '0', 'ek': '1', 'do': '2', 'teen': '3', 'tin': '3',
  'char': '4', 'chaar': '4', 'chār': '4', 'panch': '5', 'paanch': '5', 'paach': '5', 'chhe': '6', 'chhah': '6',
  'chah': '6', 'che': '6', 'chhey': '6', 'saat': '7', 'sat': '7', 'aath': '8', 'ath': '8', 'aat': '8', 'nau': '9', 'nao': '9',
  // Devanagari
  'शून्य': '0', 'शुन्य': '0', 'जीरो': '0', 'ज़ीरो': '0', 'एक': '1', 'दो': '2', 'तीन': '3',
  'चार': '4', 'पांच': '5', 'पाँच': '5', 'छह': '6', 'छः': '6', 'छे': '6', 'छै': '6', 'छ': '6',
  'सात': '7', 'आठ': '8', 'नौ': '9',
};

const Map<String, int> _tensWords = {
  'ten': 10, 'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  'das': 10, 'bees': 20, 'tees': 30, 'chalis': 40, 'pachas': 50, 'saath': 60, 'sattar': 70, 'assi': 80, 'nabbe': 90,
  'दस': 10, 'बीस': 20, 'तीस': 30, 'चालीस': 40, 'पचास': 50, 'साठ': 60, 'सत्तर': 70, 'अस्सी': 80, 'नब्बे': 90,
};

const Set<String> _hundredWords = {'hundred', 'sau', 'so', 'सौ'};
const Set<String> _thousandWords = {'thousand', 'hazar', 'hazaar', 'hajar', 'हज़ार', 'हजार'};
const Set<String> _doubleWords = {'double', 'dabal', 'डबल'};
const Set<String> _tripleWords = {'triple', 'tripal', 'ट्रिपल'};

final RegExp _devanagariDigitRe = RegExp('[०-९]');
final RegExp _devanagariRe = RegExp('[ऀ-ॿ]');
final RegExp _allDigitsRe = RegExp(r'^\d+$');
final RegExp _digitRunRe = RegExp(r'\d+');
final RegExp _whitespaceRe = RegExp(r'\s+');

/// `९८७` → `987`.
String normalizeDevanagariDigits(String text) =>
    text.replaceAllMapped(_devanagariDigitRe, (m) => '${_devanagariDigits.indexOf(m[0]!)}');

final RegExp _tokenPunctRe = RegExp(r'''[,.;:!?।|()"'“”‘’\-_/+]''');

List<String> _tokenize(String text) => normalizeDevanagariDigits(text)
    .toLowerCase()
    .replaceAll(_tokenPunctRe, ' ')
    .split(_whitespaceRe)
    .where((s) => s.isNotEmpty)
    .toList();

/// Collect every digit spoken, in order — "nau aath 7 6" → "9876", "double five" → "55".
String extractDigits(String text) {
  final tokens = _tokenize(text);
  final out = StringBuffer();
  var repeat = 1;
  for (final tok in tokens) {
    if (_doubleWords.contains(tok)) {
      repeat = 2;
      continue;
    }
    if (_tripleWords.contains(tok)) {
      repeat = 3;
      continue;
    }
    var digits = '';
    if (_allDigitsRe.hasMatch(tok)) {
      digits = tok;
    } else if (_digitWords[tok] != null) {
      digits = _digitWords[tok]!;
    } else {
      // Glued tokens such as "98765abc" — keep the digit part.
      final m = _digitRunRe.allMatches(tok).map((e) => e[0]!).toList();
      if (m.isNotEmpty) digits = m.join();
    }
    if (digits.isEmpty) continue;
    out
      ..write(digits[0] * repeat)
      ..write(digits.substring(1));
    repeat = 1;
  }
  return out.toString();
}

final RegExp _mobileStartRe = RegExp('^[6-9]');

/// Indian mobile number (10 digits starting 6–9), tolerant of +91 / 0 prefixes.
String? parsePhone(String text) {
  var digits = extractDigits(text);
  if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
  if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length != 10) return null;
  if (!_mobileStartRe.hasMatch(digits)) return null;
  return digits;
}

/// A spoken number: "604", "six zero four", "छह सौ चार", "six hundred four".
/// Returns the number as a digit string, or '' when nothing numeric was said.
String parseSpokenNumber(String text) {
  final tokens = _tokenize(text);
  bool isNumeric(String? t) =>
      t != null && t.isNotEmpty && (_allDigitsRe.hasMatch(t) || _digitWords[t] != null || _tensWords[t] != null);
  // "so" / "sau" only counts as hundred right after a number ("chhe so char" = 604).
  var compositional = false;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if ((_hundredWords.contains(t) || _thousandWords.contains(t)) && isNumeric(i > 0 ? tokens[i - 1] : null)) {
      compositional = true;
      break;
    }
  }
  if (!compositional) {
    final digits = StringBuffer();
    var pendingTens = 0;
    for (final tok in tokens) {
      final tens = _tensWords[tok];
      if (tens != null) {
        pendingTens = tens;
        continue;
      }
      final d = _allDigitsRe.hasMatch(tok) ? tok : (_digitWords[tok] ?? '');
      if (pendingTens != 0) {
        digits.write(d.length == 1 ? '${pendingTens + int.parse(d)}' : '$pendingTens$d');
        pendingTens = 0;
      } else {
        digits.write(d);
      }
    }
    if (pendingTens != 0) digits.write('$pendingTens');
    return digits.toString();
  }
  // BigInt so absurdly long digit runs cannot overflow.
  var total = BigInt.zero;
  var current = BigInt.zero;
  var seen = false;
  for (final tok in tokens) {
    if (_allDigitsRe.hasMatch(tok)) {
      current += BigInt.parse(tok);
      seen = true;
      continue;
    }
    final word = _digitWords[tok];
    if (word != null) {
      current += BigInt.parse(word);
      seen = true;
      continue;
    }
    final tens = _tensWords[tok];
    if (tens != null) {
      current += BigInt.from(tens);
      seen = true;
      continue;
    }
    if (_hundredWords.contains(tok) && current != BigInt.zero) {
      current *= BigInt.from(100);
      continue;
    }
    if (_thousandWords.contains(tok) && current != BigInt.zero) {
      total += current * BigInt.from(1000);
      current = BigInt.zero;
      continue;
    }
  }
  return seen ? '${total + current}' : '';
}

/// Spoken English letter names in Devanagari (as Hindi recognisers write them).
const List<(String, String)> _devanagariLetterNames = [
  ('डब्ल्यू', 'W'), ('डबल्यू', 'W'), ('एक्स', 'X'), ('क्यू', 'Q'), ('ज़ेड', 'Z'), ('जेड', 'Z'),
  ('वाई', 'Y'), ('आई', 'I'), ('एफ', 'F'), ('एच', 'H'), ('एल', 'L'), ('एम', 'M'), ('एन', 'N'),
  ('आर', 'R'), ('एस', 'S'), ('बी', 'B'), ('सी', 'C'), ('डी', 'D'), ('जी', 'G'), ('जे', 'J'),
  ('के', 'K'), ('पी', 'P'), ('टी', 'T'), ('वी', 'V'), ('यू', 'U'), ('ओ', 'O'), ('ए', 'A'), ('ई', 'E'),
];

/// Devanagari digit words, longest first (stable, like the JS `sort`).
final List<String> _devanagariDigitWordsSorted = () {
  final keys = _digitWords.keys.where((k) => _devanagariRe.hasMatch(k)).toList();
  final indexed = [for (var i = 0; i < keys.length; i++) (i, keys[i])];
  indexed.sort((a, b) {
    final byLength = b.$2.length - a.$2.length;
    return byLength != 0 ? byLength : a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}();

const List<String> _latinDigitWords = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
final RegExp _alnumCodeStripRe = RegExp(r'[\s,.\-_/।]');
final RegExp _latinAlnumCharRe = RegExp('[0-9A-Za-z]');

/// Turn a spoken alphanumeric code into Latin letters + digits.
/// "एमएच 12 एबी 1234" → "MH12AB1234", "m h one two" → "MH12".
String spokenToAlphanumeric(String text) {
  final src = normalizeDevanagariDigits(text).replaceAll(_alnumCodeStripRe, '');
  final out = StringBuffer();
  var i = 0;
  outer:
  while (i < src.length) {
    final ch = src[i];
    if (_latinAlnumCharRe.hasMatch(ch)) {
      // Latin run — check for spelled-out digit words first ("one", "two").
      final rest = src.substring(i).toLowerCase();
      for (final w in _latinDigitWords) {
        if (rest.startsWith(w)) {
          out.write(_digitWords[w]);
          i += w.length;
          continue outer;
        }
      }
      out.write(ch.toUpperCase());
      i++;
      continue;
    }
    for (final w in _devanagariDigitWordsSorted) {
      if (src.startsWith(w, i)) {
        out.write(_digitWords[w]);
        i += w.length;
        continue outer;
      }
    }
    for (final (name, letter) in _devanagariLetterNames) {
      if (src.startsWith(name, i)) {
        out.write(letter);
        i += name.length;
        continue outer;
      }
    }
    i++;
  }
  return out.toString();
}

final RegExp _plateRe = RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{3,4}$');
final RegExp _bhPlateRe = RegExp(r'^\d{2}BH\d{4}[A-Z]{1,2}$');

/// Indian vehicle registration number, e.g. MH02AB1234 or 22BH1234AA.
String? parseVehicleNumber(String text) {
  final code = spokenToAlphanumeric(text);
  if (_plateRe.hasMatch(code) || _bhPlateRe.hasMatch(code)) return code;
  return null;
}

/// Words around a flat number that are not part of it.
const Set<String> _flatFiller = {
  'flat', 'flats', 'number', 'no', 'num', 'house', 'room', 'wing', 'tower', 'block', 'building', 'floor',
  'my', 'is', 'in', 'to', 'mera', 'hai', 'jana', 'jaana', 'mujhe', 'ke', 'ki', 'ka', 'liye', 'me', 'mein', 'par',
  'फ्लैट', 'फ़्लैट', 'नंबर', 'नम्बर', 'मकान', 'घर', 'कमरा', 'विंग', 'टावर', 'टॉवर', 'ब्लॉक', 'बिल्डिंग',
  'मेरा', 'है', 'हैं', 'जाना', 'मुझे', 'के', 'की', 'का', 'लिए', 'में', 'को', 'पर', 'जा', 'रहा', 'रही', 'हूँ', 'हूं',
};

final RegExp _nonAlnumUpperRe = RegExp('[^A-Z0-9]');
final RegExp _flatPunctRe = RegExp(r'''[,.;:!?।|()"'“”‘’\-_/]''');
final RegExp _digitCharRe = RegExp('[0-9]');
final RegExp _upperLetterRe = RegExp('[A-Z]');
final RegExp _wingRe = RegExp(r'^[A-H]$');

String _flatKey(String s) => normalizeDevanagariDigits(s).toUpperCase().replaceAll(_nonAlnumUpperRe, '');

/// Flat / house number. When the society's flat list is known, only flats on that
/// list are accepted (so "छह सौ चार" maps to "A-604" if that is the only 604).
({String? flat, String heard}) parseFlat(String text, List<String> flatNumbers) {
  final cleaned = normalizeDevanagariDigits(text)
      .replaceAll(_flatPunctRe, ' ')
      .split(_whitespaceRe)
      .where((w) => w.isNotEmpty && !_flatFiller.contains(w.toLowerCase()))
      .join(' ');
  final code = spokenToAlphanumeric(cleaned);
  final number = parseSpokenNumber(cleaned);
  final letters = code.replaceAll(_digitCharRe, '');
  final wing = _wingRe.hasMatch(letters) ? letters : '';
  final candidates = <String>{};
  if (code.isNotEmpty) candidates.add(code);
  if (number.isNotEmpty) {
    candidates.add(number);
    if (wing.isNotEmpty) {
      candidates
        ..add(wing + number)
        ..add(number + wing);
    }
  }
  final heard = wing.isNotEmpty && number.isNotEmpty ? '$wing-$number' : (number.isNotEmpty ? number : code);

  if (flatNumbers.isEmpty) {
    return (flat: heard.isEmpty ? null : heard, heard: heard);
  }

  final byKey = <String, String>{for (final f in flatNumbers) _flatKey(f): f};
  for (final c in candidates) {
    final hit = byKey[c];
    if (hit != null && hit.isNotEmpty) return (flat: hit, heard: heard);
  }
  if (number.isNotEmpty) {
    final sameDigits = flatNumbers.where((f) => _flatKey(f).replaceAll(_upperLetterRe, '') == number).toList();
    if (sameDigits.length == 1) return (flat: sameDigits.first, heard: heard);
    if (wing.isNotEmpty) {
      final withWing = sameDigits.where((f) => _flatKey(f).contains(wing)).toList();
      if (withWing.length == 1) return (flat: withWing.first, heard: heard);
    }
  }
  return (flat: null, heard: heard);
}

const List<String> _negativeWords = [
  'नहीं', 'नही', 'ना', 'न', 'नो', 'गलत', 'ग़लत', 'मत', 'रद्द',
  'no', 'nahi', 'nahin', 'nai', 'nhi', 'na', 'nope', 'galat', 'wrong', 'incorrect', 'cancel', 'not',
];
const List<String> _positiveWords = [
  'हाँ', 'हां', 'हा', 'हान', 'जी', 'सही', 'ठीक', 'बिल्कुल', 'बिलकुल', 'हांजी', 'हाँजी', 'यस', 'ओके', 'करेक्ट',
  'yes', 'yeah', 'yep', 'yup', 'haan', 'han', 'haa', 'ha', 'hanji', 'haanji', 'ji', 'sahi', 'theek', 'thik', 'ok',
  'okay', 'correct', 'right', 'bilkul', 'confirm', 'done', 'sure',
];

/// true = yes, false = no, null = could not tell.
bool? parseYesNo(String text) {
  final tokens = _tokenize(text);
  if (tokens.any(_negativeWords.contains)) return false;
  if (tokens.any(_positiveWords.contains)) return true;
  return null;
}

/// Visit purposes, stored in `visitors.purpose` by their [label].
enum KioskPurpose {
  visit('Visit'),
  delivery('Delivery'),
  meeting('Meeting'),
  maintenance('Maintenance'),
  guest('Guest'),
  other('Other');

  const KioskPurpose(this.label);

  /// Web value (`'Visit' | 'Delivery' | …`).
  final String label;

  /// Case-insensitive match on the web value ("delivery" → [delivery]).
  static KioskPurpose? fromLabel(String value) {
    final v = value.toLowerCase();
    for (final p in values) {
      if (p.label.toLowerCase() == v) return p;
    }
    return null;
  }
}

/// Result of [parsePurpose] (web `{ purpose, company? }`).
class KioskPurposeMatch {
  const KioskPurposeMatch(this.purpose, {this.company});

  final KioskPurpose purpose;
  final String? company;

  @override
  bool operator ==(Object other) => other is KioskPurposeMatch && other.purpose == purpose && other.company == company;

  @override
  int get hashCode => Object.hash(purpose, company);

  @override
  String toString() => 'KioskPurposeMatch(${purpose.label}${company == null ? '' : ', $company'})';
}

const List<(KioskPurpose, List<String>)> _purposeKeywords = [
  (KioskPurpose.delivery, ['delivery', 'deliver', 'parcel', 'courier', 'package', 'order', 'saman', 'samaan', 'food',
    'डिलीवरी', 'डिलिवरी', 'पार्सल', 'कूरियर', 'कुरियर', 'सामान', 'ऑर्डर', 'खाना', 'पैकेट']),
  (KioskPurpose.maintenance, ['repair', 'maintenance', 'plumber', 'electrician', 'carpenter', 'service', 'technician',
    'kaam', 'mistri', 'painter', 'cleaning', 'safai', 'ac', 'मरम्मत', 'प्लंबर', 'इलेक्ट्रीशियन', 'बिजली',
    'मिस्त्री', 'सर्विस', 'काम', 'रिपेयर', 'सफाई', 'पेंटर', 'बढ़ई', 'नल']),
  (KioskPurpose.meeting, ['meeting', 'interview', 'office', 'business', 'मीटिंग', 'इंटरव्यू', 'बैठक']),
  (KioskPurpose.guest, ['guest', 'relative', 'friend', 'family', 'mehman', 'mehmaan', 'rishtedar', 'dost',
    'मेहमान', 'रिश्तेदार', 'दोस्त', 'परिवार', 'अतिथि']),
  (KioskPurpose.visit, ['visit', 'milne', 'milna', 'meet', 'mil', 'मिलने', 'मिलना', 'मुलाकात', 'मिलन']),
];

const List<(String, List<String>)> _deliveryCompanies = [
  ('Amazon', ['amazon', 'अमेज़न', 'अमेजन', 'अमेज़ॉन']),
  ('Flipkart', ['flipkart', 'फ्लिपकार्ट']),
  ('Swiggy', ['swiggy', 'स्विगी']),
  ('Zomato', ['zomato', 'ज़ोमैटो', 'जोमैटो', 'जोमाटो']),
  ('Blinkit', ['blinkit', 'ब्लिंकिट']),
  ('Zepto', ['zepto', 'ज़ेप्टो', 'जेप्टो']),
  ('BigBasket', ['bigbasket', 'बिगबास्केट']),
  ('Dunzo', ['dunzo', 'डंज़ो']),
  ('Meesho', ['meesho', 'मीशो']),
  ('Myntra', ['myntra', 'मिंत्रा']),
];

KioskPurposeMatch? parsePurpose(String text) {
  final tokens = _tokenize(text);
  final joined = tokens.join(' ');
  String? company;
  for (final (name, words) in _deliveryCompanies) {
    if (words.any(joined.contains)) {
      company = name;
      break;
    }
  }
  if (company != null) return KioskPurposeMatch(KioskPurpose.delivery, company: company);
  for (final (purpose, words) in _purposeKeywords) {
    if (tokens.any(words.contains)) return KioskPurposeMatch(purpose);
  }
  return null;
}

const Set<String> _nameFiller = {
  // Devanagari
  'मेरा', 'मेरी', 'नाम', 'है', 'हैं', 'हूँ', 'हूं', 'हु', 'मैं', 'मै', 'जी', 'मुझे', 'कहते', 'बोलते', 'मेरे',
  'का', 'की', 'के', 'से', 'आया', 'आई', 'यह', 'ये', 'मेरो', 'सर', 'मैडम', 'साहब', 'नमस्ते',
  // Latin
  'my', 'name', 'is', 'mera', 'meri', 'naam', 'nam', 'hai', 'hain', 'hoon', 'hun', 'hu', 'main', 'mai', 'mein',
  'i', 'am', "i'm", 'im', 'this', 'its', "it's", 'ji', 'sir', 'madam', 'sahab', 'namaste', 'hello', 'hi', 'here',
  'call', 'me', 'myself', 'the',
};

final RegExp _namePunctRe = RegExp('[,.;:!?।|()"“”‘’]');
final RegExp _anyDigitRe = RegExp(r'\d');

/// Pull a person's name out of a sentence: "मेरा नाम राहुल शर्मा है" → "राहुल शर्मा".
String? parseName(String text) {
  final words = normalizeDevanagariDigits(text)
      .replaceAll(_namePunctRe, ' ')
      .split(_whitespaceRe)
      .where((w) => w.isNotEmpty)
      .where((w) => !_nameFiller.contains(w.toLowerCase()))
      .where((w) => !_anyDigitRe.hasMatch(w))
      .toList();
  if (words.isEmpty) return null;
  final name = words.take(4).join(' ');
  if (name.length < 2) return null;
  return _devanagariRe.hasMatch(name) ? name : _titleCase(name);
}

final RegExp _wordStartRe = RegExp(r'(^|\s)\S');

String _titleCase(String s) => s.toLowerCase().replaceAllMapped(_wordStartRe, (m) => m[0]!.toUpperCase());

// ── Devanagari → Latin (for storing names the way guards type them) ──

const Map<String, String> _consonants = {
  'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n', 'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'n',
  'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
  'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm', 'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
  'ष': 'sh', 'स': 's', 'ह': 'h', 'ळ': 'l',
  'क़': 'q', 'ख़': 'kh', 'ग़': 'g', 'ज़': 'z', 'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f', 'य़': 'y',
};
const Map<String, String> _nuktaForms = {'क': 'q', 'ख': 'kh', 'ग': 'g', 'ज': 'z', 'ड': 'r', 'ढ': 'rh', 'फ': 'f', 'य': 'y'};
const Map<String, String> _independentVowels = {
  'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo', 'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai',
  'ओ': 'o', 'औ': 'au', 'ऑ': 'o',
};
const Map<String, String> _matras = {
  'ा': 'a', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'u', 'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ॉ': 'o',
};
const String _virama = '्';
const String _nukta = '़';
const Map<String, String> _wordExceptions = {
  'सिंह': 'singh', 'कुमार': 'kumar', 'कुमारी': 'kumari', 'मोहम्मद': 'mohammad', 'लक्ष्मी': 'lakshmi',
};

class _Syllable {
  _Syllable(this.cons, this.vowel, this.inherent);

  final String cons;
  String vowel;
  bool inherent;
}

final RegExp _latinOrDigitRe = RegExp('[a-zA-Z0-9]');

String _transliterateWord(String word) {
  final exception = _wordExceptions[word];
  if (exception != null) return exception;
  final syl = <_Syllable>[];
  // Code points, like JS `Array.from(word)`.
  final chars = word.runes.map(String.fromCharCode).toList();
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    final base = _consonants[ch];
    if (base != null) {
      var cons = base;
      if (i + 1 < chars.length && chars[i + 1] == _nukta) {
        cons = _nuktaForms[ch] ?? cons;
        i++;
      }
      final next = i + 1 < chars.length ? chars[i + 1] : null;
      if (next == _virama) {
        // Half consonant: glue onto the next syllable as a cluster.
        syl.add(_Syllable(cons, '', false));
        i++;
        continue;
      }
      final matra = next == null ? null : _matras[next];
      if (matra != null) {
        syl.add(_Syllable(cons, matra, false));
        i++;
      } else {
        syl.add(_Syllable(cons, 'a', true));
      }
      continue;
    }
    final vowel = _independentVowels[ch];
    if (vowel != null) {
      syl.add(_Syllable('', vowel, false));
      continue;
    }
    if (ch == 'ं' || ch == 'ँ' || ch == 'ः') {
      if (syl.isNotEmpty) {
        final last = syl.last;
        last.vowel += ch == 'ः' ? 'h' : 'n';
        last.inherent = false;
      }
      continue;
    }
    if (_latinOrDigitRe.hasMatch(ch)) syl.add(_Syllable(ch.toLowerCase(), '', false));
  }

  // Schwa deletion (Hindi drops the inherent "a" word-finally and in VC_CV contexts).
  bool hasVowel(_Syllable? s) => s != null && s.vowel != '';
  final fullSyllables = syl.where((s) => s.vowel != '').length;
  for (var i = syl.length - 1; i >= 0; i--) {
    final s = syl[i];
    if (!s.inherent) continue;
    if (i == syl.length - 1) {
      if (fullSyllables > 1) s.vowel = '';
      continue;
    }
    // V C(a) C V → drop the "a" (कमला → kamla, अमरनाथ → amarnath).
    final prev = i > 0 ? syl[i - 1] : null;
    final next = syl[i + 1];
    if (hasVowel(prev) && next.cons != '' && hasVowel(next)) s.vowel = '';
  }
  return syl.map((s) => s.cons + s.vowel).join();
}

/// Romanise Devanagari text: "राहुल शर्मा" → "Rahul Sharma". Latin text passes through.
String transliterateToLatin(String text) {
  if (!_devanagariRe.hasMatch(text)) return text;
  return _titleCase(
    text
        .split(_whitespaceRe)
        .where((w) => w.isNotEmpty)
        .map((w) => _devanagariRe.hasMatch(w) ? _transliterateWord(w) : w)
        .join(' '),
  );
}

/// Group a phone number for read-back: 9876543210 → "98765 43210".
String formatPhoneForDisplay(String phone) =>
    phone.length == 10 ? '${phone.substring(0, 5)} ${phone.substring(5)}' : phone;

/// Digits spaced out so TTS reads them one by one.
String phoneForSpeech(String phone) => phone.split('').join(' ');

/// Try each recogniser alternative until one parses.
T? firstParsed<T extends Object>(List<String> alternatives, T? Function(String) parse) {
  for (final alt in alternatives) {
    final v = parse(alt);
    if (v != null) return v;
  }
  return null;
}

/// A detail the visitor can correct on the summary screen.
enum KioskEditField { name, phone, flat, purpose, vehicle }

const Map<KioskEditField, List<String>> _editFieldWords = {
  KioskEditField.name: ['name', 'naam', 'nam', 'नाम'],
  KioskEditField.phone: ['phone', 'mobile', 'number', 'contact', 'fone', 'फोन', 'फ़ोन', 'मोबाइल', 'नंबर', 'नम्बर'],
  KioskEditField.flat: ['flat', 'house', 'ghar', 'wing', 'फ्लैट', 'फ़्लैट', 'घर', 'मकान', 'विंग'],
  KioskEditField.purpose: ['purpose', 'kaam', 'kam', 'reason', 'work', 'काम', 'उद्देश्य', 'कारण'],
  KioskEditField.vehicle: ['vehicle', 'gaadi', 'gadi', 'car', 'bike', 'scooter', 'गाड़ी', 'गाडी', 'वाहन', 'कार', 'बाइक'],
};

/// Which detail the visitor wants to correct ("naam galat hai" → name).
KioskEditField? parseEditField(String text) {
  final tokens = _tokenize(text);
  // Check vehicle before phone so "gaadi number" means the vehicle.
  const order = [KioskEditField.vehicle, KioskEditField.name, KioskEditField.flat, KioskEditField.purpose, KioskEditField.phone];
  for (final field in order) {
    final words = _editFieldWords[field]!;
    if (tokens.any(words.contains)) return field;
  }
  return null;
}
