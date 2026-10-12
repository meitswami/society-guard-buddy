import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import 'legal_page_layout.dart';
import 'public_nav.dart';

typedef _T = ({String en, String hi});

/// Port of web `AboutPage` (`/about`): vision, purpose, structure, principles.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const List<_T> _immediateGoals = [
    (
      en: 'Zero manual registers — every transaction is digital and auditable',
      hi: 'शून्य हस्तलिखित रजिस्टर — हर लेन-देन डिजिटल और ऑडिट-योग्य'
    ),
    (en: '100% maintenance collection tracked with receipt-level detail', hi: '100% रखरखाव वसूली, रसीद-स्तर के विवरण के साथ ट्रैक'),
    (en: 'Every expense has a head, receipt photo, and approval trail', hi: 'हर खर्च का शीर्ष, रसीद फोटो और स्वीकृति-क्रम'),
    (en: 'Monthly auto-generated financial reports sent to all members', hi: 'मासिक स्वतः बनी वित्तीय रिपोर्ट सभी सदस्यों को'),
    (
      en: 'Real-time security — visitor logs, guard attendance, geofencing',
      hi: 'रियल-टाइम सुरक्षा — आगंतुक लॉग, गार्ड उपस्थिति, भौगोलिक सीमा'
    ),
  ];

  static const List<_T> _longTerm = [
    (en: 'Fully self-auditing system — anomalies detected in real-time', hi: 'पूर्णतः स्व-ऑडिट प्रणाली — गड़बड़ी तुरंत पकड़ी जाए'),
    (en: 'Predictive budgeting based on historical expense patterns', hi: 'पिछले खर्च के आधार पर अनुमानित बजट'),
    (
      en: 'Paperless AGM — resolutions, voting, minutes with e-signatures',
      hi: 'कागज़-रहित वार्षिक सभा — प्रस्ताव, मतदान, ई-हस्ताक्षर सहित कार्यवृत्त'
    ),
    (en: 'Integrated vendor management with GST compliance', hi: 'जीएसटी अनुपालन के साथ एकीकृत विक्रेता प्रबंधन'),
    (en: 'Multi-society federation — shared vendors, benchmarking', hi: 'बहु-सोसाइटी संघ — साझा विक्रेता, तुलनात्मक मानक'),
    (
      en: 'AI-powered insights — spending anomalies, maintenance predictions',
      hi: 'एआई आधारित जानकारी — खर्च की गड़बड़ी, रखरखाव पूर्वानुमान'
    ),
  ];

  static const List<(IconData, _T, _T)> _corePurpose = [
    (
      Icons.currency_rupee,
      (en: 'Financial Transparency', hi: 'वित्तीय पारदर्शिता'),
      (
        en: 'Every rupee collected and spent is recorded, visible, and auditable by all members.',
        hi: 'हर एकत्र और खर्च रुपया दर्ज, सबको दिखने वाला और सभी सदस्यों द्वारा ऑडिट-योग्य है।'
      ),
    ),
    (
      Icons.verified_user_outlined,
      (en: 'Accountability', hi: 'जवाबदेही'),
      (
        en: 'Every action is logged with who, when, and from where — non-repudiation by design.',
        hi: 'हर कार्य किसने, कब और कहाँ से — सब दर्ज; मुकरना संभव नहीं।'
      ),
    ),
    (
      Icons.groups_outlined,
      (en: 'Community Trust', hi: 'सामुदायिक विश्वास'),
      (
        en: 'Residents see where their money goes. Committee decisions are documented and traceable.',
        hi: 'निवासी देखते हैं कि पैसा कहाँ जाता है। समिति के निर्णय दर्ज और खोजने योग्य हैं।'
      ),
    ),
    (
      Icons.lightbulb_outline,
      (en: 'Error Elimination', hi: 'त्रुटि निवारण'),
      (
        en: 'Digital records prevent overwriting, backdating, loss, and the human errors of manual registers.',
        hi: 'डिजिटल रिकॉर्ड काट-छाँट, पिछली तारीख, खोने और रजिस्टर की मानवीय भूलों को रोकते हैं।'
      ),
    ),
  ];

  static const List<(_T, _T)> _problems = [
    (
      (en: 'Double-entry of maintenance', hi: 'रखरखाव की दोहरी प्रविष्टि'),
      (
        en: 'same flat credited twice → detected by automated duplicate alarms',
        hi: 'एक ही फ्लैट दो बार जमा → स्वचालित दोहराव अलार्म से पकड़ा जाता है'
      ),
    ),
    (
      (en: 'Negative cash/bank balance', hi: 'नकद/बैंक शेष ऋणात्मक'),
      (en: 'expenses exceed receipts → flagged with root cause and fix steps', hi: 'खर्च आय से अधिक → कारण और सुधार चरणों के साथ चिह्नित'),
    ),
    (
      (en: 'Unverified payments', hi: 'असत्यापित भुगतान'),
      (
        en: 'sitting for weeks without review → audit flags pending entries > 7 days',
        hi: 'हफ़्तों बिना समीक्षा → ऑडिट 7 दिन से पुरानी लंबित प्रविष्टियाँ चिह्नित करता है'
      ),
    ),
    (
      (en: 'Recording vs reporting mismatch', hi: 'दर्ज और रिपोर्ट में अंतर'),
      (en: 'what was entered ≠ what is shown → cross-checked automatically', hi: 'जो दर्ज हुआ ≠ जो दिखा → स्वतः मिलान'),
    ),
    (
      (en: 'Lack of accountability', hi: 'जवाबदेही की कमी'),
      (
        en: '"who did what?" is unanswerable → every action logged with user, time, IP, device',
        hi: '"किसने क्या किया?" का उत्तर नहीं → हर कार्य उपयोगकर्ता, समय, आईपी, उपकरण सहित दर्ज'
      ),
    ),
    (
      (en: 'Paper-based visitor logs', hi: 'कागज़ी आगंतुक रजिस्टर'),
      (
        en: 'lost, illegible, no search → digital with photo, time, flat, and approval chain',
        hi: 'खो जाते, पढ़ने में कठिन, खोज नहीं → फोटो, समय, फ्लैट और स्वीकृति-क्रम सहित डिजिटल'
      ),
    ),
  ];

  static const List<(IconData, _T, _T)> _modules = [
    (
      Icons.currency_rupee,
      (en: 'Finance', hi: 'वित्त'),
      (
        en: 'Receipt types → Record receipt/payment → Transactions → Totals → Reminders',
        hi: 'रसीद प्रकार → रसीद/भुगतान दर्ज → लेन-देन → कुल → अनुस्मारक'
      )
    ),
    (
      Icons.verified_user_outlined,
      (en: 'Audit & Governance', hi: 'ऑडिट और शासन'),
      (
        en: 'Security logs, duplicate alarms, self-audit engine, governance framework',
        hi: 'सुरक्षा लॉग, दोहराव अलार्म, स्व-ऑडिट इंजन, शासन ढाँचा'
      )
    ),
    (
      Icons.groups_outlined,
      (en: 'Resident Portal', hi: 'निवासी पोर्टल'),
      (
        en: 'View committee, pay maintenance, notices, complaints, directory',
        hi: 'समिति देखें, रखरखाव भुगतान, सूचनाएँ, शिकायतें, निर्देशिका'
      )
    ),
    (
      Icons.account_balance_outlined,
      (en: 'Guard Module', hi: 'गार्ड मॉड्यूल'),
      (
        en: 'Visitor entry/exit, vehicle tracking, geofence, biometric attendance',
        hi: 'आगंतुक प्रवेश/निकास, वाहन ट्रैकिंग, भौगोलिक सीमा, जैवमितीय उपस्थिति'
      )
    ),
    (
      Icons.calendar_month_outlined,
      (en: 'Meetings', hi: 'बैठकें'),
      (en: 'GBM/AGM/EC, attendees, decisions, documents, publish & notify', hi: 'GBM/AGM/EC, उपस्थित, निर्णय, दस्तावेज़, प्रकाशन और सूचना')
    ),
    (
      Icons.how_to_vote_outlined,
      (en: 'Polls & Elections', hi: 'मतदान और चुनाव'),
      (
        en: 'Standard polls, bye-law MC elections (Secret Ballot / Show of Hands), result banners',
        hi: 'सामान्य मतदान, उपनियम MC चुनाव (गुप्त मतदान / हाथ उठाकर), परिणाम बैनर'
      )
    ),
    (
      Icons.notifications_none,
      (en: 'Notifications', hi: 'सूचनाएँ'),
      (en: 'FCM push, in-app center, targeted delivery, read receipts', hi: 'FCM पुश, ऐप सूचना केंद्र, लक्षित वितरण, पढ़ने की पुष्टि')
    ),
    (
      Icons.call_split,
      (en: 'Expense Splitter', hi: 'खर्च विभाजक'),
      (en: 'Group expenses, per-flat splits, settlement tracking', hi: 'समूह खर्च, प्रति-फ्लैट विभाजन, निपटान ट्रैकिंग')
    ),
    (
      Icons.directions_car_outlined,
      (en: 'Parking & Vehicles', hi: 'पार्किंग और वाहन'),
      (en: 'Slot allocation, resident vehicles, visitor parking', hi: 'स्थान आवंटन, निवासी वाहन, आगंतुक पार्किंग')
    ),
    (
      Icons.balance_outlined,
      (en: 'Admin Panel', hi: 'प्रशासक पैनल'),
      (
        en: 'All modules + user management + society settings + RBAC',
        hi: 'सभी मॉड्यूल + उपयोगकर्ता प्रबंधन + सोसाइटी सेटिंग + भूमिका आधारित पहुँच'
      )
    ),
  ];

  static const _flow = ['Payment Recorded', 'maintenance_payment', 'finance_entry', 'allocations', 'Period Report'];

  static const List<_T> _flowNotes = [
    (
      en: 'Every payment creates both a payment record AND a ledger entry',
      hi: 'हर भुगतान से भुगतान रिकॉर्ड और खाता-बही प्रविष्टि दोनों बनती हैं'
    ),
    (
      en: 'Allocations break down per-flat amounts for multi-flat recordings',
      hi: 'बहु-फ्लैट प्रविष्टियों में आवंटन प्रति-फ्लैट राशि बताते हैं'
    ),
    (en: 'Period reports compute: Opening + Receipts − Expenses = Closing', hi: 'अवधि रिपोर्ट: प्रारंभिक + आय − खर्च = अंतिम शेष'),
    (
      en: 'Self-Audit cross-verifies these relationships and flags any break',
      hi: 'स्व-ऑडिट इन संबंधों का मिलान करता है और किसी भी टूट को चिह्नित करता है'
    ),
  ];

  static const List<(_T, _T)> _roles = [
    (
      (en: 'Admin', hi: 'प्रशासक'),
      (
        en: 'Records day-to-day transactions, manages visitors, guards, and notices',
        hi: 'दैनिक लेन-देन दर्ज करता है, आगंतुक, गार्ड और सूचनाएँ सँभालता है'
      )
    ),
    (
      (en: 'Treasurer', hi: 'कोषाध्यक्ष'),
      (
        en: 'Reviews and verifies payments, runs monthly self-audit, reconciles bank',
        hi: 'भुगतानों की समीक्षा व सत्यापन, मासिक स्व-ऑडिट, बैंक मिलान'
      )
    ),
    (
      (en: 'Secretary', hi: 'सचिव'),
      (
        en: 'Manages meetings, ensures minutes reference financial decisions',
        hi: 'बैठकें सँभालता है, कार्यवृत्त में वित्तीय निर्णयों का उल्लेख सुनिश्चित करता है'
      )
    ),
    (
      (en: 'Committee', hi: 'समिति'),
      (
        en: 'Views reports, approves large expenses, participates in decisions',
        hi: 'रिपोर्ट देखती है, बड़े खर्च स्वीकृत करती है, निर्णयों में भाग लेती है'
      )
    ),
    (
      (en: 'Residents', hi: 'निवासी'),
      (
        en: 'View payment history, society summaries, raise complaints, vote in polls',
        hi: 'भुगतान इतिहास, सोसाइटी सारांश देखें, शिकायत करें, मतदान करें'
      )
    ),
  ];

  static const _tech = [
    'React 18', 'TypeScript', 'Vite', 'Tailwind CSS', 'shadcn/ui', 'Zustand', 'Supabase', 'PostgreSQL', //
    'Row Level Security', 'Edge Functions', 'jsPDF', 'Capacitor', 'FCM', 'WebAuthn',
  ];

  static const List<(_T, _T)> _principles = [
    (
      (en: 'Transparency First', hi: 'पारदर्शिता सर्वोपरि'),
      (
        en: 'Every financial transaction, every decision, every action is visible to those it affects. No hidden ledgers.',
        hi: 'हर वित्तीय लेन-देन, हर निर्णय, हर कार्य संबंधित लोगों को दिखता है। कोई छिपी बही नहीं।'
      ),
    ),
    (
      (en: 'Accountability by Design', hi: 'संरचना में जवाबदेही'),
      (
        en: 'The system does not just record - it enforces. Who did what, when, and from where is always answerable.',
        hi: 'प्रणाली केवल दर्ज नहीं करती — लागू भी करती है। किसने, क्या, कब और कहाँ से — हमेशा उत्तर मिलता है।'
      ),
    ),
    (
      (en: 'Member-Centric', hi: 'सदस्य-केंद्रित'),
      (
        en: 'Built for residents, not just administrators. Self-service, visibility, and participation are core features.',
        hi: 'केवल प्रशासकों के लिए नहीं, निवासियों के लिए बनी। स्व-सेवा, पारदर्शिता और भागीदारी मूल सुविधाएँ हैं।'
      ),
    ),
    (
      (en: 'Data Integrity', hi: 'आँकड़ों की शुद्धता'),
      (
        en: 'Cross-verification at every layer. Recording must match reporting. Discrepancies are flagged, not hidden.',
        hi: 'हर स्तर पर मिलान। दर्ज और रिपोर्ट मेल खाने चाहिए। अंतर छिपाए नहीं, चिह्नित किए जाते हैं।'
      ),
    ),
    (
      (en: 'Simplicity', hi: 'सरलता'),
      (
        en: 'Mobile-first, minimal clicks. A guard with basic smartphone skills can operate the gate module.',
        hi: 'मोबाइल-प्रथम, कम क्लिक। सामान्य स्मार्टफोन जानने वाला गार्ड भी द्वार मॉड्यूल चला सकता है।'
      ),
    ),
    (
      (en: 'Compliance Ready', hi: 'अनुपालन हेतु तैयार'),
      (
        en: 'Designed to meet Co-operative Societies Act requirements, IT filing needs, and GST tracking.',
        hi: 'सहकारी समिति अधिनियम, आयकर फाइलिंग और जीएसटी ट्रैकिंग की आवश्यकताओं हेतु बनी।'
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    String tr(_T s) => context.tr(s.en, s.hi);

    Widget sectionHeader(IconData icon, _T title, _T subtitle) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(AppTokens.radius)),
                child: Icon(icon, size: 20, color: t.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(title), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.foreground)),
                    Text(tr(subtitle), style: AppText.caption(context)),
                  ],
                ),
              ),
            ],
          ),
        );

    Widget box({required List<Widget> children, Color? border, Color? color}) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? t.card,
            border: Border.all(color: border ?? t.border),
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        );

    Widget boxTitle(IconData? icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: t.primary), const SizedBox(width: 8)],
              Expanded(child: Text(text, style: AppText.sectionTitle(context))),
            ],
          ),
        );

    Widget bullet(String text, {String mark = '•', Color? markColor, List<InlineSpan>? spans}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Text(mark, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: markColor ?? t.primary)),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(text: spans == null ? text : null, children: spans),
                  style: TextStyle(fontSize: 12, height: 1.45, color: t.mutedForeground),
                ),
              ),
            ],
          ),
        );

    Widget iconItem(IconData icon, String title, String desc, {double size = 28, double titleSize = 12, double descSize = 11}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: size,
                height: size,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                child: Icon(icon, size: size * 0.55, color: t.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600, color: t.foreground)),
                    Text(desc, style: TextStyle(fontSize: descSize, height: 1.4, color: t.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
        );

    return LegalPageScaffold(
      title: context.tr('About Kutumbika', 'कुटुम्बिका के बारे में'),
      children: [
        // Hero
        Text(context.t('app.name'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: t.foreground)),
        const SizedBox(height: 8),
        Text(
          context.t('app.tagline'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: t.primary),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'A complete digital ecosystem for housing societies — bringing transparency, accountability, and community together under one roof.',
            'आवासीय सोसाइटियों के लिए संपूर्ण डिजिटल व्यवस्था — पारदर्शिता, जवाबदेही और समुदाय एक ही छत के नीचे।',
          ),
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: t.mutedForeground),
        ),
        const SizedBox(height: 40),

        // Vision
        sectionHeader(
            Icons.visibility_outlined, (en: 'Our Vision', hi: 'हमारी दृष्टि'), (en: "Where we're headed", hi: 'हम कहाँ जा रहे हैं')),
        box(children: [
          boxTitle(Icons.rocket_launch_outlined, context.tr('Immediate Goals', 'तात्कालिक लक्ष्य')),
          for (final g in _immediateGoals) bullet(tr(g)),
        ]),
        box(children: [
          boxTitle(Icons.public, context.tr('Long-Term Vision', 'दीर्घकालिक दृष्टि')),
          for (final g in _longTerm) bullet(tr(g)),
        ]),
        box(
          border: AppTokens.tint(t.primary, 0.2),
          color: Color.alphaBlend(AppTokens.tint(t.primary, 0.05), t.background),
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: context.tr('Our north star:', 'हमारा ध्रुवतारा:'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.primary),
                ),
                TextSpan(
                  text: context.tr(
                    ' Every society member — from the newest resident to the longest-serving committee member — should have complete '
                        'visibility into how their society operates, where their money goes, and confidence that the system is fair, '
                        'transparent, and accountable.',
                    ' हर सोसाइटी सदस्य — नए निवासी से लेकर सबसे पुराने समिति सदस्य तक — को पूरी जानकारी हो कि सोसाइटी कैसे चलती है, '
                        'उनका पैसा कहाँ जाता है, और भरोसा हो कि व्यवस्था निष्पक्ष, पारदर्शी और जवाबदेह है।',
                  ),
                ),
              ]),
              style: TextStyle(fontSize: 12, height: 1.6, color: t.foreground),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Purpose
        sectionHeader(Icons.track_changes, (en: 'Purpose', hi: 'उद्देश्य'), (en: 'Why this project exists', hi: 'यह परियोजना क्यों है')),
        box(children: [
          boxTitle(Icons.favorite_border, context.tr('Core Purpose', 'मूल उद्देश्य')),
          for (final (icon, title, desc) in _corePurpose) iconItem(icon, tr(title), tr(desc)),
        ]),
        box(children: [
          boxTitle(Icons.balance_outlined, context.tr('Problems We Solve', 'हम कौन-सी समस्याएँ हल करते हैं')),
          for (final (title, desc) in _problems)
            bullet('', mark: '✗', markColor: t.destructive, spans: [
              TextSpan(text: tr(title), style: TextStyle(fontWeight: FontWeight.w700, color: t.foreground)),
              TextSpan(text: ' — ${tr(desc)}'),
            ]),
        ]),
        const SizedBox(height: 36),

        // Planning & structure
        sectionHeader(
          Icons.assignment_outlined,
          (en: 'Planning & Project Structure', hi: 'योजना और परियोजना संरचना'),
          (en: 'How the system is organized', hi: 'प्रणाली कैसे संगठित है'),
        ),
        box(children: [
          boxTitle(Icons.layers_outlined, context.tr('System Modules', 'प्रणाली मॉड्यूल')),
          for (final (icon, name, desc) in _modules)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.3), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              child: iconItem(icon, tr(name), tr(desc), size: 24, descSize: 10),
            ),
        ]),
        box(children: [
          boxTitle(Icons.arrow_forward, context.tr('Data Flow & Integrity', 'आँकड़ा प्रवाह और शुद्धता')),
          Wrap(
            spacing: 4,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _flow.length; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(4)),
                  child: Text(_flow[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: t.primary)),
                ),
                if (i < _flow.length - 1) Icon(Icons.arrow_forward, size: 12, color: t.mutedForeground),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final n in _flowNotes) bullet(tr(n)),
        ]),
        box(children: [
          boxTitle(Icons.groups_outlined, context.tr('Collaboration & Roles', 'सहयोग और भूमिकाएँ')),
          Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                    child: Text(context.tr('Role', 'भूमिका'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.tr('Responsibilities', 'ज़िम्मेदारियाँ'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground),
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < _roles.length; i++)
                TableRow(
                  decoration: i < _roles.length - 1
                      ? BoxDecoration(border: Border(bottom: BorderSide(color: AppTokens.tint(t.border, 0.5))))
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                      child: Text(tr(_roles[i].$1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.foreground)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(tr(_roles[i].$2), style: TextStyle(fontSize: 12, height: 1.4, color: t.mutedForeground)),
                    ),
                  ],
                ),
            ],
          ),
        ]),
        box(children: [
          boxTitle(null, context.tr('Technology Stack', 'तकनीकी आधार')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tech in _tech)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: t.muted, borderRadius: BorderRadius.circular(999)),
                  child: Text(tech, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: t.mutedForeground)),
                ),
            ],
          ),
        ]),
        const SizedBox(height: 36),

        // Principles
        sectionHeader(
          Icons.account_balance_outlined,
          (en: 'Guiding Principles', hi: 'मार्गदर्शक सिद्धांत'),
          (en: 'Values that drive every decision', hi: 'हर निर्णय को दिशा देने वाले मूल्य'),
        ),
        for (final (title, desc) in _principles)
          box(children: [
            Text(tr(title), style: AppText.sectionTitle(context)),
            const SizedBox(height: 4),
            Text(tr(desc), style: AppText.caption(context).copyWith(height: 1.45)),
          ]),
        const SizedBox(height: 24),

        // Footer
        Text.rich(
          TextSpan(children: [
            TextSpan(text: context.tr('Built with ❤️ by ', '❤️ के साथ निर्मित: ')),
            TextSpan(text: 'MCSPL', style: TextStyle(fontWeight: FontWeight.w700, color: t.foreground)),
            const TextSpan(text: ' · Copyright © 2026'),
          ]),
          textAlign: TextAlign.center,
          style: AppText.caption(context),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            _FooterLink(label: context.tr('Privacy', 'गोपनीयता'), page: PublicPage.privacy),
            Text('·', style: TextStyle(color: t.border)),
            _FooterLink(label: context.tr('Terms', 'शर्तें'), page: PublicPage.terms),
            Text('·', style: TextStyle(color: t.border)),
            _FooterLink(label: context.tr('Contact', 'संपर्क'), page: PublicPage.contact),
          ],
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.page});

  final String label;
  final PublicPage page;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => PublicNav.open(context, page),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label, style: TextStyle(fontSize: 12, color: context.tokens.primary)),
        ),
      );
}
