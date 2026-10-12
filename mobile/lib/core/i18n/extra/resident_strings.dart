/// RESIDENT module strings the web hard-codes in English (shell, passes share, statements).
/// Keys are mobile-only (`resident.m.*`). One-off texts use `context.tr(en, hi)` inline.
const Map<String, Map<String, String>> kResidentStrings = {
  'resident.m.pressBackAgain': {'en': 'Press back again to exit', 'hi': 'बाहर निकलने के लिए फिर से वापस दबाएँ'},
  'resident.m.navPasses': {'en': 'Passes', 'hi': 'पास'},
  'resident.m.navProfile': {'en': 'Profile', 'hi': 'प्रोफ़ाइल'},
  'resident.m.sharePass': {'en': 'Share on WhatsApp', 'hi': 'व्हाट्सऐप पर भेजें'},
  'resident.m.cancelPass': {'en': 'Cancel pass', 'hi': 'पास रद्द करें'},
  'resident.m.cancelPassConfirm': {'en': 'Cancel this visitor pass?', 'hi': 'यह आगंतुक पास रद्द करें?'},
  'resident.m.cancelPassText': {
    'en': 'The guard will no longer accept OTP {otp}.',
    'hi': 'गार्ड अब ओटीपी {otp} स्वीकार नहीं करेगा।',
  },
  'resident.m.passCancelled': {'en': 'Pass cancelled', 'hi': 'पास रद्द किया गया'},
  'resident.m.statement': {'en': 'Statement', 'hi': 'विवरण पत्र'},
  'resident.m.statementTitle': {'en': 'Maintenance payment statement', 'hi': 'रखरखाव भुगतान विवरण पत्र'},
  'resident.m.dues': {'en': 'Maintenance dues', 'hi': 'रखरखाव देय'},
  'resident.m.invite': {'en': 'Invite on WhatsApp', 'hi': 'व्हाट्सऐप पर आमंत्रित करें'},
  'resident.m.member360': {'en': 'Member 360°', 'hi': 'सदस्य 360°'},
};
