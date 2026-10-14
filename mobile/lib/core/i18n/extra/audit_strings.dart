/// Strings for the Audit and Fixed Assets admin modules (AUDIT agent).
/// `audit.title` is referenced by the web (`t('audit.title') || 'Security Audit Logs'`) but missing
/// from the web translation table; the rest are mobile-only keys used with inline fallbacks.
const Map<String, Map<String, String>> kAuditStrings = {
  'audit.title': {'en': 'Security Audit Logs', 'hi': 'सुरक्षा ऑडिट लॉग'},
  'fixedAssets.title': {'en': 'Fixed Assets', 'hi': 'स्थिर संपत्ति'},
  'fixedAssets.subtitle': {
    'en':
        'Society asset register — builder handover, manual entry, and auto-sync from Finance payments.',
    'hi':
        'सोसाइटी संपत्ति रजिस्टर — बिल्डर हस्तांतरण, मैन्युअल प्रविष्टि, और वित्त भुगतानों से स्वतः सिंक।',
  },
};
