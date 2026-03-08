export type Lang = 'en' | 'hi';

const translations: Record<string, Record<Lang, string>> = {
  // Common
  'app.name': { en: 'Evergreen Heights', hi: 'एवरग्रीन हाइट्स' },
  'app.subtitle': { en: 'Society Management System', hi: 'सोसाइटी प्रबंधन प्रणाली' },
  'app.footer': { en: 'Copyright © 2026. Developed By MCSPL with ❤️', hi: 'कॉपीराइट © 2026. MCSPL द्वारा ❤️ से विकसित' },
  'app.loading': { en: 'Loading...', hi: 'लोड हो रहा है...' },
  'common.add': { en: 'Add', hi: 'जोड़ें' },
  'common.save': { en: 'Save', hi: 'सहेजें' },
  'common.cancel': { en: 'Cancel', hi: 'रद्द करें' },
  'common.search': { en: 'Search', hi: 'खोजें' },
  'common.delete': { en: 'Delete', hi: 'हटाएं' },
  'common.exit': { en: 'Exit', hi: 'बाहर' },
  'common.enter': { en: 'Enter', hi: 'प्रवेश' },
  'common.inside': { en: 'Inside', hi: 'अंदर' },
  'common.active': { en: 'Active', hi: 'सक्रिय' },
  'common.name': { en: 'Name', hi: 'नाम' },
  'common.phone': { en: 'Phone', hi: 'फोन' },
  'common.flat': { en: 'Flat', hi: 'फ्लैट' },
  'common.records': { en: 'records', hi: 'रिकॉर्ड' },

  // Login
  'login.guardId': { en: 'Guard ID', hi: 'गार्ड आईडी' },
  'login.password': { en: 'Password', hi: 'पासवर्ड' },
  'login.guardIdPlaceholder': { en: 'e.g. G001', hi: 'जैसे G001' },
  'login.passwordPlaceholder': { en: 'Enter password', hi: 'पासवर्ड दर्ज करें' },
  'login.startShift': { en: 'Start Shift', hi: 'शिफ्ट शुरू करें' },
  'login.loggingIn': { en: 'Logging in...', hi: 'लॉगिन हो रहा है...' },
  'login.invalidCredentials': { en: 'Invalid credentials', hi: 'गलत प्रमाण-पत्र' },
  'login.enterBoth': { en: 'Enter Guard ID and Password', hi: 'गार्ड आईडी और पासवर्ड दर्ज करें' },
  'login.demo': { en: 'Demo: G001 / guard123', hi: 'डेमो: G001 / guard123' },

  // Nav
  'nav.home': { en: 'Home', hi: 'होम' },
  'nav.quick': { en: 'Quick', hi: 'क्विक' },
  'nav.visitor': { en: 'Visitor', hi: 'विज़िटर' },
  'nav.delivery': { en: 'Delivery', hi: 'डिलीवरी' },
  'nav.vehicles': { en: 'Vehicles', hi: 'वाहन' },
  'nav.blacklist': { en: 'Blacklist', hi: 'ब्लैकलिस्ट' },
  'nav.directory': { en: 'Directory', hi: 'डायरेक्टरी' },
  'nav.report': { en: 'Report', hi: 'रिपोर्ट' },
  'nav.logs': { en: 'Logs', hi: 'लॉग्स' },

  // Dashboard
  'dashboard.visitors': { en: 'Visitors', hi: 'आगंतुक' },
  'dashboard.vehicles': { en: 'Vehicles', hi: 'वाहन' },
  'dashboard.deliveries': { en: 'Deliveries', hi: 'डिलीवरी' },
  'dashboard.insideNow': { en: 'Inside Now', hi: 'अभी अंदर' },
  'dashboard.alerts': { en: 'Alerts', hi: 'अलर्ट' },
  'dashboard.recentEntries': { en: 'Recent Entries', hi: 'हाल की एंट्री' },
  'dashboard.noEntries': { en: 'No entries today', hi: 'आज कोई एंट्री नहीं' },
  'dashboard.enteredXToday': { en: 'entered', hi: 'बार आया' },
  'dashboard.today': { en: 'today', hi: 'आज' },

  // Visitor Entry
  'visitor.title': { en: 'New Visitor', hi: 'नया आगंतुक' },
  'visitor.subtitle': { en: 'Quick entry logging', hi: 'त्वरित एंट्री लॉगिंग' },
  'visitor.phoneNumber': { en: 'Phone Number', hi: 'फोन नंबर' },
  'visitor.fullName': { en: 'Full Name', hi: 'पूरा नाम' },
  'visitor.flatNumber': { en: 'Flat / House No.', hi: 'फ्लैट / मकान नं.' },
  'visitor.purpose': { en: 'Purpose', hi: 'उद्देश्य' },
  'visitor.docType': { en: 'Doc Type', hi: 'दस्तावेज़ प्रकार' },
  'visitor.docNumber': { en: 'Doc Number', hi: 'दस्तावेज़ नंबर' },
  'visitor.visitorPhotos': { en: 'Visitor Photos', hi: 'आगंतुक फोटो' },
  'visitor.documentPhoto': { en: 'Document Photo', hi: 'दस्तावेज़ फोटो' },
  'visitor.hasVehicle': { en: 'Has vehicle', hi: 'वाहन है' },
  'visitor.vehicleNumber': { en: 'Vehicle Number', hi: 'वाहन नंबर' },
  'visitor.logEntry': { en: 'Log Entry', hi: 'एंट्री दर्ज करें' },
  'visitor.loggedSuccess': { en: 'Visitor logged successfully', hi: 'आगंतुक सफलतापूर्वक दर्ज' },
  'visitor.blacklisted': { en: 'BLACKLISTED — This visitor is flagged!', hi: 'ब्लैकलिस्टेड — यह आगंतुक चिह्नित है!' },
  'visitor.repeatAlert': { en: 'This visitor has already entered', hi: 'यह आगंतुक पहले ही आ चुका है' },
  'visitor.timesToday': { en: 'x today', hi: 'बार आज' },

  // Purpose options
  'purpose.visit': { en: 'Visit', hi: 'मिलने' },
  'purpose.delivery': { en: 'Delivery', hi: 'डिलीवरी' },
  'purpose.meeting': { en: 'Meeting', hi: 'मीटिंग' },
  'purpose.maintenance': { en: 'Maintenance', hi: 'रखरखाव' },
  'purpose.guest': { en: 'Guest', hi: 'मेहमान' },
  'purpose.other': { en: 'Other', hi: 'अन्य' },

  // Quick Entry
  'quick.title': { en: 'Quick Entry', hi: 'क्विक एंट्री' },
  'quick.subtitle': { en: 'One-tap re-entry for frequent visitors', hi: 'नियमित आगंतुकों के लिए एक-टैप प्रवेश' },
  'quick.searchPlaceholder': { en: 'Search by name, phone, or flat...', hi: 'नाम, फोन, या फ्लैट से खोजें...' },
  'quick.noFrequent': { en: 'No frequent visitors yet. Visitors with 2+ entries will appear here.', hi: 'अभी कोई नियमित आगंतुक नहीं। 2+ बार आने वाले यहां दिखेंगे।' },
  'quick.noMatch': { en: 'No matching frequent visitors', hi: 'कोई मिलता-जुलता आगंतुक नहीं' },
  'quick.visits': { en: 'visits', hi: 'बार आया' },
  'quick.loggedIn': { en: 'logged in', hi: 'प्रवेश दर्ज' },

  // Delivery
  'delivery.title': { en: 'Delivery / Service', hi: 'डिलीवरी / सेवा' },
  'delivery.subtitle': { en: 'Quick entry for deliveries & staff', hi: 'डिलीवरी और कर्मचारियों की त्वरित एंट्री' },
  'delivery.tab.delivery': { en: 'Delivery', hi: 'डिलीवरी' },
  'delivery.tab.service': { en: 'Service', hi: 'सेवा' },
  'delivery.company': { en: 'Company', hi: 'कंपनी' },
  'delivery.serviceType': { en: 'Service Type', hi: 'सेवा प्रकार' },
  'delivery.personName': { en: 'Name', hi: 'नाम' },
  'delivery.personPhoto': { en: 'Person Photo', hi: 'व्यक्ति फोटो' },
  'delivery.vehicleOptional': { en: 'Vehicle Number (optional)', hi: 'वाहन नंबर (वैकल्पिक)' },
  'delivery.success': { en: 'Entry logged successfully', hi: 'एंट्री सफलतापूर्वक दर्ज' },

  // Vehicle Page
  'vehicle.title': { en: 'Vehicles', hi: 'वाहन' },
  'vehicle.subtitle': { en: 'Resident vehicle registry', hi: 'निवासी वाहन रजिस्ट्री' },
  'vehicle.searchPlaceholder': { en: 'Search by vehicle no., flat, name...', hi: 'वाहन नं., फ्लैट, नाम से खोजें...' },
  'vehicle.noVehicles': { en: 'No vehicles registered', hi: 'कोई वाहन पंजीकृत नहीं' },
  'vehicle.flatNo': { en: 'Flat No.', hi: 'फ्लैट नं.' },
  'vehicle.residentName': { en: 'Resident Name', hi: 'निवासी का नाम' },
  'vehicle.saveVehicle': { en: 'Save Vehicle', hi: 'वाहन सहेजें' },

  // Blacklist
  'blacklist.title': { en: 'Blacklist', hi: 'ब्लैकलिस्ट' },
  'blacklist.flagged': { en: 'flagged entries', hi: 'चिह्नित एंट्री' },
  'blacklist.addToBlacklist': { en: 'Add to Blacklist', hi: 'ब्लैकलिस्ट में जोड़ें' },
  'blacklist.addedSuccess': { en: 'Added to blacklist', hi: 'ब्लैकलिस्ट में जोड़ा गया' },
  'blacklist.searchPlaceholder': { en: 'Search blacklist...', hi: 'ब्लैकलिस्ट खोजें...' },
  'blacklist.empty': { en: 'Blacklist is empty', hi: 'ब्लैकलिस्ट खाली है' },
  'blacklist.noMatch': { en: 'No matching entries', hi: 'कोई मिलती एंट्री नहीं' },
  'blacklist.removeConfirm': { en: 'Remove from blacklist?', hi: 'ब्लैकलिस्ट से हटाएं?' },
  'blacklist.reason': { en: 'Reason', hi: 'कारण' },
  'blacklist.visitor': { en: 'Visitor', hi: 'आगंतुक' },
  'blacklist.vehicle': { en: 'Vehicle', hi: 'वाहन' },

  // Directory
  'directory.title': { en: 'Directory', hi: 'डायरेक्टरी' },
  'directory.registeredVisitors': { en: 'registered visitors', hi: 'पंजीकृत आगंतुक' },
  'directory.searchPlaceholder': { en: 'Search name, phone, flat, vehicle...', hi: 'नाम, फोन, फ्लैट, वाहन खोजें...' },
  'directory.noVisitors': { en: 'No visitors found', hi: 'कोई आगंतुक नहीं मिला' },
  'directory.category': { en: 'Category', hi: 'श्रेणी' },
  'directory.document': { en: 'Document', hi: 'दस्तावेज़' },
  'directory.firstVisit': { en: 'First visit', hi: 'पहली विज़िट' },
  'directory.lastVisit': { en: 'Last visit', hi: 'अंतिम विज़िट' },

  // Logs
  'logs.title': { en: 'Logs', hi: 'लॉग्स' },
  'logs.subtitle': { en: 'Search & export records', hi: 'रिकॉर्ड खोजें और निर्यात करें' },
  'logs.searchPlaceholder': { en: 'Name, phone, flat, vehicle, guard...', hi: 'नाम, फोन, फ्लैट, वाहन, गार्ड...' },
  'logs.noRecords': { en: 'No records found', hi: 'कोई रिकॉर्ड नहीं मिला' },
  'logs.all': { en: 'All', hi: 'सभी' },
  'logs.guard': { en: 'Guard', hi: 'गार्ड' },

  // Report
  'report.title': { en: 'Daily Report', hi: 'दैनिक रिपोर्ट' },
  'report.subtitle': { en: 'Summary & export', hi: 'सारांश और निर्यात' },
  'report.guardShifts': { en: 'Guard Shifts', hi: 'गार्ड शिफ्ट' },
  'report.noShifts': { en: 'No shifts recorded', hi: 'कोई शिफ्ट दर्ज नहीं' },
  'report.entries': { en: 'Entries', hi: 'एंट्री' },
  'report.noEntries': { en: 'No entries for this date', hi: 'इस तारीख की कोई एंट्री नहीं' },
  'report.more': { en: 'more — use Print/CSV for full list', hi: 'और — पूरी सूची के लिए प्रिंट/CSV उपयोग करें' },
  'report.flatsVisited': { en: 'Flats Visited', hi: 'फ्लैट विज़िट' },
  'report.print': { en: 'Print', hi: 'प्रिंट' },
};

export default translations;
