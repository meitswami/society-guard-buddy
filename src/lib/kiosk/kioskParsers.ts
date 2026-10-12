/**
 * Rule-based understanding of what a visitor says at the AI kiosk.
 * Works on Hindi (Devanagari), Hinglish (romanised Hindi) and English transcripts
 * coming from the browser speech recogniser. Pure functions — no browser APIs.
 */

const DEVANAGARI_DIGITS = '०१२३४५६७८९';

/** Spoken digit words → digit. Keys are lowercase / Devanagari. */
const DIGIT_WORDS: Record<string, string> = {
  // English
  zero: '0', oh: '0', one: '1', two: '2', three: '3', four: '4', five: '5',
  six: '6', seven: '7', eight: '8', nine: '9',
  // Hinglish
  shunya: '0', shoonya: '0', sunya: '0', jiro: '0', ek: '1', do: '2', teen: '3', tin: '3',
  char: '4', chaar: '4', chār: '4', panch: '5', paanch: '5', paach: '5', chhe: '6', chhah: '6',
  chah: '6', che: '6', chhey: '6', saat: '7', sat: '7', aath: '8', ath: '8', aat: '8', nau: '9', nao: '9',
  // Devanagari
  'शून्य': '0', 'शुन्य': '0', 'जीरो': '0', 'ज़ीरो': '0', 'एक': '1', 'दो': '2', 'तीन': '3',
  'चार': '4', 'पांच': '5', 'पाँच': '5', 'छह': '6', 'छः': '6', 'छे': '6', 'छै': '6', 'छ': '6',
  'सात': '7', 'आठ': '8', 'नौ': '9',
};

const TENS_WORDS: Record<string, number> = {
  ten: 10, twenty: 20, thirty: 30, forty: 40, fifty: 50, sixty: 60, seventy: 70, eighty: 80, ninety: 90,
  das: 10, bees: 20, tees: 30, chalis: 40, pachas: 50, saath: 60, sattar: 70, assi: 80, nabbe: 90,
  'दस': 10, 'बीस': 20, 'तीस': 30, 'चालीस': 40, 'पचास': 50, 'साठ': 60, 'सत्तर': 70, 'अस्सी': 80, 'नब्बे': 90,
};

const HUNDRED_WORDS = new Set(['hundred', 'sau', 'so', 'सौ']);
const THOUSAND_WORDS = new Set(['thousand', 'hazar', 'hazaar', 'hajar', 'हज़ार', 'हजार']);
const DOUBLE_WORDS = new Set(['double', 'dabal', 'डबल']);
const TRIPLE_WORDS = new Set(['triple', 'tripal', 'ट्रिपल']);

export function normalizeDevanagariDigits(text: string): string {
  return text.replace(/[०-९]/g, (d) => String(DEVANAGARI_DIGITS.indexOf(d)));
}

