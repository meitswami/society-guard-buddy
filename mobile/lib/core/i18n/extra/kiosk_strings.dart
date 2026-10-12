/// Mobile-only strings of the AI kiosk (KIOSK module). The web `kiosk.*` keys come
/// from `assets/i18n/translations.json`; these replace web lines that talk about
/// Chrome / browser wrappers, which do not apply to the native app.
const Map<String, Map<String, String>> kKioskStrings = {
  'kiosk.mobile.speechMissing': {
    'en': 'Speech recognition needs Google speech services (the Google app) and an internet connection. Visitors can still type.',
    'hi': 'आवाज़ पहचान के लिए Google स्पीच सेवा (Google ऐप) और इंटरनेट चाहिए। आगंतुक फिर भी टाइप कर सकते हैं।',
  },
  'kiosk.mobile.micDenied': {
    'en': 'Microphone permission is off — allow it in Android Settings → Apps → Kutumbika → Permissions. Visitors can still type.',
    'hi': 'माइक्रोफ़ोन की अनुमति बंद है — Android सेटिंग → ऐप्स → Kutumbika → अनुमतियाँ में चालू करें। आगंतुक फिर भी टाइप कर सकते हैं।',
  },
  'kiosk.mobile.camError': {
    'en': 'Camera did not start. Close other apps using the camera and try again.',
    'hi': 'कैमरा शुरू नहीं हुआ। कैमरा इस्तेमाल कर रहे दूसरे ऐप बंद करके फिर से कोशिश करें।',
  },
  'kiosk.mobile.camDenied': {
    'en': 'Camera permission blocked. Allow camera for Kutumbika in Android Settings → Apps → Permissions.',
    'hi': 'कैमरे की अनुमति बंद है। Android सेटिंग → ऐप्स → अनुमतियाँ में Kutumbika के लिए कैमरा चालू करें।',
  },
  'kiosk.mobile.retryMic': {'en': 'Check again', 'hi': 'फिर से जाँचें'},
  'kiosk.mobile.retryCamera': {'en': 'Retry camera', 'hi': 'कैमरा फिर से शुरू करें'},
};
