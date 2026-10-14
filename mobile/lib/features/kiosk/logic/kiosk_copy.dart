/// What the AI receptionist says and shows, per kiosk language — port of web
/// `src/lib/kiosk/kioskCopy.ts`.
/// Hinglish is shown in Roman script but spoken with the Hindi voice (from the `hi`
/// text) so pronunciation stays natural.
library;

enum KioskLang {
  hi('हिंदी'),
  hinglish('Hinglish'),
  en('English');

  const KioskLang(this.label);

  /// Label on the language buttons.
  final String label;

  /// Web id (`'hi' | 'hinglish' | 'en'`), also sent to the `kiosk-assistant` function.
  String get id => name;

  static KioskLang? fromId(Object? id) {
    for (final l in values) {
      if (l.name == id) return l;
    }
    return null;
  }
}

/// Web `KIOSK_LANGS` (button order).
const List<KioskLang> kKioskLangs = [KioskLang.hi, KioskLang.hinglish, KioskLang.en];

/// Recogniser locale: Hinglish speech transcribes best (in Roman script) with en-IN.
const Map<KioskLang, String> kRecognitionLocale = {KioskLang.hi: 'hi-IN', KioskLang.hinglish: 'en-IN', KioskLang.en: 'en-IN'};

/// Voice locale.
const Map<KioskLang, String> kVoiceLocale = {KioskLang.hi: 'hi-IN', KioskLang.hinglish: 'hi-IN', KioskLang.en: 'en-IN'};

/// Keys of the kiosk copy (web `KioskCopyKey`).
enum KioskCopyKey {
  // Screensaver / framing
  idleTitle,
  idleSubtitle,
  idleTap,
  idleTip1,
  idleTip2,
  idleTip3,
  frameNone,
  frameTooFar,
  frameTooClose,
  frameOffCenter,
  frameHold,

  // Camera / detector status (bottom of the screensaver)
  statusCamStarting,
  statusCamDenied,
  statusCamError,
  /// Native-app wording of [statusCamError] (the web line talks about Chrome / app wrappers).
  statusCamErrorApp,
  statusDetectorLoading,
  statusNoDetector,
  statusLooking,
  retryCamera,

  // Conversation
  greeting,
  askName,
  confirmName,
  askPhone,
  confirmPhone,
  welcomeBack,
  askSameFlat,
  askFlat,
  confirmFlat,
  flatNotFound,
  askPurpose,
  askVehicle,
  askVehicleNumber,
  confirmVehicle,
  summary,
  whichField,
  didNotHear,
  didNotUnderstand,
  sayYesNo,
  typeInstead,
  blacklisted,
  askingResident,
  approved,
  rejected,
  approvalTimeout,
  done,
  saveFailed,
  sessionEnded,

  // On-screen labels
  youSaid,
  listening,
  understood,
  yes,
  no,
  repeat,
  typeIt,
  submit,
  skip,
  cancelSession,
  edit,
  fieldName,
  fieldPhone,
  fieldFlat,
  fieldPurpose,
  fieldVehicle,
  noVehicle,
  waitingResident,
  savingEntry,
  noMic,
}

typedef _Copy = Map<KioskLang, String>;

