/// Superadmin console strings that the web hard-codes in English (or mobile-only copy).
/// Merged into `kExtraStrings` by the lead; `context.st()` in the module also reads it directly.
const Map<String, Map<String, String>> kSuperadminStrings = {
  // Bottom nav (web hard-coded labels)
  'sa.tab.maintenance': {'en': 'Maintenance', 'hi': 'रखरखाव'},
  'sa.tab.payments': {'en': 'Payments', 'hi': 'भुगतान'},
  'sa.tab.support': {'en': 'Support', 'hi': 'सहायता'},

  // Common
  'sa.copied': {'en': 'Copied', 'hi': 'कॉपी किया गया'},
  'sa.copy': {'en': 'Copy', 'hi': 'कॉपी करें'},
  'sa.refresh': {'en': 'Refresh', 'hi': 'रीफ़्रेश'},
  'sa.loading': {'en': 'Loading…', 'hi': 'लोड हो रहा है…'},
  'sa.noMatches': {'en': 'Nothing matches your search.', 'hi': 'खोज से कुछ मेल नहीं खाता।'},
  'sa.filter.all': {'en': 'All', 'hi': 'सभी'},
  'sa.unsavedTitle': {'en': 'Discard changes?', 'hi': 'बदलाव छोड़ें?'},
  'sa.unsavedText': {'en': 'Your changes have not been saved.', 'hi': 'आपके बदलाव सहेजे नहीं गए हैं।'},
  'sa.pick.gallery': {'en': 'Choose from gallery', 'hi': 'गैलरी से चुनें'},
  'sa.pick.camera': {'en': 'Take a photo', 'hi': 'फोटो लें'},
  'sa.pick.failed': {'en': 'Could not open the image picker', 'hi': 'चित्र चयन नहीं खुल सका'},

  // Login (mobile-only helpers for authenticator enrollment on the same phone)
  'sa.login.openAuthenticator': {'en': 'Open in authenticator', 'hi': 'प्रमाणक ऐप में खोलें'},
  'sa.login.copyKey': {'en': 'Copy secret key', 'hi': 'गुप्त कुंजी कॉपी करें'},
  'sa.login.noAuthenticator': {
    'en': 'No authenticator app found. Copy the secret key and add it manually.',
    'hi': 'कोई प्रमाणक ऐप नहीं मिला। गुप्त कुंजी कॉपी करके स्वयं जोड़ें।',
  },
  'sa.login.sameDeviceHint': {
    'en': 'Setting up on this phone? Tap "Open in authenticator" or copy the key instead of scanning.',
    'hi': 'इसी फोन पर सेटअप? स्कैन के बजाय "प्रमाणक ऐप में खोलें" दबाएँ या कुंजी कॉपी करें।',
  },

  // Societies
  'sa.societies.search': {'en': 'Search name, city, contact, referral…', 'hi': 'नाम, शहर, संपर्क, रेफ़रल खोजें…'},
  'sa.societies.inactive': {'en': 'Inactive', 'hi': 'निष्क्रिय'},
  'sa.societies.deleted': {'en': 'Society deleted', 'hi': 'सोसाइटी हटाई गई'},
  'sa.societies.deleteFailed': {'en': 'Could not delete society', 'hi': 'सोसाइटी हटाई नहीं जा सकी'},
  'sa.societies.nameRequired': {'en': 'Society name is required', 'hi': 'सोसाइटी का नाम आवश्यक है'},
  'sa.societies.activateTitle': {'en': 'Activate society?', 'hi': 'सोसाइटी सक्रिय करें?'},
  'sa.societies.activateText': {
    'en': 'The society will appear on the login screen again and its users can sign in.',
    'hi': 'सोसाइटी फिर से प्रवेश स्क्रीन पर दिखेगी और उसके उपयोगकर्ता प्रवेश कर सकेंगे।',
  },
  'sa.societies.deactivateTitle': {'en': 'Deactivate society?', 'hi': 'सोसाइटी निष्क्रिय करें?'},
  'sa.societies.deactivateText': {
    'en': 'The society is hidden from the login society list. No data is deleted.',
    'hi': 'सोसाइटी प्रवेश सूची से छिप जाएगी। कोई डेटा नहीं हटेगा।',
  },
  'sa.societies.activated': {'en': 'Society activated', 'hi': 'सोसाइटी सक्रिय की गई'},
  'sa.societies.deactivated': {'en': 'Society deactivated', 'hi': 'सोसाइटी निष्क्रिय की गई'},
  'sa.societies.referral': {'en': 'Referral code', 'hi': 'रेफ़रल कोड'},
  'sa.societies.noReferral': {
    'en': 'No referral code yet (societies created by payment get one automatically).',
    'hi': 'अभी कोई रेफ़रल कोड नहीं (भुगतान से बनी सोसाइटी को स्वतः मिलता है)।',
  },
  'sa.societies.generateReferral': {'en': 'Generate referral code', 'hi': 'रेफ़रल कोड बनाएँ'},
  'sa.societies.referralSaved': {'en': 'Referral code saved', 'hi': 'रेफ़रल कोड सहेजा गया'},
  'sa.societies.referralDuplicate': {'en': 'This referral code is already used', 'hi': 'यह रेफ़रल कोड पहले से उपयोग में है'},
  'sa.societies.referralShare': {
    'en': 'Join Kutumbika with referral code {code} ({name}) and get 10% off your society signup.',
    'hi': 'रेफ़रल कोड {code} ({name}) के साथ कुटुम्बिका से जुड़ें और सोसाइटी पंजीकरण पर 10% छूट पाएँ।',
  },
  'sa.details.flats': {'en': 'Flats', 'hi': 'फ्लैट'},
  'sa.details.guards': {'en': 'Guards', 'hi': 'गार्ड'},
  'sa.details.blocks': {'en': 'Blocks / wings', 'hi': 'ब्लॉक / विंग'},
  'sa.details.flatSeries': {'en': 'Flat range', 'hi': 'फ्लैट सीमा'},
  'sa.details.created': {'en': 'Created', 'hi': 'बनाया गया'},
  'sa.details.email': {'en': 'E-mail', 'hi': 'ई-मेल'},
  'sa.details.walletBalance': {'en': 'Wallet balance', 'hi': 'वॉलेट शेष'},
  'sa.details.referrals': {'en': 'Referral rewards', 'hi': 'रेफ़रल पुरस्कार'},

  // Roles & permissions
  'sa.roles.newRoleHint': {
    'en': 'New roles start locked down (Finance, Directory, Password, Biometric). Tap a role to edit its permissions.',
    'hi': 'नई भूमिकाएँ सीमित अनुमति से शुरू होती हैं (वित्त, निर्देशिका, कूटशब्द, जैवमितीय)। अनुमति बदलने के लिए भूमिका दबाएँ।',
  },
  'sa.roles.modules': {'en': '{on}/{total} permissions', 'hi': '{on}/{total} अनुमतियाँ'},
  'sa.roles.adminsCount': {'en': '{count} admin(s)', 'hi': '{count} प्रशासक'},
  'sa.roles.editPermissions': {'en': 'Edit permissions', 'hi': 'अनुमतियाँ बदलें'},
  'sa.roles.deleted': {'en': 'Role deleted', 'hi': 'भूमिका हटाई गई'},
  'sa.roles.deleteFailed': {'en': 'Could not delete role', 'hi': 'भूमिका हटाई नहीं जा सकी'},
  'sa.roles.deleteInUse': {
    'en': '{count} admin(s) use this role. They will be left without a role, which means full (legacy) access.',
    'hi': '{count} प्रशासक यह भूमिका उपयोग करते हैं। वे बिना भूमिका के रहेंगे, यानी पूर्ण (पुरानी) पहुँच।',
  },
  'sa.roles.permissionsTitle': {'en': 'Role permissions', 'hi': 'भूमिका अनुमतियाँ'},
  'sa.roles.presets': {'en': 'Presets', 'hi': 'प्रीसेट'},
  'sa.roles.presetFull': {'en': 'Full access (Admin)', 'hi': 'पूर्ण पहुँच (प्रशासक)'},
  'sa.roles.presetNew': {'en': 'New role default', 'hi': 'नई भूमिका डिफ़ॉल्ट'},
  'sa.roles.presetNewHint': {'en': 'Finance, Directory, Password, Biometric', 'hi': 'वित्त, निर्देशिका, कूटशब्द, जैवमितीय'},
  'sa.roles.presetNone': {'en': 'No modules', 'hi': 'कोई खंड नहीं'},
  'sa.roles.presetSeeded': {'en': 'Standard committee role', 'hi': 'मानक समिति भूमिका'},
  'sa.roles.roleName': {'en': 'Role name', 'hi': 'भूमिका का नाम'},
  'sa.roles.matrixHint': {
    'en': '{on} of {total} permissions on. Changes apply when the admin next signs in or reopens the app.',
    'hi': '{total} में से {on} अनुमतियाँ चालू। बदलाव प्रशासक के अगले प्रवेश या ऐप दोबारा खोलने पर लागू होंगे।',
  },
  'sa.roles.allInGroup': {'en': 'All', 'hi': 'सभी'},
  'sa.roles.noneInGroup': {'en': 'None', 'hi': 'कोई नहीं'},
  'sa.roles.visibleTabs': {'en': 'Admin tabs this role can open', 'hi': 'यह भूमिका कौन-से खंड खोल सकती है'},
  'sa.roles.appliesNextLogin': {
    'en': 'Admins without a role keep full access (legacy behaviour).',
    'hi': 'बिना भूमिका वाले प्रशासकों के पास पूर्ण पहुँच रहती है (पुराना व्यवहार)।',
  },
  'sa.roles.saved': {'en': 'Role saved', 'hi': 'भूमिका सहेजी गई'},
  'sa.roles.saveFailed': {'en': 'Could not save role', 'hi': 'भूमिका सहेजी नहीं जा सकी'},
  'sa.permGroup.people': {'en': 'People & access', 'hi': 'लोग और पहुँच'},
  'sa.permGroup.finance': {'en': 'Finance', 'hi': 'वित्त'},
  'sa.permGroup.governance': {'en': 'Governance', 'hi': 'शासन'},
  'sa.permGroup.community': {'en': 'Notifications & parking', 'hi': 'सूचनाएँ और पार्किंग'},
  'sa.permGroup.gate': {'en': 'Gate operations', 'hi': 'द्वार संचालन'},
  'sa.permGroup.reports': {'en': 'Reports & audit', 'hi': 'प्रतिवेदन और लेखा-परीक्षा'},
  'sa.permGroup.account': {'en': 'Account', 'hi': 'खाता'},
  'sa.perm.splits': {'en': 'Expense splits', 'hi': 'खर्च बँटवारा'},
  'sa.perm.splitsHint': {'en': 'Also opens when Events is on', 'hi': 'आयोजन चालू होने पर भी खुलता है'},
  'sa.perm.rwHint': {'en': 'Read & write', 'hi': 'पढ़ना और बदलना'},

  // Admins
  'sa.admins.add': {'en': 'Add admin', 'hi': 'प्रशासक जोड़ें'},
  'sa.admins.edit': {'en': 'Edit admin', 'hi': 'प्रशासक संपादित करें'},
  'sa.admins.search': {'en': 'Search name, admin ID, e-mail…', 'hi': 'नाम, प्रशासक पहचान, ई-मेल खोजें…'},
  'sa.admins.allSocieties': {'en': 'Show admins of all societies', 'hi': 'सभी सोसाइटी के प्रशासक दिखाएँ'},
  'sa.admins.allSocietiesHint': {'en': 'Includes admins without a society', 'hi': 'बिना सोसाइटी वाले प्रशासक भी'},
  'sa.admins.fullAccess': {'en': 'No role · full access', 'hi': 'कोई भूमिका नहीं · पूर्ण पहुँच'},
  'sa.admins.noSociety': {'en': 'No society', 'hi': 'कोई सोसाइटी नहीं'},
  'sa.admins.noRoleHint': {
    'en': 'Without a role the admin gets full access to every module.',
    'hi': 'बिना भूमिका के प्रशासक को हर खंड की पूर्ण पहुँच मिलती है।',
  },
  'sa.admins.required': {'en': 'Name, admin ID, password and society are required', 'hi': 'नाम, प्रशासक पहचान, कूटशब्द और सोसाइटी आवश्यक हैं'},
  'sa.admins.duplicateId': {'en': 'This admin ID is already taken', 'hi': 'यह प्रशासक पहचान पहले से उपयोग में है'},
  'sa.admins.saveFailed': {'en': 'Could not save admin', 'hi': 'प्रशासक सहेजा नहीं जा सका'},
  'sa.admins.updated': {'en': 'Admin updated', 'hi': 'प्रशासक अपडेट किया गया'},
  'sa.admins.deleted': {'en': 'Admin deleted', 'hi': 'प्रशासक हटाया गया'},
  'sa.admins.deleteFailed': {'en': 'Could not delete admin', 'hi': 'प्रशासक हटाया नहीं जा सका'},
  'sa.admins.resetPassword': {'en': 'Reset password', 'hi': 'कूटशब्द रीसेट करें'},
  'sa.admins.setPassword': {'en': 'Set new password', 'hi': 'नया कूटशब्द सेट करें'},
  'sa.admins.generate': {'en': 'Generate', 'hi': 'बनाएँ'},
  'sa.admins.shareCredentials': {
    'en': 'Your Kutumbika admin login\nAdmin ID: {id}\nPassword: {password}',
    'hi': 'आपका कुटुम्बिका प्रशासक प्रवेश\nप्रशासक पहचान: {id}\nकूटशब्द: {password}',
  },

  // Maintenance
  'sa.maint.title': {'en': 'Data Maintenance', 'hi': 'डेटा रखरखाव'},
  'sa.maint.backupTitle': {'en': 'Backup Export', 'hi': 'बैकअप निर्यात'},
  'sa.maint.backupText': {
    'en':
        'Download JSON backups of app tables (includes support tickets, approvals, audit logs, and all society data). Manual exports always return a file; emailed backups use Resend when RESEND_API_KEY is set on Supabase.',
    'hi':
        'ऐप तालिकाओं का JSON बैकअप लें (सहायता टिकट, अनुमोदन, ऑडिट लॉग और सभी सोसाइटी डेटा सहित)। मैनुअल निर्यात हमेशा फ़ाइल देता है; ई-मेल बैकअप Supabase पर RESEND_API_KEY होने पर Resend से जाता है।',
  },
  'sa.maint.exportAll': {'en': 'Export All Societies Backup', 'hi': 'सभी सोसाइटी का बैकअप निर्यात'},
  'sa.maint.exportComplete': {'en': 'Complete Database Export', 'hi': 'पूर्ण डेटाबेस निर्यात'},
  'sa.maint.exportOne': {'en': 'Export {name} Only', 'hi': 'केवल {name} निर्यात करें'},
  'sa.maint.emailNow': {'en': 'Email full backup now (test / manual)', 'hi': 'पूरा बैकअप अभी ई-मेल करें (परीक्षण / मैनुअल)'},
  'sa.maint.exporting': {'en': 'Exporting...', 'hi': 'निर्यात हो रहा है...'},
  'sa.maint.emailed': {'en': 'Backup emailed (check inbox and spam).', 'hi': 'बैकअप ई-मेल हुआ (इनबॉक्स और स्पैम देखें)।'},
  'sa.maint.notEmailed': {
    'en': 'Backup was not emailed. Set RESEND_API_KEY on the project or check function logs.',
    'hi': 'बैकअप ई-मेल नहीं हुआ। प्रोजेक्ट पर RESEND_API_KEY सेट करें या फ़ंक्शन लॉग देखें।',
  },
  'sa.maint.unexpected': {
    'en': 'Unexpected export response. Deploy the latest backup-export Edge Function (JSON envelope with { backup }).',
    'hi': 'अप्रत्याशित निर्यात उत्तर। नवीनतम backup-export Edge Function डिप्लॉय करें ({ backup } वाला JSON)।',
  },
  'sa.maint.downloaded': {'en': 'Backup ready — choose where to save or share it.', 'hi': 'बैकअप तैयार — सहेजने या साझा करने की जगह चुनें।'},
  'sa.maint.lastExport': {'en': 'Last export', 'hi': 'पिछला निर्यात'},
  'sa.maint.society': {'en': 'Society', 'hi': 'सोसाइटी'},
  'sa.maint.tables': {'en': 'Tables', 'hi': 'तालिकाएँ'},
  'sa.maint.records': {'en': 'Records', 'hi': 'अभिलेख'},
  'sa.maint.size': {'en': 'Size', 'hi': 'आकार'},
  'sa.maint.exportedAt': {'en': 'Exported at', 'hi': 'निर्यात समय'},
  'sa.maint.deployHint': {
    'en':
        'If the export fails with 404 on backup-export, the function is not deployed to the Supabase project behind this app. From the repo: supabase functions deploy backup-export',
    'hi':
        'यदि backup-export पर 404 त्रुटि आए, तो यह फ़ंक्शन इस ऐप के Supabase प्रोजेक्ट में डिप्लॉय नहीं है। रिपो से चलाएँ: supabase functions deploy backup-export',
  },
  'sa.maint.autoBackupHint': {
    'en':
        'Auto-backup email: set RESEND_API_KEY and BACKUP_EMAIL (optional; defaults to meit10swami@gmail.com), then schedule the backup-export function in the Supabase Dashboard with body {"send_email":true} on your desired cadence (e.g. twice a month). Large backups email a summary without an attachment.',
    'hi':
        'स्वतः बैकअप ई-मेल: RESEND_API_KEY और BACKUP_EMAIL सेट करें (वैकल्पिक; डिफ़ॉल्ट meit10swami@gmail.com), फिर Supabase डैशबोर्ड में backup-export फ़ंक्शन को {"send_email":true} बॉडी के साथ शेड्यूल करें (जैसे महीने में दो बार)। बड़े बैकअप में बिना अटैचमेंट सारांश भेजा जाता है।',
  },
  'sa.maint.dangerZone': {'en': 'Danger Zone', 'hi': 'खतरनाक क्षेत्र'},
  'sa.maint.dangerText': {
    'en':
        'Clear all dummy/test data to start fresh with real production data. This will delete all visitors, flats, members, vehicles, blacklist entries, and guard shift logs. This cannot be undone!',
    'hi':
        'असली डेटा से नई शुरुआत के लिए सारा परीक्षण डेटा हटाएँ। इससे सभी आगंतुक, फ्लैट, सदस्य, वाहन, काली सूची और गार्ड पारी लॉग हट जाएँगे। यह पूर्ववत नहीं होगा!',
  },
  'sa.maint.clearButton': {'en': 'Clear All Data & Go Production', 'hi': 'सारा डेटा हटाएँ और प्रोडक्शन शुरू करें'},
  'sa.maint.clearTitle': {'en': 'Clear All Data?', 'hi': 'सारा डेटा हटाएँ?'},
  'sa.maint.clearText': {
    'en':
        'This will permanently delete ALL visitors, flats, members, vehicles, blacklist entries, and shift logs. This cannot be undone!',
    'hi': 'इससे सभी आगंतुक, फ्लैट, सदस्य, वाहन, काली सूची और पारी लॉग स्थायी रूप से हट जाएँगे। यह पूर्ववत नहीं होगा!',
  },
  'sa.maint.clearConfirm': {'en': 'Yes, clear everything', 'hi': 'हाँ, सब हटाएँ'},
  'sa.maint.typeClearTitle': {'en': 'Type CLEAR to confirm', 'hi': 'पुष्टि के लिए CLEAR लिखें'},
  'sa.maint.typeClearText': {
    'en': 'This affects every society on the platform.',
    'hi': 'इसका असर मंच की हर सोसाइटी पर होगा।',
  },
  'sa.maint.typeClearMismatch': {'en': 'Not cleared — confirmation text did not match.', 'hi': 'नहीं हटाया — पुष्टि शब्द मेल नहीं खाया।'},
  'sa.maint.cleared': {
    'en': 'All dummy data has been cleared. Ready for production!',
    'hi': 'सारा परीक्षण डेटा हटा दिया गया। प्रोडक्शन के लिए तैयार!',
  },
  'sa.maint.clearFailed': {'en': 'Could not clear all data.', 'hi': 'सारा डेटा हटाया नहीं जा सका।'},

  // Payments (onboarding)
  'sa.pay.title': {'en': 'Payments (onboarding)', 'hi': 'भुगतान (ऑनबोर्डिंग)'},
  'sa.pay.empty': {'en': 'No payment orders found.', 'hi': 'कोई भुगतान ऑर्डर नहीं मिला।'},
  'sa.pay.search': {'en': 'Search society, phone, order…', 'hi': 'सोसाइटी, फोन, ऑर्डर खोजें…'},
  'sa.pay.orders': {'en': 'Orders', 'hi': 'ऑर्डर'},
  'sa.pay.ordersInfo': {
    'en': 'PhonePe orders created by the public "Create your society" signup (latest 200).',
    'hi': 'सार्वजनिक "अपनी सोसाइटी बनाएं" पंजीकरण से बने फ़ोनपे ऑर्डर (नवीनतम 200)।',
  },
  'sa.pay.collected': {'en': 'Collected', 'hi': 'प्राप्त'},
  'sa.pay.collectedInfo': {
    'en': 'Sum of amount_inr for orders whose status is success.',
    'hi': 'सफल स्थिति वाले ऑर्डरों की राशि का योग।',
  },
  'sa.pay.signup': {'en': 'Signup', 'hi': 'पंजीकरण'},
  'sa.pay.order': {'en': 'Order', 'hi': 'ऑर्डर'},
  'sa.pay.signupStatus': {'en': 'Signup status', 'hi': 'पंजीकरण स्थिति'},
  'sa.pay.orderStatus': {'en': 'Order status', 'hi': 'ऑर्डर स्थिति'},
  'sa.pay.amount': {'en': 'Amount', 'hi': 'राशि'},
  'sa.pay.provider': {'en': 'Provider', 'hi': 'प्रदाता'},
  'sa.pay.referralUsed': {'en': 'Referral code used', 'hi': 'उपयोग किया गया रेफ़रल कोड'},
  'sa.pay.merchantOrder': {'en': 'Merchant order', 'hi': 'मर्चेंट ऑर्डर'},
  'sa.pay.signupCreated': {'en': 'Signup created', 'hi': 'पंजीकरण बना'},
  'sa.pay.copyOrder': {'en': 'Copy merchant order ID', 'hi': 'मर्चेंट ऑर्डर आईडी कॉपी करें'},

  // Settings
  'sa.set.totpTitle': {'en': 'Authenticator App (TOTP)', 'hi': 'प्रमाणक ऐप (TOTP)'},
  'sa.set.totpText': {'en': 'Turn on/off 2-step verification for Superadmin login.', 'hi': 'सुपर प्रशासक प्रवेश के लिए 2-चरण सत्यापन चालू/बंद करें।'},
  'sa.set.enabled': {'en': 'Enabled', 'hi': 'चालू'},
  'sa.set.disabled': {'en': 'Disabled', 'hi': 'बंद'},
  'sa.set.totpConfigured': {'en': 'Authenticator is currently configured.', 'hi': 'प्रमाणक अभी कॉन्फ़िगर है।'},
  'sa.set.totpNotConfigured': {'en': 'No authenticator secret configured yet.', 'hi': 'अभी कोई प्रमाणक कुंजी कॉन्फ़िगर नहीं है।'},
  'sa.set.totpPending': {
    'en': 'Enabled but not configured yet. You will be asked to scan QR and verify code on next Superadmin login.',
    'hi': 'चालू है पर कॉन्फ़िगर नहीं। अगले सुपर प्रशासक प्रवेश पर क्यूआर स्कैन और कोड सत्यापन माँगा जाएगा।',
  },
  'sa.set.disableTotpTitle': {'en': 'Disable Authenticator?', 'hi': 'प्रमाणक बंद करें?'},
  'sa.set.disableTotpText': {
    'en': 'This will turn off authenticator verification and remove current authenticator setup for Superadmin.',
    'hi': 'इससे प्रमाणक सत्यापन बंद होगा और सुपर प्रशासक का वर्तमान प्रमाणक सेटअप हट जाएगा।',
  },
  'sa.set.disable': {'en': 'Disable', 'hi': 'बंद करें'},
  'sa.set.totpUpdateFailed': {'en': 'Could not update authenticator setting', 'hi': 'प्रमाणक सेटिंग अपडेट नहीं हो सकी'},
  'sa.set.totpEnabled': {
    'en': 'Authenticator enabled. Complete setup on next Superadmin login.',
    'hi': 'प्रमाणक चालू। अगले सुपर प्रशासक प्रवेश पर सेटअप पूरा करें।',
  },
  'sa.set.totpDisabled': {'en': 'Authenticator disabled for Superadmin.', 'hi': 'सुपर प्रशासक के लिए प्रमाणक बंद।'},
  'sa.set.devices': {'en': 'devices', 'hi': 'उपकरण'},
  'sa.set.device': {'en': 'Device', 'hi': 'उपकरण'},
  'sa.set.thisDevice': {'en': 'this phone', 'hi': 'यह फोन'},
  'sa.set.added': {'en': 'Added', 'hi': 'जोड़ा'},
  'sa.set.remove': {'en': 'Remove', 'hi': 'हटाएँ'},
  'sa.set.removing': {'en': 'Removing...', 'hi': 'हटाया जा रहा है...'},
  'sa.set.deviceRemoved': {'en': 'Biometric device removed', 'hi': 'जैवमितीय उपकरण हटाया गया'},
  'sa.set.deviceRemoveFailed': {'en': 'Could not remove biometric device', 'hi': 'जैवमितीय उपकरण हटाया नहीं जा सका'},
  'sa.set.maxDevices': {
    'en': 'Max {max} biometrics reached. Adding one more will replace the oldest device.',
    'hi': 'अधिकतम {max} जैवमितीय हो चुके। एक और जोड़ने पर सबसे पुराना उपकरण बदल जाएगा।',
  },
  'sa.set.appPrefs': {'en': 'App preferences', 'hi': 'ऐप प्राथमिकताएँ'},
  'sa.set.language': {'en': 'Language', 'hi': 'भाषा'},
  'sa.set.theme': {'en': 'Theme', 'hi': 'थीम'},

  // Colour picker
  'sa.color.hue': {'en': 'Hue', 'hi': 'रंगत'},
  'sa.color.saturation': {'en': 'Saturation', 'hi': 'गहनता'},
  'sa.color.brightness': {'en': 'Brightness', 'hi': 'चमक'},
  'sa.color.use': {'en': 'Use colour', 'hi': 'रंग चुनें'},

  // Support tickets
  'sa.tickets.title': {'en': 'Support tickets', 'hi': 'सहायता टिकट'},
  'sa.tickets.intro': {
    'en':
        'New resident feedback appears here with ticket numbers #1, #2, … Email alerts go to the configured developer inbox when Resend is set on the Edge Function.',
    'hi':
        'नई निवासी प्रतिक्रिया यहाँ टिकट संख्या #1, #2, … के साथ दिखती है। Edge Function पर Resend सेट होने पर ई-मेल अलर्ट डेवलपर इनबॉक्स में जाते हैं।',
  },
  'sa.tickets.empty': {'en': 'No tickets yet.', 'hi': 'अभी कोई टिकट नहीं।'},
  'sa.tickets.status': {'en': 'Status', 'hi': 'स्थिति'},
  'sa.tickets.pending': {'en': 'Pending', 'hi': 'लंबित'},
  'sa.tickets.resolved': {'en': 'Resolved', 'hi': 'हल हुआ'},
  'sa.tickets.futureUpdate': {'en': 'Future update', 'hi': 'आगामी अपडेट'},
  'sa.tickets.statusUpdated': {'en': 'Status updated', 'hi': 'स्थिति अपडेट हुई'},
  'sa.tickets.message': {'en': 'Message', 'hi': 'संदेश'},
  'sa.tickets.voice': {'en': 'Voice', 'hi': 'आवाज़'},
  'sa.tickets.media': {'en': 'Media', 'hi': 'मीडिया'},
  'sa.tickets.lastReply': {'en': 'Last reply', 'hi': 'पिछला उत्तर'},
  'sa.tickets.replyLabel': {'en': 'Reply to resident (push + in-app)', 'hi': 'निवासी को उत्तर (पुश + ऐप में)'},
  'sa.tickets.replyHint': {'en': 'Your reply…', 'hi': 'आपका उत्तर…'},
  'sa.tickets.send': {'en': 'Send reply', 'hi': 'उत्तर भेजें'},
  'sa.tickets.sending': {'en': 'Sending…', 'hi': 'भेजा जा रहा है…'},
  'sa.tickets.enterReply': {'en': 'Enter a reply message', 'hi': 'उत्तर संदेश लिखें'},
  'sa.tickets.missingTarget': {'en': 'Ticket is missing society or submitter', 'hi': 'टिकट में सोसाइटी या भेजने वाला नहीं है'},
  'sa.tickets.replySent': {'en': 'Reply sent (in-app + push to that resident)', 'hi': 'उत्तर भेजा गया (उस निवासी को ऐप में + पुश)'},
};