function tokenize(text: string): string[] {
  return normalizeDevanagariDigits(text)
    .toLowerCase()
    .replace(/[,.;:!?।|()"'“”‘’\-_/+]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

/** Collect every digit spoken, in order — "nau aath 7 6" → "9876", "double five" → "55". */
export function extractDigits(text: string): string {
  const tokens = tokenize(text);
  let out = '';
  let repeat = 1;
  for (const tok of tokens) {
    if (DOUBLE_WORDS.has(tok)) { repeat = 2; continue; }
    if (TRIPLE_WORDS.has(tok)) { repeat = 3; continue; }
    let digits = '';
    if (/^\d+$/.test(tok)) digits = tok;
    else if (DIGIT_WORDS[tok]) digits = DIGIT_WORDS[tok];
    else {
      // Glued tokens such as "98765abc" — keep the digit part.
      const m = tok.match(/\d+/g);
      if (m) digits = m.join('');
    }
    if (!digits) continue;
    out += digits[0].repeat(repeat) + digits.slice(1);
    repeat = 1;
  }
  return out;
}

/** Indian mobile number (10 digits starting 6–9), tolerant of +91 / 0 prefixes. */
export function parsePhone(text: string): string | null {
  let digits = extractDigits(text);
  if (digits.length === 12 && digits.startsWith('91')) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
  if (digits.length !== 10) return null;
  if (!/^[6-9]/.test(digits)) return null;
  return digits;
}

/**
 * A spoken number: "604", "six zero four", "छह सौ चार", "six hundred four".
 * Returns the number as a digit string, or '' when nothing numeric was said.
 */
export function parseSpokenNumber(text: string): string {
  const tokens = tokenize(text);
  const isNumeric = (t?: string) => !!t && (/^\d+$/.test(t) || !!DIGIT_WORDS[t] || !!TENS_WORDS[t]);
  // "so" / "sau" only counts as hundred right after a number ("chhe so char" = 604).
  const compositional = tokens.some(
    (t, i) => (HUNDRED_WORDS.has(t) || THOUSAND_WORDS.has(t)) && isNumeric(tokens[i - 1]),
  );
  if (!compositional) {
    let digits = '';
    let pendingTens = 0;
    for (const tok of tokens) {
      if (TENS_WORDS[tok]) { pendingTens = TENS_WORDS[tok]; continue; }
      const d = /^\d+$/.test(tok) ? tok : DIGIT_WORDS[tok] || '';
      if (pendingTens) {
        digits += d.length === 1 ? String(pendingTens + Number(d)) : String(pendingTens) + d;
        pendingTens = 0;
      } else {
        digits += d;
      }
    }
    if (pendingTens) digits += String(pendingTens);
    return digits;
  }
  let total = 0;
  let current = 0;
  let seen = false;
  for (const tok of tokens) {
    if (/^\d+$/.test(tok)) { current += Number(tok); seen = true; continue; }
    if (DIGIT_WORDS[tok]) { current += Number(DIGIT_WORDS[tok]); seen = true; continue; }
    if (TENS_WORDS[tok]) { current += TENS_WORDS[tok]; seen = true; continue; }
    if (HUNDRED_WORDS.has(tok) && current) { current *= 100; continue; }
    if (THOUSAND_WORDS.has(tok) && current) { total += current * 1000; current = 0; continue; }
  }
  return seen ? String(total + current) : '';
}

/** Spoken English letter names in Devanagari (as Hindi recognisers write them). */
const DEVANAGARI_LETTER_NAMES: [string, string][] = [
  ['डब्ल्यू', 'W'], ['डबल्यू', 'W'], ['एक्स', 'X'], ['क्यू', 'Q'], ['ज़ेड', 'Z'], ['जेड', 'Z'],
  ['वाई', 'Y'], ['आई', 'I'], ['एफ', 'F'], ['एच', 'H'], ['एल', 'L'], ['एम', 'M'], ['एन', 'N'],
  ['आर', 'R'], ['एस', 'S'], ['बी', 'B'], ['सी', 'C'], ['डी', 'D'], ['जी', 'G'], ['जे', 'J'],
  ['के', 'K'], ['पी', 'P'], ['टी', 'T'], ['वी', 'V'], ['यू', 'U'], ['ओ', 'O'], ['ए', 'A'], ['ई', 'E'],
];
const DEVANAGARI_DIGIT_WORDS_SORTED = Object.keys(DIGIT_WORDS)
  .filter((k) => /[ऀ-ॿ]/.test(k))
  .sort((a, b) => b.length - a.length);

/**
 * Turn a spoken alphanumeric code into Latin letters + digits.
 * "एमएच 12 एबी 1234" → "MH12AB1234", "m h one two" → "MH12".
 */
export function spokenToAlphanumeric(text: string): string {
  const src = normalizeDevanagariDigits(text).replace(/[\s,.\-_/।]/g, '');
  let out = '';
  let i = 0;
  outer: while (i < src.length) {
    const ch = src[i];
    if (/[0-9A-Za-z]/.test(ch)) {
      // Latin run — check for spelled-out digit words first ("one", "two").
      const rest = src.slice(i).toLowerCase();
      for (const w of ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']) {
        if (rest.startsWith(w)) { out += DIGIT_WORDS[w]; i += w.length; continue outer; }
      }
      out += ch.toUpperCase();
      i++;
      continue;
    }
    for (const w of DEVANAGARI_DIGIT_WORDS_SORTED) {
      if (src.startsWith(w, i)) { out += DIGIT_WORDS[w]; i += w.length; continue outer; }
    }
    for (const [name, letter] of DEVANAGARI_LETTER_NAMES) {
      if (src.startsWith(name, i)) { out += letter; i += name.length; continue outer; }
    }
    i++;
  }
  return out;
}

const PLATE_RE = /^[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{3,4}$/;
const BH_PLATE_RE = /^\d{2}BH\d{4}[A-Z]{1,2}$/;

/** Indian vehicle registration number, e.g. MH02AB1234 or 22BH1234AA. */
export function parseVehicleNumber(text: string): string | null {
  const code = spokenToAlphanumeric(text);
  if (PLATE_RE.test(code) || BH_PLATE_RE.test(code)) return code;
  return null;
}

/** Words around a flat number that are not part of it. */
const FLAT_FILLER = new Set([
  'flat', 'flats', 'number', 'no', 'num', 'house', 'room', 'wing', 'tower', 'block', 'building', 'floor',
  'my', 'is', 'in', 'to', 'mera', 'hai', 'jana', 'jaana', 'mujhe', 'ke', 'ki', 'ka', 'liye', 'me', 'mein', 'par',
  'फ्लैट', 'फ़्लैट', 'नंबर', 'नम्बर', 'मकान', 'घर', 'कमरा', 'विंग', 'टावर', 'टॉवर', 'ब्लॉक', 'बिल्डिंग',
  'मेरा', 'है', 'हैं', 'जाना', 'मुझे', 'के', 'की', 'का', 'लिए', 'में', 'को', 'पर', 'जा', 'रहा', 'रही', 'हूँ', 'हूं',
]);

const flatKey = (s: string) => normalizeDevanagariDigits(s).toUpperCase().replace(/[^A-Z0-9]/g, '');

/**
 * Flat / house number. When the society's flat list is known, only flats on that
 * list are accepted (so "छह सौ चार" maps to "A-604" if that is the only 604).
 */
export function parseFlat(
  text: string,
  flatNumbers: string[],
): { flat: string | null; heard: string } {
  const cleaned = normalizeDevanagariDigits(text)
    .replace(/[,.;:!?।|()"'“”‘’\-_/]/g, ' ')
    .split(/\s+/)
    .filter((w) => w && !FLAT_FILLER.has(w.toLowerCase()))
    .join(' ');
  const code = spokenToAlphanumeric(cleaned);
  const number = parseSpokenNumber(cleaned);
  const letters = code.replace(/[0-9]/g, '');
  const wing = /^[A-H]$/.test(letters) ? letters : '';
  const candidates = new Set<string>();
  if (code) candidates.add(code);
  if (number) {
    candidates.add(number);
    if (wing) { candidates.add(wing + number); candidates.add(number + wing); }
  }
  const heard = wing && number ? `${wing}-${number}` : number || code;

  if (flatNumbers.length === 0) {
    return { flat: heard || null, heard };
  }

  const byKey = new Map(flatNumbers.map((f) => [flatKey(f), f]));
  for (const c of candidates) {
    const hit = byKey.get(c);
    if (hit) return { flat: hit, heard };
  }
  if (number) {
    const sameDigits = flatNumbers.filter((f) => flatKey(f).replace(/[A-Z]/g, '') === number);
    if (sameDigits.length === 1) return { flat: sameDigits[0], heard };
    if (wing) {
      const withWing = sameDigits.filter((f) => flatKey(f).includes(wing));
      if (withWing.length === 1) return { flat: withWing[0], heard };
    }
  }
  return { flat: null, heard };
}

const NEGATIVE_WORDS = [
  'नहीं', 'नही', 'ना', 'न', 'नो', 'गलत', 'ग़लत', 'मत', 'रद्द',
  'no', 'nahi', 'nahin', 'nai', 'nhi', 'na', 'nope', 'galat', 'wrong', 'incorrect', 'cancel', 'not',
];
const POSITIVE_WORDS = [
  'हाँ', 'हां', 'हा', 'हान', 'जी', 'सही', 'ठीक', 'बिल्कुल', 'बिलकुल', 'हांजी', 'हाँजी', 'यस', 'ओके', 'करेक्ट',
  'yes', 'yeah', 'yep', 'yup', 'haan', 'han', 'haa', 'ha', 'hanji', 'haanji', 'ji', 'sahi', 'theek', 'thik', 'ok',
  'okay', 'correct', 'right', 'bilkul', 'confirm', 'done', 'sure',
];

/** true = yes, false = no, null = could not tell. */
export function parseYesNo(text: string): boolean | null {
  const tokens = tokenize(text);
  if (tokens.some((t) => NEGATIVE_WORDS.includes(t))) return false;
  if (tokens.some((t) => POSITIVE_WORDS.includes(t))) return true;
  return null;
}

export type KioskPurpose = 'Visit' | 'Delivery' | 'Meeting' | 'Maintenance' | 'Guest' | 'Other';

const PURPOSE_KEYWORDS: [KioskPurpose, string[]][] = [
  ['Delivery', ['delivery', 'deliver', 'parcel', 'courier', 'package', 'order', 'saman', 'samaan', 'food',
    'डिलीवरी', 'डिलिवरी', 'पार्सल', 'कूरियर', 'कुरियर', 'सामान', 'ऑर्डर', 'खाना', 'पैकेट']],
  ['Maintenance', ['repair', 'maintenance', 'plumber', 'electrician', 'carpenter', 'service', 'technician',
    'kaam', 'mistri', 'painter', 'cleaning', 'safai', 'ac', 'मरम्मत', 'प्लंबर', 'इलेक्ट्रीशियन', 'बिजली',
    'मिस्त्री', 'सर्विस', 'काम', 'रिपेयर', 'सफाई', 'पेंटर', 'बढ़ई', 'नल']],
  ['Meeting', ['meeting', 'interview', 'office', 'business', 'मीटिंग', 'इंटरव्यू', 'बैठक']],
  ['Guest', ['guest', 'relative', 'friend', 'family', 'mehman', 'mehmaan', 'rishtedar', 'dost',
    'मेहमान', 'रिश्तेदार', 'दोस्त', 'परिवार', 'अतिथि']],
  ['Visit', ['visit', 'milne', 'milna', 'meet', 'mil', 'मिलने', 'मिलना', 'मुलाकात', 'मिलन']],
];

const DELIVERY_COMPANIES: [string, string[]][] = [
  ['Amazon', ['amazon', 'अमेज़न', 'अमेजन', 'अमेज़ॉन']],
  ['Flipkart', ['flipkart', 'फ्लिपकार्ट']],
  ['Swiggy', ['swiggy', 'स्विगी']],
  ['Zomato', ['zomato', 'ज़ोमैटो', 'जोमैटो', 'जोमाटो']],
  ['Blinkit', ['blinkit', 'ब्लिंकिट']],
  ['Zepto', ['zepto', 'ज़ेप्टो', 'जेप्टो']],
  ['BigBasket', ['bigbasket', 'बिगबास्केट']],
  ['Dunzo', ['dunzo', 'डंज़ो']],
  ['Meesho', ['meesho', 'मीशो']],
  ['Myntra', ['myntra', 'मिंत्रा']],
];

export function parsePurpose(text: string): { purpose: KioskPurpose; company?: string } | null {
  const tokens = tokenize(text);
  const joined = tokens.join(' ');
  let company: string | undefined;
  for (const [name, words] of DELIVERY_COMPANIES) {
    if (words.some((w) => joined.includes(w))) { company = name; break; }
  }
  if (company) return { purpose: 'Delivery', company };
  for (const [purpose, words] of PURPOSE_KEYWORDS) {
    if (tokens.some((t) => words.includes(t))) return { purpose };
  }
  return null;
}

const NAME_FILLER = new Set([
  // Devanagari
  'मेरा', 'मेरी', 'नाम', 'है', 'हैं', 'हूँ', 'हूं', 'हु', 'मैं', 'मै', 'जी', 'मुझे', 'कहते', 'बोलते', 'मेरे',
  'का', 'की', 'के', 'से', 'आया', 'आई', 'यह', 'ये', 'मेरो', 'सर', 'मैडम', 'साहब', 'नमस्ते',
  // Latin
  'my', 'name', 'is', 'mera', 'meri', 'naam', 'nam', 'hai', 'hain', 'hoon', 'hun', 'hu', 'main', 'mai', 'mein',
  'i', 'am', "i'm", 'im', 'this', 'its', "it's", 'ji', 'sir', 'madam', 'sahab', 'namaste', 'hello', 'hi', 'here',
  'call', 'me', 'myself', 'the',
]);

/** Pull a person's name out of a sentence: "मेरा नाम राहुल शर्मा है" → "राहुल शर्मा". */
export function parseName(text: string): string | null {
  const words = normalizeDevanagariDigits(text)
    .replace(/[,.;:!?।|()"“”‘’]/g, ' ')
    .split(/\s+/)
    .filter(Boolean)
    .filter((w) => !NAME_FILLER.has(w.toLowerCase()))
    .filter((w) => !/\d/.test(w));
  if (words.length === 0) return null;
  const name = words.slice(0, 4).join(' ');
  if (name.length < 2) return null;
  return /[ऀ-ॿ]/.test(name) ? name : titleCase(name);
}

function titleCase(s: string): string {
  return s.toLowerCase().replace(/(^|\s)\S/g, (c) => c.toUpperCase());
}

// ── Devanagari → Latin (for storing names the way guards type them) ──

const CONSONANTS: Record<string, string> = {
  'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n', 'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'n',
  'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
  'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm', 'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
  'ष': 'sh', 'स': 's', 'ह': 'h', 'ळ': 'l',
  'क़': 'q', 'ख़': 'kh', 'ग़': 'g', 'ज़': 'z', 'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f', 'य़': 'y',
};
const NUKTA_FORMS: Record<string, string> = { 'क': 'q', 'ख': 'kh', 'ग': 'g', 'ज': 'z', 'ड': 'r', 'ढ': 'rh', 'फ': 'f', 'य': 'y' };
const INDEPENDENT_VOWELS: Record<string, string> = {
  'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo', 'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai',
  'ओ': 'o', 'औ': 'au', 'ऑ': 'o',
};
const MATRAS: Record<string, string> = {
  'ा': 'a', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'u', 'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ॉ': 'o',
};
const VIRAMA = '्';
const NUKTA = '़';
const WORD_EXCEPTIONS: Record<string, string> = {
  'सिंह': 'singh', 'कुमार': 'kumar', 'कुमारी': 'kumari', 'मोहम्मद': 'mohammad', 'लक्ष्मी': 'lakshmi',
};

interface Syllable { cons: string; vowel: string; inherent: boolean; }

function transliterateWord(word: string): string {
  if (WORD_EXCEPTIONS[word]) return WORD_EXCEPTIONS[word];
  const syl: Syllable[] = [];
  const chars = Array.from(word);
  for (let i = 0; i < chars.length; i++) {
    const ch = chars[i];
    if (CONSONANTS[ch] !== undefined) {
      let cons = CONSONANTS[ch];
      if (chars[i + 1] === NUKTA) { cons = NUKTA_FORMS[ch] ?? cons; i++; }
      const next = chars[i + 1];
      if (next === VIRAMA) {
        // Half consonant: glue onto the next syllable as a cluster.
        syl.push({ cons, vowel: '', inherent: false });
        i++;
        continue;
      }
      if (next && MATRAS[next] !== undefined) {
        syl.push({ cons, vowel: MATRAS[next], inherent: false });
        i++;
      } else {
        syl.push({ cons, vowel: 'a', inherent: true });
      }
      continue;
    }
    if (INDEPENDENT_VOWELS[ch] !== undefined) { syl.push({ cons: '', vowel: INDEPENDENT_VOWELS[ch], inherent: false }); continue; }
    if (ch === 'ं' || ch === 'ँ' || ch === 'ः') {
      const last = syl[syl.length - 1];
      if (last) { last.vowel += ch === 'ः' ? 'h' : 'n'; last.inherent = false; }
      continue;
    }
    if (/[a-zA-Z0-9]/.test(ch)) syl.push({ cons: ch.toLowerCase(), vowel: '', inherent: false });
  }

  // Schwa deletion (Hindi drops the inherent "a" word-finally and in VC_CV contexts).
  const hasVowel = (s?: Syllable) => !!s && s.vowel !== '';
  const fullSyllables = syl.filter((s) => s.vowel !== '').length;
  for (let i = syl.length - 1; i >= 0; i--) {
    const s = syl[i];
    if (!s.inherent) continue;
    if (i === syl.length - 1) {
      if (fullSyllables > 1) s.vowel = '';
      continue;
    }
    // V C(a) C V → drop the "a" (कमला → kamla, अमरनाथ → amarnath).
    const prev = syl[i - 1];
    const next = syl[i + 1];
    if (hasVowel(prev) && next && next.cons !== '' && hasVowel(next)) s.vowel = '';
  }
  return syl.map((s) => s.cons + s.vowel).join('');
}

/** Romanise Devanagari text: "राहुल शर्मा" → "Rahul Sharma". Latin text passes through. */
export function transliterateToLatin(text: string): string {
  if (!/[ऀ-ॿ]/.test(text)) return text;
  return titleCase(
    text
      .split(/\s+/)
      .filter(Boolean)
      .map((w) => (/[ऀ-ॿ]/.test(w) ? transliterateWord(w) : w))
      .join(' '),
  );
}

/** Group a phone number for read-back: 9876543210 → "98765 43210". */
export function formatPhoneForDisplay(phone: string): string {
  return phone.length === 10 ? `${phone.slice(0, 5)} ${phone.slice(5)}` : phone;
}

/** Digits spaced out so TTS reads them one by one. */
export function phoneForSpeech(phone: string): string {
  return phone.split('').join(' ');
}

/** Try each recogniser alternative until one parses. */
export function firstParsed<T>(alternatives: string[], parse: (s: string) => T | null): T | null {
  for (const alt of alternatives) {
    const v = parse(alt);
    if (v !== null && v !== undefined) return v;
  }
  return null;
}

export type KioskEditField = 'name' | 'phone' | 'flat' | 'purpose' | 'vehicle';

const EDIT_FIELD_WORDS: [KioskEditField, string[]][] = [
  ['name', ['name', 'naam', 'nam', 'नाम']],
  ['phone', ['phone', 'mobile', 'number', 'contact', 'fone', 'फोन', 'फ़ोन', 'मोबाइल', 'नंबर', 'नम्बर']],
  ['flat', ['flat', 'house', 'ghar', 'wing', 'फ्लैट', 'फ़्लैट', 'घर', 'मकान', 'विंग']],
  ['purpose', ['purpose', 'kaam', 'kam', 'reason', 'work', 'काम', 'उद्देश्य', 'कारण']],
  ['vehicle', ['vehicle', 'gaadi', 'gadi', 'car', 'bike', 'scooter', 'गाड़ी', 'गाडी', 'वाहन', 'कार', 'बाइक']],
];

/** Which detail the visitor wants to correct ("naam galat hai" → name). */
export function parseEditField(text: string): KioskEditField | null {
  const tokens = tokenize(text);
  // Check vehicle before phone so "gaadi number" means the vehicle.
  const order: KioskEditField[] = ['vehicle', 'name', 'flat', 'purpose', 'phone'];
  for (const field of order) {
    const words = EDIT_FIELD_WORDS.find(([f]) => f === field)![1];
    if (tokens.some((t) => words.includes(t))) return field;
  }
  return null;
}
