/// Mobile-only UI strings (keys the web app does not have). Each feature module keeps
/// its own map in `extra/<module>_strings.dart`; they are merged here.
/// Web keys always win: these only fill gaps.
const Map<String, Map<String, String>> kExtraStrings = {
  'mobile.retry': {'en': 'Retry', 'hi': 'फिर से'},
  'mobile.loadFailed': {'en': 'Could not load. Check your internet and try again.', 'hi': 'लोड नहीं हो पाया। इंटरनेट जाँचें और फिर से कोशिश करें।'},
  'mobile.empty': {'en': 'Nothing here yet', 'hi': 'अभी यहाँ कुछ नहीं है'},
  'mobile.saved': {'en': 'Saved', 'hi': 'सहेजा गया'},
  'mobile.more': {'en': 'More', 'hi': 'और'},
  'mobile.search': {'en': 'Search…', 'hi': 'खोजें…'},
  'mobile.close': {'en': 'Close', 'hi': 'बंद करें'},
  'mobile.confirm': {'en': 'Confirm', 'hi': 'पुष्टि करें'},
  'mobile.share': {'en': 'Share', 'hi': 'साझा करें'},
  'mobile.exportPdf': {'en': 'Export PDF', 'hi': 'PDF निर्यात'},
  'mobile.exportExcel': {'en': 'Export Excel', 'hi': 'Excel निर्यात'},
  'mobile.exportCsv': {'en': 'Export CSV', 'hi': 'CSV निर्यात'},
  'mobile.theme.light': {'en': 'Light', 'hi': 'लाइट'},
  'mobile.theme.dark': {'en': 'Dark', 'hi': 'डार्क'},
  'mobile.theme.system': {'en': 'System', 'hi': 'सिस्टम'},
};
