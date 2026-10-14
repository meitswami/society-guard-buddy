/**
 * What the AI receptionist says and shows, per kiosk language.
 * Hinglish is shown in Roman script but spoken with the Hindi voice (from the `hi`
 * text) so pronunciation stays natural.
 */

export type KioskLang = 'hi' | 'hinglish' | 'en';

export const KIOSK_LANGS: { id: KioskLang; label: string }[] = [
  { id: 'hi', label: 'हिंदी' },
  { id: 'hinglish', label: 'Hinglish' },
  { id: 'en', label: 'English' },
];

/** Recogniser locale: Hinglish speech transcribes best (in Roman script) with en-IN. */
export const RECOGNITION_LOCALE: Record<KioskLang, string> = { hi: 'hi-IN', hinglish: 'en-IN', en: 'en-IN' };
/** Voice locale. */
export const VOICE_LOCALE: Record<KioskLang, string> = { hi: 'hi-IN', hinglish: 'hi-IN', en: 'en-IN' };

type Copy = Record<KioskLang, string>;

const COPY = {
  // Screensaver / framing
  idleTitle: { hi: 'नमस्ते 🙏', hinglish: 'Namaste 🙏', en: 'Welcome 🙏' },
  idleSubtitle: {
    hi: 'एंट्री के लिए कैमरे के सामने आइए',
    hinglish: 'Entry ke liye camera ke saamne aaiye',
    en: 'Step in front of the camera to check in',
  },
  idleTap: { hi: 'या स्क्रीन को छुएँ', hinglish: 'ya screen ko touch karein', en: 'or tap the screen' },
  idleTip1: { hi: 'मैं आपकी एंट्री बोलकर दर्ज करूँगी', hinglish: 'Main aapki entry bolkar darj karungi', en: 'I will take your entry by voice' },
  idleTip2: { hi: 'हिंदी, Hinglish या English — कोई भी भाषा चुनें', hinglish: 'Hindi, Hinglish ya English — koi bhi bhasha chuniye', en: 'Choose Hindi, Hinglish or English' },
  idleTip3: { hi: 'कृपया मास्क / हेलमेट हटाकर कैमरे में देखें', hinglish: 'Kripya mask / helmet hatakar camera mein dekhiye', en: 'Please remove mask / helmet and look at the camera' },
  frameNone: { hi: 'कैमरे के सामने आइए', hinglish: 'Camera ke saamne aaiye', en: 'Please face the camera' },
  frameTooFar: { hi: 'थोड़ा पास आइए', hinglish: 'Thoda paas aaiye', en: 'Come a little closer' },
  frameTooClose: { hi: 'थोड़ा पीछे हटिए', hinglish: 'Thoda peeche hatiye', en: 'Step back a little' },
  frameOffCenter: { hi: 'कृपया बीच में आइए', hinglish: 'Kripya beech mein aaiye', en: 'Please move to the centre' },
  frameHold: { hi: 'बढ़िया! ऐसे ही रहिए…', hinglish: 'Badhiya! Aise hi rahiye…', en: 'Great! Hold still…' },

  // Camera / detector status (bottom of the screensaver)
  statusCamStarting: { hi: 'कैमरा शुरू हो रहा है…', hinglish: 'Camera shuru ho raha hai…', en: 'Starting camera…' },
  statusCamDenied: {
    hi: 'कैमरे की अनुमति नहीं मिली — ऐप/ब्राउज़र सेटिंग में कैमरा चालू करें',
    hinglish: 'Camera permission nahi mili — app/browser settings mein camera allow karein',
    en: 'Camera blocked — allow camera in app / browser settings',
  },
  statusCamError: {
    hi: 'कैमरा शुरू नहीं हुआ। यह ऐप कैमरा रोक रहा हो सकता है — Chrome में खोलकर देखें',
    hinglish: 'Camera shuru nahi hua. Ye app camera rok raha ho sakta hai — Chrome mein kholkar dekhiye',
    en: 'Camera did not start. This app may be blocking it — try opening in Chrome',
  },
  statusDetectorLoading: { hi: 'चेहरा पहचान लोड हो रही है…', hinglish: 'Face detection load ho raha hai…', en: 'Loading face detection…' },
  statusNoDetector: {
    hi: 'चेहरा पहचान उपलब्ध नहीं — शुरू करने के लिए स्क्रीन छुएँ',
    hinglish: 'Face detection nahi chal raha — shuru karne ke liye screen touch karein',
    en: 'Face detection unavailable — tap the screen to start',
  },
  statusLooking: { hi: 'कैमरा चालू · चेहरा देख रही हूँ', hinglish: 'Camera on · chehra dekh rahi hoon', en: 'Camera on · looking for a face' },
  retryCamera: { hi: 'कैमरा फिर से शुरू करें', hinglish: 'Camera phir se shuru karein', en: 'Retry camera' },

  // Conversation
  greeting: {
    hi: 'नमस्ते! {society} में आपका स्वागत है। मैं आपकी एंट्री में मदद करूँगी।',
    hinglish: 'Namaste! {society} mein aapka swagat hai. Main aapki entry mein madad karungi.',
    en: 'Hello! Welcome to {society}. I will help you with your entry.',
  },
  askName: { hi: 'कृपया अपना पूरा नाम बताइए।', hinglish: 'Kripya apna poora naam bataiye.', en: 'Please tell me your full name.' },
  confirmName: { hi: 'आपका नाम {name} है, सही है?', hinglish: 'Aapka naam {name} hai, sahi hai?', en: 'Your name is {name}, is that right?' },
  askPhone: {
    hi: 'अपना दस अंकों का मोबाइल नंबर बताइए।',
    hinglish: 'Apna das ankon ka mobile number bataiye.',
    en: 'Please say your ten digit mobile number.',
  },
  confirmPhone: { hi: 'आपका नंबर {phone} है, सही है?', hinglish: 'Aapka number {phone} hai, sahi hai?', en: 'Your number is {phone}, is that right?' },
  welcomeBack: { hi: 'फिर से स्वागत है {name} जी!', hinglish: 'Phir se swagat hai {name} ji!', en: 'Welcome back, {name}!' },
  askSameFlat: {
    hi: 'पिछली बार आप फ्लैट {flat} गए थे। क्या आज भी वहीं जाना है?',
    hinglish: 'Pichhli baar aap flat {flat} gaye the. Kya aaj bhi wahin jaana hai?',
    en: 'Last time you visited flat {flat}. Are you going there again today?',
  },
  askFlat: {
    hi: 'आपको किस फ्लैट में जाना है? विंग और फ्लैट नंबर बताइए।',
    hinglish: 'Aapko kis flat mein jaana hai? Wing aur flat number bataiye.',
    en: 'Which flat are you visiting? Please say the wing and flat number.',
  },
  confirmFlat: { hi: 'फ्लैट {flat}, सही है?', hinglish: 'Flat {flat}, sahi hai?', en: 'Flat {flat}, is that right?' },
  flatNotFound: {
    hi: 'फ्लैट {flat} इस सोसाइटी में नहीं मिला। कृपया दोबारा बताइए।',
    hinglish: 'Flat {flat} is society mein nahi mila. Kripya dobara bataiye.',
    en: 'I could not find flat {flat} in this society. Please say it again.',
  },
  askPurpose: {
    hi: 'आप किस काम से आए हैं? जैसे मिलने, डिलीवरी, मरम्मत या मीटिंग।',
    hinglish: 'Aap kis kaam se aaye hain? Jaise milne, delivery, repair ya meeting.',
    en: 'What is the purpose of your visit? For example visit, delivery, repair or meeting.',
  },
  askVehicle: { hi: 'क्या आप गाड़ी से आए हैं?', hinglish: 'Kya aap gaadi se aaye hain?', en: 'Have you come with a vehicle?' },
  askVehicleNumber: { hi: 'गाड़ी का नंबर बताइए।', hinglish: 'Gaadi ka number bataiye.', en: 'Please say the vehicle number.' },
  confirmVehicle: { hi: 'गाड़ी नंबर {vehicle}, सही है?', hinglish: 'Gaadi number {vehicle}, sahi hai?', en: 'Vehicle number {vehicle}, is that right?' },
  summary: {
    hi: 'कृपया स्क्रीन पर अपनी जानकारी देख लीजिए। क्या सब सही है?',
    hinglish: 'Kripya screen par apni jaankari dekh lijiye. Kya sab sahi hai?',
    en: 'Please check your details on the screen. Is everything correct?',
  },
  whichField: {
    hi: 'क्या बदलना है? नाम, नंबर, फ्लैट, काम या गाड़ी?',
    hinglish: 'Kya badalna hai? Naam, number, flat, kaam ya gaadi?',
    en: 'What should I change? Name, number, flat, purpose or vehicle?',
  },
  didNotHear: { hi: 'माफ़ कीजिए, मुझे सुनाई नहीं दिया।', hinglish: 'Maaf kijiye, mujhe sunai nahi diya.', en: "Sorry, I didn't catch that." },
  didNotUnderstand: { hi: 'माफ़ कीजिए, मैं समझ नहीं पाई।', hinglish: 'Maaf kijiye, main samajh nahi paayi.', en: "Sorry, I didn't understand." },
  sayYesNo: { hi: 'कृपया हाँ या ना बोलिए।', hinglish: 'Kripya haan ya na boliye.', en: 'Please say yes or no.' },
  typeInstead: {
    hi: 'कृपया नीचे स्क्रीन पर टाइप कर दीजिए।',
    hinglish: 'Kripya neeche screen par type kar dijiye.',
    en: 'Please type it on the screen below.',
  },
  blacklisted: {
    hi: 'माफ़ कीजिए, आपकी एंट्री अभी नहीं हो सकती। कृपया गार्ड से संपर्क करें।',
    hinglish: 'Maaf kijiye, aapki entry abhi nahi ho sakti. Kripya guard se sampark karein.',
    en: 'Sorry, your entry cannot be completed. Please contact the guard.',
  },
  askingResident: {
    hi: 'फ्लैट {flat} के निवासी से अनुमति ली जा रही है। कृपया थोड़ा इंतज़ार कीजिए।',
    hinglish: 'Flat {flat} ke resident se permission li ja rahi hai. Kripya thoda intezaar kijiye.',
    en: 'Asking the resident of flat {flat} for permission. Please wait a moment.',
  },
  approved: {
    hi: 'निवासी ने अनुमति दे दी है।',
    hinglish: 'Resident ne permission de di hai.',
    en: 'The resident has approved your visit.',
  },
  rejected: {
    hi: 'माफ़ कीजिए, निवासी ने अनुमति नहीं दी। कृपया गार्ड से बात करें।',
    hinglish: 'Maaf kijiye, resident ne permission nahi di. Kripya guard se baat karein.',
    en: 'Sorry, the resident did not approve the visit. Please speak to the guard.',
  },
  approvalTimeout: {
    hi: 'निवासी से जवाब नहीं मिला। कृपया गार्ड से संपर्क करें।',
    hinglish: 'Resident se jawab nahi mila. Kripya guard se sampark karein.',
    en: 'No reply from the resident. Please contact the guard.',
  },
  done: {
    hi: 'धन्यवाद {name} जी! आपकी एंट्री दर्ज हो गई है। आपका दिन शुभ हो।',
    hinglish: 'Dhanyavaad {name} ji! Aapki entry darj ho gayi hai. Aapka din shubh ho.',
    en: 'Thank you, {name}! Your entry has been recorded. Have a nice day.',
  },
  saveFailed: {
    hi: 'माफ़ कीजिए, एंट्री सेव नहीं हो पाई। कृपया गार्ड से संपर्क करें।',
    hinglish: 'Maaf kijiye, entry save nahi ho paayi. Kripya guard se sampark karein.',
    en: 'Sorry, the entry could not be saved. Please contact the guard.',
  },
  sessionEnded: { hi: 'सत्र समाप्त हुआ।', hinglish: 'Session khatam hua.', en: 'Session ended.' },

  // On-screen labels
  youSaid: { hi: 'आपने कहा', hinglish: 'Aapne kaha', en: 'You said' },
  listening: { hi: 'बोलिए… मैं सुन रही हूँ', hinglish: 'Boliye… main sun rahi hoon', en: 'Speak now… I am listening' },
  understood: { hi: 'मैंने समझा', hinglish: 'Maine samjha', en: 'I understood' },
  yes: { hi: 'हाँ, सही है', hinglish: 'Haan, sahi hai', en: 'Yes, correct' },
  no: { hi: 'नहीं', hinglish: 'Nahi', en: 'No' },
  repeat: { hi: 'फिर से बोलें', hinglish: 'Phir se bolein', en: 'Say again' },
  typeIt: { hi: 'टाइप करें', hinglish: 'Type karein', en: 'Type it' },
  submit: { hi: 'आगे बढ़ें', hinglish: 'Aage badhein', en: 'Continue' },
  skip: { hi: 'छोड़ें', hinglish: 'Skip', en: 'Skip' },
  cancelSession: { hi: 'रद्द करें', hinglish: 'Cancel', en: 'Cancel' },
  edit: { hi: 'बदलें', hinglish: 'Badlein', en: 'Change' },
  fieldName: { hi: 'नाम', hinglish: 'Naam', en: 'Name' },
  fieldPhone: { hi: 'मोबाइल', hinglish: 'Mobile', en: 'Mobile' },
  fieldFlat: { hi: 'फ्लैट', hinglish: 'Flat', en: 'Flat' },
  fieldPurpose: { hi: 'काम', hinglish: 'Kaam', en: 'Purpose' },
  fieldVehicle: { hi: 'गाड़ी', hinglish: 'Gaadi', en: 'Vehicle' },
  noVehicle: { hi: 'नहीं', hinglish: 'Nahi', en: 'None' },
  waitingResident: { hi: 'निवासी की अनुमति का इंतज़ार', hinglish: 'Resident ki permission ka intezaar', en: 'Waiting for resident approval' },
  savingEntry: { hi: 'एंट्री दर्ज हो रही है…', hinglish: 'Entry darj ho rahi hai…', en: 'Saving your entry…' },
  noMic: {
    hi: 'माइक की अनुमति नहीं मिली। कृपया टाइप करें या गार्ड को बुलाएँ।',
    hinglish: 'Mic ki permission nahi mili. Kripya type karein ya guard ko bulaiye.',
    en: 'Microphone is blocked. Please type, or call the guard.',
  },
} satisfies Record<string, Copy>;

