import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import 'audit_ui.dart';

/// Port of `SocietyGovernanceGuide.tsx` (Principal · Purpose · Vision · Planning · Policy), English + Hindi.

typedef _T = (String en, String hi);

class _Block {
  const _Block(this.heading, this.points);
  final _T heading;
  final List<_T> points;
}

class _Section {
  const _Section(this.id, this.icon, this.title, this.subtitle, this.content);
  final String id;
  final IconData icon;
  final _T title;
  final _T subtitle;
  final List<_Block> content;
}

const List<_Section> _sections = [
  _Section('principal', Icons.account_balance_outlined, ('Principal', 'प्रधान (शासी निकाय)'),
      ('Who governs and the authority structure', 'कौन शासन करता है और अधिकार संरचना'), [
    _Block(('Governing Authority', 'शासी प्राधिकरण'), [
      ('The Managing Committee (MC) is the principal governing body elected by the General Body of members.',
          'प्रबंध समिति (MC) सदस्यों की आम सभा द्वारा चुनी गई प्रमुख शासी संस्था है।'),
      ('MC acts as a fiduciary — managing society assets, funds, and operations on behalf of all members.',
          'MC एक न्यासी की तरह कार्य करती है — सभी सदस्यों की ओर से सोसाइटी की संपत्ति, धन और संचालन का प्रबंधन करती है।'),
      ('All decisions must be traceable to either MC resolution, General Body resolution, or bye-law authority.',
          'हर निर्णय MC प्रस्ताव, आम सभा प्रस्ताव, या उपनियम के अधिकार से जुड़ा होना चाहिए।'),
      ('The Treasurer is the custodian of funds; the Secretary is the custodian of records.',
          'कोषाध्यक्ष धन का संरक्षक है; सचिव अभिलेखों का संरक्षक है।'),
    ]),
    _Block(('Accountability Chain', 'जवाबदेही श्रृंखला'), [
      ('General Body → Managing Committee → Office Bearers → Admin Staff → Guards/Vendors.',
          'आम सभा → प्रबंध समिति → पदाधिकारी → प्रशासनिक कर्मचारी → गार्ड/विक्रेता।'),
      ('Every financial transaction must have an identifiable recorder (admin) and approver (office bearer).',
          'हर वित्तीय लेन-देन का एक पहचान योग्य दर्ज करने वाला (एडमिन) और अनुमोदक (पदाधिकारी) होना चाहिए।'),
      ('This app enforces accountability by logging who recorded, verified, or rejected each entry.',
          'यह ऐप हर प्रविष्टि को किसने दर्ज, सत्यापित या अस्वीकार किया, यह लॉग करके जवाबदेही सुनिश्चित करता है।'),
      ('Audit trail in this section provides non-repudiation — actions cannot be denied after the fact.',
          'इस खंड का ऑडिट ट्रेल अस्वीकार्यता-रोधी है — किए गए कार्यों से बाद में इनकार नहीं किया जा सकता।'),
    ]),
  ]),
  _Section('purpose', Icons.track_changes_outlined, ('Purpose', 'उद्देश्य'),
      ('Why this system exists and what it solves', 'यह प्रणाली क्यों है और क्या हल करती है'), [
    _Block(('Core Purpose', 'मुख्य उद्देश्य'), [
      ('Transparent financial management — every rupee collected and spent is recorded and visible.',
          'पारदर्शी वित्तीय प्रबंधन — एकत्र और खर्च किया गया हर रुपया दर्ज और दृश्य है।'),
      ('Eliminate manual register errors — digital records prevent overwriting, backdating, and loss.',
          'हाथ के रजिस्टर की गलतियाँ खत्म करें — डिजिटल रिकॉर्ड ओवरराइटिंग, पिछली तारीख और खोने से बचाते हैं।'),
      ('Real-time audit capability — detect discrepancies immediately, not months later.',
          'तत्काल ऑडिट क्षमता — असंगतियाँ महीनों बाद नहीं, तुरंत पकड़ें।'),
      ('Member trust — residents can see where their maintenance money goes.',
          'सदस्यों का विश्वास — निवासी देख सकते हैं कि उनका रखरखाव शुल्क कहाँ जाता है।'),
    ]),
    _Block(('Problems Addressed', 'हल की गई समस्याएँ'), [
      ('Duplicate maintenance payment rows (same flat credited twice) — Duplicate payment alarms above.',
          'डुप्लिकेट रखरखाव भुगतान पंक्तियाँ (एक ही फ्लैट दो बार जमा) — ऊपर डुप्लिकेट भुगतान अलार्म।'),
      ('Ledger double-count in period reports (extra finance_entries receipt) — Ledger double-count panel above; fix with delete or month alignment.',
          'अवधि रिपोर्ट में लेजर दोहरी गिनती (अतिरिक्त finance_entries रसीद) — ऊपर लेजर दोहरी गिनती पैनल; हटाकर या माह मिलाकर सुधारें।'),
      ('Negative cash/bank balance — flagged by Internal Audit with root cause and fix steps.',
          'ऋणात्मक नकद/बैंक शेष — आंतरिक ऑडिट मूल कारण और सुधार चरणों के साथ चिह्नित करता है।'),
      ('Unverified payments sitting for weeks — audit flags pending entries > 7 days.',
          'हफ्तों से असत्यापित भुगतान — ऑडिट 7 दिन से अधिक लंबित प्रविष्टियाँ चिह्नित करता है।'),
      ('Mismatch between what was recorded vs what is reported — cross-checked automatically.',
          'जो दर्ज हुआ और जो रिपोर्ट हुआ उसमें अंतर — स्वतः जाँचा जाता है।'),
      ('Lack of accountability — every action is logged with user, timestamp, IP, and device.',
          'जवाबदेही की कमी — हर कार्रवाई उपयोगकर्ता, समय, IP और डिवाइस के साथ लॉग होती है।'),
    ]),
  ]),
  _Section('vision', Icons.visibility_outlined, ('Vision', 'दृष्टि'),
      ('Where the society management is headed', 'सोसाइटी प्रबंधन किस दिशा में जा रहा है'), [
    _Block(('Short-Term Vision (Current Year)', 'अल्पकालिक दृष्टि (चालू वर्ष)'), [
      ('Zero manual registers — all financial and visitor records are digital.', 'शून्य हाथ के रजिस्टर — सभी वित्तीय और आगंतुक रिकॉर्ड डिजिटल।'),
      ('100% maintenance collection tracked with receipt-level detail.', '100% रखरखाव संग्रह रसीद-स्तर के विवरण के साथ ट्रैक।'),
      ('Every expense has a head, receipt photo, and approval trail.', 'हर खर्च का एक शीर्ष, रसीद फोटो और अनुमोदन क्रम हो।'),
      ('Monthly auto-generated financial reports sent to all members.', 'सभी सदस्यों को हर माह स्वतः बनी वित्तीय रिपोर्ट भेजी जाए।'),
    ]),
    _Block(('Long-Term Vision', 'दीर्घकालिक दृष्टि'), [
      ('Fully self-auditing system — anomalies detected and flagged in real-time without human intervention.',
          'पूर्णतः स्व-ऑडिट प्रणाली — बिना मानवीय हस्तक्षेप के गड़बड़ियाँ तुरंत पकड़ी और चिह्नित हों।'),
      ("Predictive budgeting — based on historical expense patterns, forecast next quarter's needs.",
          'पूर्वानुमानित बजट — पिछले खर्च के पैटर्न के आधार पर अगली तिमाही की ज़रूरतों का अनुमान।'),
      ('Paperless AGM — resolutions, voting, minutes all digital with e-signatures.',
          'कागज़ रहित वार्षिक आम सभा — प्रस्ताव, मतदान, कार्यवृत्त सब ई-हस्ताक्षर के साथ डिजिटल।'),
      ('Integrated vendor management — payments to vendors tracked end-to-end with GST compliance.',
          'एकीकृत विक्रेता प्रबंधन — विक्रेताओं के भुगतान GST अनुपालन के साथ शुरू से अंत तक ट्रैक।'),
      ('Member self-service — residents view their ledger, download receipts, raise disputes online.',
          'सदस्य स्व-सेवा — निवासी अपना खाता देखें, रसीदें डाउनलोड करें, ऑनलाइन विवाद उठाएँ।'),
    ]),
  ]),
  _Section('planning', Icons.assignment_outlined, ('Planning & Structure', 'योजना और संरचना'),
      ('How the project is organized and maintained', 'परियोजना कैसे व्यवस्थित और संचालित है'), [
    _Block(('Project Structure', 'परियोजना संरचना'), [
      ('Finance Module: All society payments and receipts (maintenance, corpus, pool, vendors, utilities).',
          'वित्त मॉड्यूल: सोसाइटी के सभी भुगतान और रसीदें (रखरखाव, कॉर्पस, पूल, विक्रेता, उपयोगिताएँ)।'),
      ('Events Module: Calendar events + food/catering only — split by adults & kids per flat from Residents data.',
          'कार्यक्रम मॉड्यूल: कैलेंडर कार्यक्रम + केवल भोजन/कैटरिंग — निवासी डेटा से प्रति फ्लैट वयस्क व बच्चों के अनुसार विभाजन।'),
      ('Audit Module: Security logs + Finance alarms + Self-audit engine + Governance guide.',
          'ऑडिट मॉड्यूल: सुरक्षा लॉग + वित्त अलार्म + स्व-ऑडिट इंजन + शासन मार्गदर्शिका।'),
      ('Resident Portal: View committee, pay maintenance, see notices, raise complaints.',
          'निवासी पोर्टल: समिति देखें, रखरखाव भुगतान करें, सूचनाएँ देखें, शिकायत करें।'),
      ('Guard Module: Visitor entry/exit, vehicle tracking, geofence, biometric attendance.',
          'गार्ड मॉड्यूल: आगंतुक प्रवेश/निकास, वाहन ट्रैकिंग, जियोफेंस, बायोमेट्रिक उपस्थिति।'),
      ('Admin Panel: All modules + user management + society settings.', 'एडमिन पैनल: सभी मॉड्यूल + उपयोगकर्ता प्रबंधन + सोसाइटी सेटिंग्स।'),
    ]),
    _Block(('Data Flow & Integrity', 'डेटा प्रवाह और अखंडता'), [
      ('Pool receipts create a finance_entry only; use “Distribute equally to all flats” to create per-flat allocations and maintenance_payment rows when linked to a charge.',
          'पूल रसीदें केवल finance_entry बनाती हैं; शुल्क से जुड़े होने पर प्रति-फ्लैट आवंटन और maintenance_payment पंक्तियाँ बनाने के लिए “सभी फ्लैटों में बराबर बाँटें” का उपयोग करें।'),
      ('Direct flat recordings create maintenance_payment + finance_entry + allocations immediately.',
          'सीधे फ्लैट की प्रविष्टि तुरंत maintenance_payment + finance_entry + आवंटन बनाती है।'),
      ('finance_entry_allocations break down per-flat amounts for multi-flat recordings.',
          'finance_entry_allocations बहु-फ्लैट प्रविष्टियों के लिए प्रति-फ्लैट राशि बाँटते हैं।'),
      ('Expense entries (separate_entry) reduce the balance; receipt entries increase it.',
          'खर्च प्रविष्टियाँ (separate_entry) शेष घटाती हैं; रसीद प्रविष्टियाँ शेष बढ़ाती हैं।'),
      ('Period reports compute: Opening Balance + Receipts − Expenses = Closing Balance.',
          'अवधि रिपोर्ट की गणना: प्रारंभिक शेष + रसीदें − खर्च = अंतिम शेष।'),
      ('The Self-Audit button cross-verifies these relationships and flags any break in the chain.',
          'स्व-ऑडिट बटन इन संबंधों की जाँच करता है और श्रृंखला में किसी भी टूट को चिह्नित करता है।'),
    ]),
    _Block(('Collaboration Guidelines', 'सहयोग दिशानिर्देश'), [
      ('Admin records day-to-day transactions (receipts, expenses, visitor logs).', 'एडमिन रोज़ के लेन-देन (रसीदें, खर्च, आगंतुक लॉग) दर्ज करता है।'),
      ('Treasurer reviews and verifies — especially bank entries and large amounts.', 'कोषाध्यक्ष समीक्षा और सत्यापन करता है — खासकर बैंक प्रविष्टियाँ और बड़ी राशियाँ।'),
      ('Secretary ensures meeting minutes reference financial decisions.', 'सचिव सुनिश्चित करता है कि बैठक के कार्यवृत्त में वित्तीय निर्णयों का उल्लेख हो।'),
      ('Committee members can view reports but cannot modify financial records.', 'समिति सदस्य रिपोर्ट देख सकते हैं पर वित्तीय रिकॉर्ड नहीं बदल सकते।'),
      ('Residents view their own payment history and society-level summaries.', 'निवासी अपना भुगतान इतिहास और सोसाइटी-स्तरीय सारांश देखते हैं।'),
    ]),
  ]),
  _Section('policy', Icons.balance_outlined, ('Policy & Compliance', 'नीति और अनुपालन'),
      ('Rules, standards, and issue resolution', 'नियम, मानक और समस्या समाधान'), [
    _Block(('Financial Policies', 'वित्तीय नीतियाँ'), [
      ('All cash receipts must be recorded on the same day they are collected.', 'सभी नकद रसीदें उसी दिन दर्ज हों जिस दिन एकत्र की गईं।'),
      ('Bank/UPI receipts must be verified against bank statement within 48 hours.', 'बैंक/UPI रसीदें 48 घंटे के भीतर बैंक विवरण से सत्यापित हों।'),
      ('No expense above ₹5,000 without prior MC approval (documented in meeting minutes).',
          '₹5,000 से अधिक का कोई भी खर्च MC की पूर्व स्वीकृति के बिना नहीं (बैठक कार्यवृत्त में दर्ज)।'),
      ('Petty cash limit: ₹2,000 maximum without receipt photo.', 'छोटी नकदी सीमा: रसीद फोटो के बिना अधिकतम ₹2,000।'),
      ('Monthly reconciliation: Cash in hand + Bank balance must match system closing balance.',
          'मासिक मिलान: हाथ में नकद + बैंक शेष, प्रणाली के अंतिम शेष से मेल खाना चाहिए।'),
      ('Any negative balance is a policy violation — must be rectified within 24 hours of detection.',
          'कोई भी ऋणात्मक शेष नीति उल्लंघन है — पता चलने के 24 घंटे में सुधारना होगा।'),
    ]),
    _Block(('Audit Policies', 'ऑडिट नीतियाँ'), [
      ('Internal self-audit must be run at least once per month by the Treasurer.', 'कोषाध्यक्ष द्वारा हर माह कम से कम एक बार आंतरिक स्व-ऑडिट चलाया जाए।'),
      ('All "Critical" findings must be resolved before the next General Body meeting.', 'सभी "गंभीर" निष्कर्ष अगली आम सभा बैठक से पहले हल हों।'),
      ('"Warning" findings must be documented with an action plan within 7 days.', '"चेतावनी" निष्कर्ष 7 दिन के भीतर कार्य योजना के साथ दर्ज हों।'),
      ('Duplicate entries must be deleted (not just rejected) to prevent reporting inflation.',
          'रिपोर्ट बढ़ने से रोकने के लिए डुप्लिकेट प्रविष्टियाँ हटाई जाएँ (केवल अस्वीकृत नहीं)।'),
      ('Orphaned payments (no ledger link) must be re-recorded properly or documented as legacy.',
          'बिना लिंक भुगतान (लेजर लिंक नहीं) सही ढंग से फिर से दर्ज हों या पुराने रिकॉर्ड के रूप में दर्ज किए जाएँ।'),
    ]),
    _Block(('Common Policy Issues & Resolution', 'सामान्य नीति समस्याएँ और समाधान'), [
      ('Issue: Resident claims payment but no record exists → Check bank statement, ask for screenshot, record with note.',
          'समस्या: निवासी भुगतान का दावा करे पर रिकॉर्ड न हो → बैंक विवरण जाँचें, स्क्रीनशॉट माँगें, टिप्पणी के साथ दर्ज करें।'),
      ('Issue: Negative cash balance → Run self-audit, identify mistagged payment method, correct it.',
          'समस्या: ऋणात्मक नकद शेष → स्व-ऑडिट चलाएँ, गलत टैग किया भुगतान माध्यम पहचानें, सुधारें।'),
      ('Issue: Committee member questions expense → Show finance_entry with receipt photo and approval trail.',
          'समस्या: समिति सदस्य खर्च पर प्रश्न करे → रसीद फोटो और अनुमोदन क्रम के साथ finance_entry दिखाएँ।'),
      ('Issue: Guard recorded wrong flat for visitor → Edit in visitor log, add correction note in audit.',
          'समस्या: गार्ड ने आगंतुक का गलत फ्लैट दर्ज किया → आगंतुक लॉग में संपादित करें, ऑडिट में सुधार टिप्पणी जोड़ें।'),
      ('Issue: Two admins recorded same payment → Duplicate alarm will flag it; delete the later entry.',
          'समस्या: दो एडमिन ने एक ही भुगतान दर्ज किया → डुप्लिकेट अलार्म चिह्नित करेगा; बाद वाली प्रविष्टि हटाएँ।'),
      ('Issue: Maintenance amount changed mid-month → Update charge definition; existing payments remain at old amount (this is correct).',
          'समस्या: माह के बीच रखरखाव राशि बदली → शुल्क परिभाषा अपडेट करें; मौजूदा भुगतान पुरानी राशि पर रहेंगे (यह सही है)।'),
    ]),
    _Block(('Regulatory Compliance', 'नियामक अनुपालन'), [
      ('Maharashtra Co-operative Societies Act / State Housing Society Act compliance.', 'महाराष्ट्र सहकारी संस्था अधिनियम / राज्य आवास सोसाइटी अधिनियम का अनुपालन।'),
      ('Books of accounts must be maintained as per Section 79/80 of the Act.', 'लेखा पुस्तकें अधिनियम की धारा 79/80 के अनुसार रखी जाएँ।'),
      ('Annual audit by certified auditor — this system provides digital-ready data export.',
          'प्रमाणित लेखा परीक्षक द्वारा वार्षिक ऑडिट — यह प्रणाली डिजिटल-तैयार डेटा निर्यात देती है।'),
      ('Income Tax: Society income above threshold requires ITR filing — period reports support this.',
          'आयकर: सीमा से अधिक सोसाइटी आय पर ITR भरना ज़रूरी — अवधि रिपोर्ट इसमें मदद करती हैं।'),
      ('GST: If society turnover exceeds limit, vendor payments must track GST — expense heads support this.',
          'GST: यदि सोसाइटी का कारोबार सीमा से अधिक हो, तो विक्रेता भुगतानों में GST ट्रैक हो — खर्च शीर्ष इसमें मदद करते हैं।'),
    ]),
  ]),
];