const Map<KioskCopyKey, _Copy> _copy = {
  // Screensaver / framing
  KioskCopyKey.idleTitle: {KioskLang.hi: 'नमस्ते 🙏', KioskLang.hinglish: 'Namaste 🙏', KioskLang.en: 'Welcome 🙏'},
  KioskCopyKey.idleSubtitle: {
    KioskLang.hi: 'एंट्री के लिए कैमरे के सामने आइए',
    KioskLang.hinglish: 'Entry ke liye camera ke saamne aaiye',
    KioskLang.en: 'Step in front of the camera to check in',
  },
  KioskCopyKey.idleTap: {KioskLang.hi: 'या स्क्रीन को छुएँ', KioskLang.hinglish: 'ya screen ko touch karein', KioskLang.en: 'or tap the screen'},
  KioskCopyKey.idleTip1: {
    KioskLang.hi: 'मैं आपकी एंट्री बोलकर दर्ज करूँगी',
    KioskLang.hinglish: 'Main aapki entry bolkar darj karungi',
    KioskLang.en: 'I will take your entry by voice',
  },
  KioskCopyKey.idleTip2: {
    KioskLang.hi: 'हिंदी, Hinglish या English — कोई भी भाषा चुनें',
    KioskLang.hinglish: 'Hindi, Hinglish ya English — koi bhi bhasha chuniye',
    KioskLang.en: 'Choose Hindi, Hinglish or English',
  },
  KioskCopyKey.idleTip3: {
    KioskLang.hi: 'कृपया मास्क / हेलमेट हटाकर कैमरे में देखें',
    KioskLang.hinglish: 'Kripya mask / helmet hatakar camera mein dekhiye',
    KioskLang.en: 'Please remove mask / helmet and look at the camera',
  },
  KioskCopyKey.frameNone: {KioskLang.hi: 'कैमरे के सामने आइए', KioskLang.hinglish: 'Camera ke saamne aaiye', KioskLang.en: 'Please face the camera'},
  KioskCopyKey.frameTooFar: {KioskLang.hi: 'थोड़ा पास आइए', KioskLang.hinglish: 'Thoda paas aaiye', KioskLang.en: 'Come a little closer'},
  KioskCopyKey.frameTooClose: {KioskLang.hi: 'थोड़ा पीछे हटिए', KioskLang.hinglish: 'Thoda peeche hatiye', KioskLang.en: 'Step back a little'},
  KioskCopyKey.frameOffCenter: {KioskLang.hi: 'कृपया बीच में आइए', KioskLang.hinglish: 'Kripya beech mein aaiye', KioskLang.en: 'Please move to the centre'},
  KioskCopyKey.frameHold: {KioskLang.hi: 'बढ़िया! ऐसे ही रहिए…', KioskLang.hinglish: 'Badhiya! Aise hi rahiye…', KioskLang.en: 'Great! Hold still…'},

  // Camera / detector status (bottom of the screensaver)
  KioskCopyKey.statusCamStarting: {
    KioskLang.hi: 'कैमरा शुरू हो रहा है…',
    KioskLang.hinglish: 'Camera shuru ho raha hai…',
    KioskLang.en: 'Starting camera…',
  },
  KioskCopyKey.statusCamDenied: {
    KioskLang.hi: 'कैमरे की अनुमति नहीं मिली — ऐप/ब्राउज़र सेटिंग में कैमरा चालू करें',
    KioskLang.hinglish: 'Camera permission nahi mili — app/browser settings mein camera allow karein',
    KioskLang.en: 'Camera blocked — allow camera in app / browser settings',
  },
  KioskCopyKey.statusCamError: {
    KioskLang.hi: 'कैमरा शुरू नहीं हुआ। यह ऐप कैमरा रोक रहा हो सकता है — Chrome में खोलकर देखें',
    KioskLang.hinglish: 'Camera shuru nahi hua. Ye app camera rok raha ho sakta hai — Chrome mein kholkar dekhiye',
    KioskLang.en: 'Camera did not start. This app may be blocking it — try opening in Chrome',
  },
  KioskCopyKey.statusCamErrorApp: {
    KioskLang.hi: 'कैमरा शुरू नहीं हुआ। कैमरा इस्तेमाल कर रहे दूसरे ऐप बंद करके फिर से कोशिश करें',
    KioskLang.hinglish: 'Camera shuru nahi hua. Camera use kar rahe doosre apps band karke phir se try karein',
    KioskLang.en: 'Camera did not start. Close other apps using the camera and try again',
  },
  KioskCopyKey.statusDetectorLoading: {
    KioskLang.hi: 'चेहरा पहचान लोड हो रही है…',
    KioskLang.hinglish: 'Face detection load ho raha hai…',
    KioskLang.en: 'Loading face detection…',
  },
  KioskCopyKey.statusNoDetector: {
    KioskLang.hi: 'चेहरा पहचान उपलब्ध नहीं — शुरू करने के लिए स्क्रीन छुएँ',
    KioskLang.hinglish: 'Face detection nahi chal raha — shuru karne ke liye screen touch karein',
    KioskLang.en: 'Face detection unavailable — tap the screen to start',
  },
  KioskCopyKey.statusLooking: {
    KioskLang.hi: 'कैमरा चालू · चेहरा देख रही हूँ',
    KioskLang.hinglish: 'Camera on · chehra dekh rahi hoon',
    KioskLang.en: 'Camera on · looking for a face',
  },
  KioskCopyKey.retryCamera: {KioskLang.hi: 'कैमरा फिर से शुरू करें', KioskLang.hinglish: 'Camera phir se shuru karein', KioskLang.en: 'Retry camera'},

  // Conversation
  KioskCopyKey.greeting: {
    KioskLang.hi: 'नमस्ते! {society} में आपका स्वागत है। मैं आपकी एंट्री में मदद करूँगी।',
    KioskLang.hinglish: 'Namaste! {society} mein aapka swagat hai. Main aapki entry mein madad karungi.',
    KioskLang.en: 'Hello! Welcome to {society}. I will help you with your entry.',
  },
  KioskCopyKey.askName: {KioskLang.hi: 'कृपया अपना पूरा नाम बताइए।', KioskLang.hinglish: 'Kripya apna poora naam bataiye.', KioskLang.en: 'Please tell me your full name.'},
  KioskCopyKey.confirmName: {
    KioskLang.hi: 'आपका नाम {name} है, सही है?',
    KioskLang.hinglish: 'Aapka naam {name} hai, sahi hai?',
    KioskLang.en: 'Your name is {name}, is that right?',
  },
  KioskCopyKey.askPhone: {
    KioskLang.hi: 'अपना दस अंकों का मोबाइल नंबर बताइए।',
    KioskLang.hinglish: 'Apna das ankon ka mobile number bataiye.',
    KioskLang.en: 'Please say your ten digit mobile number.',
  },
  KioskCopyKey.confirmPhone: {
    KioskLang.hi: 'आपका नंबर {phone} है, सही है?',
    KioskLang.hinglish: 'Aapka number {phone} hai, sahi hai?',
    KioskLang.en: 'Your number is {phone}, is that right?',
  },
  KioskCopyKey.welcomeBack: {KioskLang.hi: 'फिर से स्वागत है {name} जी!', KioskLang.hinglish: 'Phir se swagat hai {name} ji!', KioskLang.en: 'Welcome back, {name}!'},
  KioskCopyKey.askSameFlat: {
    KioskLang.hi: 'पिछली बार आप फ्लैट {flat} गए थे। क्या आज भी वहीं जाना है?',
    KioskLang.hinglish: 'Pichhli baar aap flat {flat} gaye the. Kya aaj bhi wahin jaana hai?',
    KioskLang.en: 'Last time you visited flat {flat}. Are you going there again today?',
  },
  KioskCopyKey.askFlat: {
    KioskLang.hi: 'आपको किस फ्लैट में जाना है? विंग और फ्लैट नंबर बताइए।',
    KioskLang.hinglish: 'Aapko kis flat mein jaana hai? Wing aur flat number bataiye.',
    KioskLang.en: 'Which flat are you visiting? Please say the wing and flat number.',
  },
  KioskCopyKey.confirmFlat: {KioskLang.hi: 'फ्लैट {flat}, सही है?', KioskLang.hinglish: 'Flat {flat}, sahi hai?', KioskLang.en: 'Flat {flat}, is that right?'},
  KioskCopyKey.flatNotFound: {
    KioskLang.hi: 'फ्लैट {flat} इस सोसाइटी में नहीं मिला। कृपया दोबारा बताइए।',
    KioskLang.hinglish: 'Flat {flat} is society mein nahi mila. Kripya dobara bataiye.',
    KioskLang.en: 'I could not find flat {flat} in this society. Please say it again.',
  },
  KioskCopyKey.askPurpose: {
    KioskLang.hi: 'आप किस काम से आए हैं? जैसे मिलने, डिलीवरी, मरम्मत या मीटिंग।',
    KioskLang.hinglish: 'Aap kis kaam se aaye hain? Jaise milne, delivery, repair ya meeting.',
    KioskLang.en: 'What is the purpose of your visit? For example visit, delivery, repair or meeting.',
  },
  KioskCopyKey.askVehicle: {KioskLang.hi: 'क्या आप गाड़ी से आए हैं?', KioskLang.hinglish: 'Kya aap gaadi se aaye hain?', KioskLang.en: 'Have you come with a vehicle?'},
  KioskCopyKey.askVehicleNumber: {KioskLang.hi: 'गाड़ी का नंबर बताइए।', KioskLang.hinglish: 'Gaadi ka number bataiye.', KioskLang.en: 'Please say the vehicle number.'},
  KioskCopyKey.confirmVehicle: {
    KioskLang.hi: 'गाड़ी नंबर {vehicle}, सही है?',
    KioskLang.hinglish: 'Gaadi number {vehicle}, sahi hai?',
    KioskLang.en: 'Vehicle number {vehicle}, is that right?',
  },
  KioskCopyKey.summary: {
    KioskLang.hi: 'कृपया स्क्रीन पर अपनी जानकारी देख लीजिए। क्या सब सही है?',
    KioskLang.hinglish: 'Kripya screen par apni jaankari dekh lijiye. Kya sab sahi hai?',
    KioskLang.en: 'Please check your details on the screen. Is everything correct?',
  },
  KioskCopyKey.whichField: {
    KioskLang.hi: 'क्या बदलना है? नाम, नंबर, फ्लैट, काम या गाड़ी?',
    KioskLang.hinglish: 'Kya badalna hai? Naam, number, flat, kaam ya gaadi?',
    KioskLang.en: 'What should I change? Name, number, flat, purpose or vehicle?',
  },
  KioskCopyKey.didNotHear: {KioskLang.hi: 'माफ़ कीजिए, मुझे सुनाई नहीं दिया।', KioskLang.hinglish: 'Maaf kijiye, mujhe sunai nahi diya.', KioskLang.en: "Sorry, I didn't catch that."},
  KioskCopyKey.didNotUnderstand: {
    KioskLang.hi: 'माफ़ कीजिए, मैं समझ नहीं पाई।',
    KioskLang.hinglish: 'Maaf kijiye, main samajh nahi paayi.',
    KioskLang.en: "Sorry, I didn't understand.",
  },
  KioskCopyKey.sayYesNo: {KioskLang.hi: 'कृपया हाँ या ना बोलिए।', KioskLang.hinglish: 'Kripya haan ya na boliye.', KioskLang.en: 'Please say yes or no.'},
  KioskCopyKey.typeInstead: {
    KioskLang.hi: 'कृपया नीचे स्क्रीन पर टाइप कर दीजिए।',
    KioskLang.hinglish: 'Kripya neeche screen par type kar dijiye.',
    KioskLang.en: 'Please type it on the screen below.',
  },
  KioskCopyKey.blacklisted: {
    KioskLang.hi: 'माफ़ कीजिए, आपकी एंट्री अभी नहीं हो सकती। कृपया गार्ड से संपर्क करें।',
    KioskLang.hinglish: 'Maaf kijiye, aapki entry abhi nahi ho sakti. Kripya guard se sampark karein.',
    KioskLang.en: 'Sorry, your entry cannot be completed. Please contact the guard.',
  },
  KioskCopyKey.askingResident: {
    KioskLang.hi: 'फ्लैट {flat} के निवासी से अनुमति ली जा रही है। कृपया थोड़ा इंतज़ार कीजिए।',
    KioskLang.hinglish: 'Flat {flat} ke resident se permission li ja rahi hai. Kripya thoda intezaar kijiye.',
    KioskLang.en: 'Asking the resident of flat {flat} for permission. Please wait a moment.',
  },
  KioskCopyKey.approved: {
    KioskLang.hi: 'निवासी ने अनुमति दे दी है।',
    KioskLang.hinglish: 'Resident ne permission de di hai.',
    KioskLang.en: 'The resident has approved your visit.',
  },
  KioskCopyKey.rejected: {
    KioskLang.hi: 'माफ़ कीजिए, निवासी ने अनुमति नहीं दी। कृपया गार्ड से बात करें।',
    KioskLang.hinglish: 'Maaf kijiye, resident ne permission nahi di. Kripya guard se baat karein.',
    KioskLang.en: 'Sorry, the resident did not approve the visit. Please speak to the guard.',
  },
  KioskCopyKey.approvalTimeout: {
    KioskLang.hi: 'निवासी से जवाब नहीं मिला। कृपया गार्ड से संपर्क करें।',
    KioskLang.hinglish: 'Resident se jawab nahi mila. Kripya guard se sampark karein.',
    KioskLang.en: 'No reply from the resident. Please contact the guard.',
  },
  KioskCopyKey.done: {
    KioskLang.hi: 'धन्यवाद {name} जी! आपकी एंट्री दर्ज हो गई है। आपका दिन शुभ हो।',
    KioskLang.hinglish: 'Dhanyavaad {name} ji! Aapki entry darj ho gayi hai. Aapka din shubh ho.',
    KioskLang.en: 'Thank you, {name}! Your entry has been recorded. Have a nice day.',
  },
  KioskCopyKey.saveFailed: {
    KioskLang.hi: 'माफ़ कीजिए, एंट्री सेव नहीं हो पाई। कृपया गार्ड से संपर्क करें।',
    KioskLang.hinglish: 'Maaf kijiye, entry save nahi ho paayi. Kripya guard se sampark karein.',
    KioskLang.en: 'Sorry, the entry could not be saved. Please contact the guard.',
  },
  KioskCopyKey.sessionEnded: {KioskLang.hi: 'सत्र समाप्त हुआ।', KioskLang.hinglish: 'Session khatam hua.', KioskLang.en: 'Session ended.'},

  // On-screen labels
  KioskCopyKey.youSaid: {KioskLang.hi: 'आपने कहा', KioskLang.hinglish: 'Aapne kaha', KioskLang.en: 'You said'},
  KioskCopyKey.listening: {KioskLang.hi: 'बोलिए… मैं सुन रही हूँ', KioskLang.hinglish: 'Boliye… main sun rahi hoon', KioskLang.en: 'Speak now… I am listening'},
  KioskCopyKey.understood: {KioskLang.hi: 'मैंने समझा', KioskLang.hinglish: 'Maine samjha', KioskLang.en: 'I understood'},
  KioskCopyKey.yes: {KioskLang.hi: 'हाँ, सही है', KioskLang.hinglish: 'Haan, sahi hai', KioskLang.en: 'Yes, correct'},
  KioskCopyKey.no: {KioskLang.hi: 'नहीं', KioskLang.hinglish: 'Nahi', KioskLang.en: 'No'},
  KioskCopyKey.repeat: {KioskLang.hi: 'फिर से बोलें', KioskLang.hinglish: 'Phir se bolein', KioskLang.en: 'Say again'},
  KioskCopyKey.typeIt: {KioskLang.hi: 'टाइप करें', KioskLang.hinglish: 'Type karein', KioskLang.en: 'Type it'},
  KioskCopyKey.submit: {KioskLang.hi: 'आगे बढ़ें', KioskLang.hinglish: 'Aage badhein', KioskLang.en: 'Continue'},
  KioskCopyKey.skip: {KioskLang.hi: 'छोड़ें', KioskLang.hinglish: 'Skip', KioskLang.en: 'Skip'},
  KioskCopyKey.cancelSession: {KioskLang.hi: 'रद्द करें', KioskLang.hinglish: 'Cancel', KioskLang.en: 'Cancel'},
  KioskCopyKey.edit: {KioskLang.hi: 'बदलें', KioskLang.hinglish: 'Badlein', KioskLang.en: 'Change'},
  KioskCopyKey.fieldName: {KioskLang.hi: 'नाम', KioskLang.hinglish: 'Naam', KioskLang.en: 'Name'},
  KioskCopyKey.fieldPhone: {KioskLang.hi: 'मोबाइल', KioskLang.hinglish: 'Mobile', KioskLang.en: 'Mobile'},
  KioskCopyKey.fieldFlat: {KioskLang.hi: 'फ्लैट', KioskLang.hinglish: 'Flat', KioskLang.en: 'Flat'},
  KioskCopyKey.fieldPurpose: {KioskLang.hi: 'काम', KioskLang.hinglish: 'Kaam', KioskLang.en: 'Purpose'},
  KioskCopyKey.fieldVehicle: {KioskLang.hi: 'गाड़ी', KioskLang.hinglish: 'Gaadi', KioskLang.en: 'Vehicle'},
  KioskCopyKey.noVehicle: {KioskLang.hi: 'नहीं', KioskLang.hinglish: 'Nahi', KioskLang.en: 'None'},
  KioskCopyKey.waitingResident: {
    KioskLang.hi: 'निवासी की अनुमति का इंतज़ार',
    KioskLang.hinglish: 'Resident ki permission ka intezaar',
    KioskLang.en: 'Waiting for resident approval',
  },
  KioskCopyKey.savingEntry: {KioskLang.hi: 'एंट्री दर्ज हो रही है…', KioskLang.hinglish: 'Entry darj ho rahi hai…', KioskLang.en: 'Saving your entry…'},
  KioskCopyKey.noMic: {
    KioskLang.hi: 'माइक की अनुमति नहीं मिली। कृपया टाइप करें या गार्ड को बुलाएँ।',
    KioskLang.hinglish: 'Mic ki permission nahi mili. Kripya type karein ya guard ko bulaiye.',
    KioskLang.en: 'Microphone is blocked. Please type, or call the guard.',
  },
};

