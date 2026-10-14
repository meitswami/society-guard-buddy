/// GATE module strings the web hard-codes in English (guard home, entry pages, vehicles,
/// blacklist, photo capture, biometric card, shell). Keys are mobile-only (`gate.*`).
const Map<String, Map<String, String>> kGateStrings = {
  // Shell
  'gate.pressBackAgain': {
    'en': 'Press back again to exit',
    'hi': 'बाहर निकलने के लिए फिर से वापस दबाएँ'
  },

  // Home dashboard
  'gate.markExitTitle': {
    'en': '🚪 Mark Exit?',
    'hi': '🚪 बाहर जाना दर्ज करें?'
  },
  'gate.markExitText': {
    'en': 'Are you sure you want to mark "{name}" as exited?',
    'hi': 'क्या आप "{name}" को बाहर गया दर्ज करना चाहते हैं?',
  },
  'gate.markExitConfirm': {'en': 'Yes, mark exit', 'hi': 'हाँ, बाहर दर्ज करें'},
  'gate.exitRecorded': {'en': 'Exit Recorded', 'hi': 'बाहर जाना दर्ज हुआ'},
  'gate.exitRecordedText': {
    'en': '{name} has been marked as exited.',
    'hi': '{name} को बाहर गया दर्ज कर दिया गया है।'
  },
  'gate.exitBadge': {'en': 'EXIT', 'hi': 'बाहर'},
  'gate.exitFailed': {
    'en': 'Could not mark exit. Try again.',
    'hi': 'बाहर जाना दर्ज नहीं हो सका। फिर से कोशिश करें।'
  },
  'gate.filterList': {'en': 'Filter list', 'hi': 'सूची छाँटें'},
  'gate.stat.visitors.desc': {
    'en': 'Guest and serviceman visitor entries for the selected day.',
    'hi': 'चुने गए दिन की मेहमान और सेवा कर्मी आगंतुक प्रविष्टियाँ।',
  },
  'gate.stat.visitors.how': {
    'en': 'Rows in the visitor log for today / yesterday offset.',
    'hi': 'चुने गए दिन (आज / कल) के आगंतुक रजिस्टर की पंक्तियाँ।',
  },
  'gate.stat.vehicles.desc': {
    'en': 'Visitor entries that include a vehicle number.',
    'hi': 'वे आगंतुक प्रविष्टियाँ जिनमें वाहन नंबर दर्ज है।',
  },
  'gate.stat.vehicles.how': {
    'en': 'Visitor rows with vehicle_number on the selected day.',
    'hi': 'चुने गए दिन की वाहन नंबर वाली आगंतुक पंक्तियाँ।',
  },
  'gate.stat.deliveries.desc': {
    'en': 'Delivery-category visitors for the day.',
    'hi': 'दिन के वितरण श्रेणी के आगंतुक।'
  },
  'gate.stat.deliveries.how': {
    'en': 'Visitors filtered as deliveries.',
    'hi': 'वितरण के रूप में छाँटे गए आगंतुक।'
  },
  'gate.stat.inside.desc': {
    'en': 'People still inside the society (no exit recorded).',
    'hi': 'जो लोग अभी भी सोसाइटी के अंदर हैं (बाहर जाना दर्ज नहीं)।',
  },
  'gate.stat.inside.how': {
    'en': 'Visitor rows with exit_time empty for the day view.',
    'hi': 'चुने गए दिन की वे पंक्तियाँ जिनमें बाहर जाने का समय खाली है।',
  },

  // Biometric card (web BiometricSetup)
  'gate.bio.devices': {
    'en': '({count}/{max} devices)',
    'hi': '({count}/{max} डिवाइस)'
  },
  'gate.bio.addAnother': {
    'en': 'Add another device ({count}/{max})',
    'hi': 'एक और डिवाइस जोड़ें ({count}/{max})'
  },
  'gate.bio.device': {
    'en': 'Device {n} ({id}...)',
    'hi': 'डिवाइस {n} ({id}...)'
  },
  'gate.bio.added': {'en': 'Added {date}', 'hi': 'जोड़ा गया {date}'},
  'gate.bio.remove': {'en': 'Remove', 'hi': 'हटाएं'},
  'gate.bio.removing': {'en': 'Removing...', 'hi': 'हटाया जा रहा है...'},
  'gate.bio.maxReached': {
    'en':
        'Max {max} biometrics reached. Adding one more will replace the oldest device.',
    'hi':
        'अधिकतम {max} बायोमेट्रिक पूरे हो गए। एक और जोड़ने पर सबसे पुराना डिवाइस बदल जाएगा।',
  },
  'gate.bio.removed': {
    'en': 'Biometric device removed',
    'hi': 'बायोमेट्रिक डिवाइस हटाया गया'
  },
  'gate.bio.removeFailed': {
    'en': 'Could not remove biometric device',
    'hi': 'बायोमेट्रिक डिवाइस हटाया नहीं जा सका'
  },

  // Photo capture
  'gate.photo.camera': {'en': 'Camera', 'hi': 'कैमरा'},
  'gate.photo.upload': {'en': 'Upload', 'hi': 'अपलोड'},
  'gate.photo.failed': {
    'en': 'Could not read the photo',
    'hi': 'फोटो पढ़ी नहीं जा सकी'
  },

  // Visitor / delivery entry
  'gate.visitor.phonePlaceholder': {
    'en': '10-digit number',
    'hi': '10 अंकों का नंबर'
  },
  'gate.visitor.flatPlaceholder': {'en': 'e.g. 604', 'hi': 'जैसे 604'},
  'gate.visitor.docPlaceholder': {'en': 'ID number', 'hi': 'पहचान संख्या'},
  'gate.visitor.vehiclePlaceholder': {
    'en': 'e.g. MH02AB1234',
    'hi': 'जैसे MH02AB1234'
  },
  'gate.visitor.required': {
    'en': 'Enter phone, name and flat number',
    'hi': 'फोन, नाम और फ्लैट नंबर दर्ज करें'
  },
  'gate.delivery.required': {
    'en': 'Enter name, phone and flat number',
    'hi': 'नाम, फोन और फ्लैट नंबर दर्ज करें'
  },
  'gate.saveFailed': {
    'en': 'Could not save the entry. Check your internet and try again.',
    'hi': 'प्रवेश सहेजा नहीं जा सका। इंटरनेट जाँचें और फिर से कोशिश करें।',
  },
  'gate.approval.flatNotFound': {
    'en': 'Flat {flat} was not found in this society',
    'hi': 'इस सोसाइटी में फ्लैट {flat} नहीं मिला'
  },
  'gate.approval.failed': {
    'en': 'Could not send the request. Try again.',
    'hi': 'अनुरोध भेजा नहीं जा सका। फिर से कोशिश करें।'
  },
  'gate.otp.failed': {
    'en': 'Could not verify the pass. Try again.',
    'hi': 'पास सत्यापित नहीं हो सका। फिर से कोशिश करें।'
  },

  // Vehicles
  'gate.vehicle.selectFlat': {
    'en': 'Select at least one flat',
    'hi': 'कम से कम एक फ्लैट चुनें'
  },
  'gate.vehicle.enterNumber': {
    'en': 'Enter the vehicle number',
    'hi': 'वाहन नंबर दर्ज करें'
  },
  'gate.vehicle.saved': {'en': 'Vehicle saved', 'hi': 'वाहन सहेजा गया'},
  'gate.vehicle.savedMany': {
    'en': 'Vehicles saved for {count} flats',
    'hi': '{count} फ्लैटों के लिए वाहन सहेजे गए'
  },
  'gate.vehicle.noResident': {
    'en': '{label}: flat {flat} (add owner or primary member)',
    'hi': '{label}: फ्लैट {flat} (मालिक या मुख्य सदस्य जोड़ें)',
  },

  // Flat multi-select (web FlatMultiSelect)
  'gate.flats.selected': {
    'en': '{label} ({count} selected)',
    'hi': '{label} ({count} चुने गए)'
  },
  'gate.flats.allVisible': {'en': 'All visible', 'hi': 'सभी दिखाई देने वाले'},
  'gate.flats.clearVisible': {
    'en': 'Clear visible',
    'hi': 'दिखाई देने वाले हटाएँ'
  },
  'gate.flats.search': {
    'en': 'Search flat or resident…',
    'hi': 'फ्लैट या निवासी खोजें…'
  },
  'gate.flats.empty': {
    'en': 'No flats match your search.',
    'hi': 'खोज से कोई फ्लैट मेल नहीं खाता।'
  },

  // Blacklist
  'gate.blacklist.by': {'en': 'by {name}', 'hi': '{name} द्वारा'},
  'gate.blacklist.reasonRequired': {
    'en': 'Enter a reason',
    'hi': 'कारण दर्ज करें'
  },
  'gate.blacklist.phoneRequired': {
    'en': 'Enter the phone number',
    'hi': 'फोन नंबर दर्ज करें'
  },
  'gate.blacklist.vehicleRequired': {
    'en': 'Enter the vehicle number',
    'hi': 'वाहन नंबर दर्ज करें'
  },

  // Generic
  'gate.deleteFailed': {
    'en': 'Could not delete. Try again.',
    'hi': 'हटाया नहीं जा सका। फिर से कोशिश करें।'
  },
  'gate.actionFailed': {
    'en': 'Something went wrong. Try again.',
    'hi': 'कुछ गड़बड़ हो गई। फिर से कोशिश करें।'
  },
};