class SocietyGovernanceGuide extends StatefulWidget {
  const SocietyGovernanceGuide({super.key});

  @override
  State<SocietyGovernanceGuide> createState() => _SocietyGovernanceGuideState();
}

class _SocietyGovernanceGuideState extends State<SocietyGovernanceGuide> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    String p(_T x) => context.tr(x.$1, x.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.menu_book_outlined,
          title: context.tr('Society Governance Framework', 'सोसाइटी शासन ढाँचा'),
          subtitle: context.tr('Principal · Purpose · Vision · Planning · Policy', 'प्रधान · उद्देश्य · दृष्टि · योजना · नीति'),
        ),
        const SizedBox(height: 12),
        for (final s in _sections) ...[
          CardSection(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = _expanded == s.id ? null : s.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.1), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                        child: Icon(s.icon, size: 16, color: t.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p(s.title), style: AppText.sectionTitle(context)),
                          Text(p(s.subtitle), style: AppText.tiny(context)),
                        ]),
                      ),
                      Icon(_expanded == s.id ? Icons.expand_less : Icons.expand_more, size: 18, color: t.mutedForeground),
                    ]),
                  ),
                ),
                if (_expanded == s.id) ...[
                  Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final b in s.content) ...[
                          Row(children: [
                            Icon(Icons.lightbulb_outline, size: 12, color: t.primary),
                            const SizedBox(width: 4),
                            Expanded(child: Text(p(b.heading), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.primary))),
                          ]),
                          const SizedBox(height: 6),
                          for (final pt in b.points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('•  ', style: TextStyle(fontSize: 12, color: t.primary)),
                                Expanded(child: Text(p(pt), style: TextStyle(fontSize: 12, color: t.foreground))),
                              ]),
                            ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        CardSection(
          padding: const EdgeInsets.all(12),
          color: Color.alphaBlend(AppTokens.tint(t.muted, 0.3), t.card),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_outlined, size: 16, color: t.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('How to use this section', 'इस खंड का उपयोग कैसे करें'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  context.tr(
                    'This governance guide serves as a reference for committee members and admins. Share it during AGMs, onboarding new committee members, or when resolving disputes. The policies above should be adopted via MC resolution and communicated to all members.',
                    'यह शासन मार्गदर्शिका समिति सदस्यों और एडमिन के लिए संदर्भ है। इसे वार्षिक आम सभा, नए समिति सदस्यों को जोड़ते समय, या विवाद सुलझाते समय साझा करें। ऊपर दी गई नीतियाँ MC प्रस्ताव से अपनाई जाएँ और सभी सदस्यों को बताई जाएँ।',
                  ),
                  style: AppText.tiny(context),
                ),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}