export type KioskCopyKey = keyof typeof COPY;

const PURPOSE_LABELS: Record<string, Copy> = {
  Visit: { hi: 'मिलने', hinglish: 'Milne', en: 'Visit' },
  Delivery: { hi: 'डिलीवरी', hinglish: 'Delivery', en: 'Delivery' },
  Meeting: { hi: 'मीटिंग', hinglish: 'Meeting', en: 'Meeting' },
  Maintenance: { hi: 'मरम्मत / सर्विस', hinglish: 'Repair / Service', en: 'Maintenance' },
  Guest: { hi: 'मेहमान', hinglish: 'Guest', en: 'Guest' },
  Other: { hi: 'अन्य', hinglish: 'Other', en: 'Other' },
};

function fill(template: string, vars?: Record<string, string>): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (_, k: string) => vars[k] ?? '');
}

/** On-screen text. */
export function kioskText(key: KioskCopyKey, lang: KioskLang, vars?: Record<string, string>): string {
  return fill(COPY[key][lang], vars);
}

/** Text for the voice (Hinglish is voiced from the Devanagari line). */
export function kioskSpeech(key: KioskCopyKey, lang: KioskLang, vars?: Record<string, string>): string {
  return fill(COPY[key][lang === 'hinglish' ? 'hi' : lang], vars);
}

export function purposeLabel(purpose: string, lang: KioskLang): string {
  return PURPOSE_LABELS[purpose]?.[lang] ?? purpose;
}