const Map<String, _Copy> _purposeLabels = {
  'Visit': {KioskLang.hi: 'मिलने', KioskLang.hinglish: 'Milne', KioskLang.en: 'Visit'},
  'Delivery': {KioskLang.hi: 'डिलीवरी', KioskLang.hinglish: 'Delivery', KioskLang.en: 'Delivery'},
  'Meeting': {KioskLang.hi: 'मीटिंग', KioskLang.hinglish: 'Meeting', KioskLang.en: 'Meeting'},
  'Maintenance': {KioskLang.hi: 'मरम्मत / सर्विस', KioskLang.hinglish: 'Repair / Service', KioskLang.en: 'Maintenance'},
  'Guest': {KioskLang.hi: 'मेहमान', KioskLang.hinglish: 'Guest', KioskLang.en: 'Guest'},
  'Other': {KioskLang.hi: 'अन्य', KioskLang.hinglish: 'Other', KioskLang.en: 'Other'},
};

final RegExp _varRe = RegExp(r'\{(\w+)\}');

/// Web `fill`: unknown placeholders become '' when vars are given; untouched otherwise.
String _fill(String template, Map<String, String>? vars) {
  if (vars == null) return template;
  return template.replaceAllMapped(_varRe, (m) => vars[m[1]] ?? '');
}

/// On-screen text.
String kioskText(KioskCopyKey key, KioskLang lang, [Map<String, String>? vars]) => _fill(_copy[key]![lang]!, vars);

/// Text for the voice (Hinglish is voiced from the Devanagari line).
String kioskSpeech(KioskCopyKey key, KioskLang lang, [Map<String, String>? vars]) =>
    _fill(_copy[key]![lang == KioskLang.hinglish ? KioskLang.hi : lang]!, vars);

/// "Delivery" → "डिलीवरी" etc.; unknown purposes pass through.
String purposeLabel(String purpose, KioskLang lang) => _purposeLabels[purpose]?[lang] ?? purpose;
