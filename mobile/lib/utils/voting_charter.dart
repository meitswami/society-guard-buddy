import 'package:url_launcher/url_launcher.dart';

/// Member-facing election charter (EN + HI) — registered bye-laws controlling.
/// Charter + bye-laws are merged into one descriptive step-by-step guide.
enum CharterLang { en, hi }

class VotingCharterStep {
  const VotingCharterStep({
    required this.title,
    required this.detail,
    this.points = const [],
  });
  final String title;
  final String detail;
  final List<String> points;
}

class VotingCharterContent {
  const VotingCharterContent({
    required this.title,
    required this.summaryTitle,
    required this.summaryPosts,
    required this.summaryPoints,
    required this.programHeading,
    required this.programIntro,
    required this.steps,
    required this.footerNote,
    required this.shareMessage,
  });

  final String title;
  final String summaryTitle;
  final String summaryPosts;
  final List<String> summaryPoints;
  final String programHeading;
  final String programIntro;
  final List<VotingCharterStep> steps;
  final String footerNote;
  final String shareMessage;
}

const votingCharterTitle = 'Election of the 7-member Management Committee';

const votingCharterShareMessage =
    'Society Election Charter — election of the 7-member Management Committee under the registered bye-laws.';

const _enSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'Step 1 — Know the seven Management Committee seats',
    detail:
        'Under the bye-laws the Management Committee has exactly seven seats. Know the posts and the two-year term before you nominate or vote. Second- or third-place finishers are not automatically given a committee seat.',
    points: [
      'The Management Committee has exactly seven members: President, Vice-President, Secretary, Treasurer, and three Executive Members, for a two-year term.',
      'Second- or third-place candidates are not automatically made members of the Management Committee.',
    ],
  ),
  VotingCharterStep(
    title: 'Step 2 — Confirm you are eligible',
    detail:
        'Before nominating or voting, check the bye-law eligibility rules: one vote per member, designated member for joint ownership, arrears over 60 days on election day disqualify, and proxy only with written authorisation at least 48 hours before the meeting (max one proxy per person).',
    points: [
      'Each Society member has one voting right, irrespective of the number of apartments owned.',
      'Joint ownership follows the designated-member rule in the bye-laws — only the designated member votes for that holding.',
      'A member with maintenance or common-expense arrears exceeding 60 days on the election date is disqualified from voting and contesting.',
      'Voting may be in person or through a valid written proxy submitted at least 48 hours before the meeting; one person may not act as proxy for more than one member.',
    ],
  ),
  VotingCharterStep(
    title: 'Step 3 — Nominate during the nomination window',
    detail:
        'When the admin opens nominations, eligible members may self-nominate for President, Vice-President, Secretary, Treasurer, or Executive Member with a short statement. Retiring members may seek re-election. Nominations are allowed only inside the admin-set dates and only if you are not disqualified by arrears.',
    points: [
      'When the admin opens the nomination window, eligible members may propose themselves for Management Committee seats: President, Vice-President, Secretary, Treasurer, or Executive Member.',
      'Each nominee must write a short statement. Retiring members remain eligible for re-election.',
      'Self-nomination is only allowed inside the admin-set nomination open and close dates, and only for members not disqualified by arrears.',
    ],
  ),
  VotingCharterStep(
    title: 'Step 4 — Meet quorum, then cast your vote',
    detail:
        'Election quorum is 3/4 of members (for 30 members: at least 23). Voting opens only inside the admin-set window once quorum is met. Record Secret Ballot or Show of Hands before polling. One member, one vote — separate per-office ballots only if that method is expressly approved. Votes are final; duplicates are blocked.',
    points: [
      'Bye-laws permit Secret Ballot and Show of Hands. The chosen method must be recorded before polling begins.',
      'Each eligible member casts one vote. Separate per-office ballots are used only when that voting method is expressly established or approved.',
      'Votes are final after submission — ordinary administrators cannot edit them. Duplicate voting is blocked; the election record is immutable.',
      'Voting is only allowed inside the admin-set voting window and only once election quorum (3/4 of members) is satisfied.',
    ],
  ),
  VotingCharterStep(
    title: 'Step 5 — Results, audit, vacancies and removal',
    detail:
        'After voting closes, results are tallied and audited. Declared winners fill the seven seats. Vacancies are filled by majority of the remaining committee. Removal needs Special Resolution and hearing; removed members are disqualified for two years. A full Election Report and AGM Election Minutes are produced on completion.',
    points: [
      'After voting closes, results are tallied and audited. A complete Election Report and AGM Election Minutes are generated on completion.',
      'Vacancies are filled by majority of the remaining committee per the bye-laws. Removal requires Special Resolution and hearing; removed members are disqualified for two years.',
    ],
  ),
  VotingCharterStep(
    title: 'Step 6 — Documents, publish roster and first meeting',
    detail:
        'Admins may attach circulars and society documents to the election. Elected names appear for residents only after the roster is published. The first Management Committee meeting must be within 30 days of the election. Ordinary MC quorum is 5 of 7; regular meetings are at least monthly with seven clear days’ notice. Share this charter PDF with all members.',
    points: [
      'Admin may attach circulars, letters, or other society documents to the election; members can open them from the poll.',
      'Elected committee names appear in the residents’ Committee module only after the admin publishes the roster.',
      'The first committee meeting must be within 30 days of election. Ordinary meeting quorum is 5 of 7; regular meetings at least monthly with seven clear days’ notice.',
      'This charter can be downloaded as a PDF and shared with all members (for example via WhatsApp).',
    ],
  ),
];

const _hiSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'चरण 1 — प्रबंध समिति के सात पद जानें',
    detail:
        'उपविधियों के अनुसार प्रबंध समिति में ठीक सात पद हैं। नामांकन या मतदान से पहले पद और दो-वर्ष का कार्यकाल समझ लें। द्वितीय या तृतीय स्थान पर आने वाले अभ्यर्थी स्वतः समिति सदस्य नहीं बनते।',
    points: [
      'प्रबंध समिति में ठीक सात सदस्य होते हैं—अध्यक्ष, उपाध्यक्ष, सचिव, कोषाध्यक्ष तथा तीन कार्यकारिणी सदस्य—दो वर्ष के कार्यकाल हेतु।',
      'द्वितीय अथवा तृतीय स्थान के अभ्यर्थी स्वतः प्रबंध समिति के सदस्य नहीं बनते।',
    ],
  ),
  VotingCharterStep(
    title: 'चरण 2 — अपनी पात्रता सुनिश्चित करें',
    detail:
        'नामांकन या मतदान से पहले उपविधि की पात्रता जाँचें: प्रत्येक सदस्य को एक मत, संयुक्त स्वामित्व में नामित सदस्य, चुनाव तिथि पर 60 दिनों से अधिक बकाया होने पर अयोग्यता, तथा प्रॉक्सी केवल बैठक से कम-से-कम 48 घंटे पूर्व लिखित प्राधिकरण से (प्रति व्यक्ति अधिकतम एक प्रॉक्सी)।',
    points: [
      'प्रत्येक सोसायटी सदस्य को एक मतदान अधिकार है—चाहे उनके स्वामित्व में कितने भी फ्लैट हों।',
      'संयुक्त स्वामित्व में उपविधि का नामित-सदस्य नियम लागू होता है—उस धारण हेतु केवल नामित सदस्य मतदान करता है।',
      'चुनाव तिथि पर 60 दिनों से अधिक अनुरक्षण अथवा साझा व्यय बकाया वाले सदस्य मतदान एवं निर्वाचन से अयोग्य हैं।',
      'मतदान व्यक्तिगत रूप से अथवा बैठक से कम-से-कम 48 घंटे पूर्व जमा वैध लिखित प्रॉक्सी द्वारा हो सकता है; एक व्यक्ति एक से अधिक सदस्य का प्रॉक्सी नहीं हो सकता।',
    ],
  ),
  VotingCharterStep(
    title: 'चरण 3 — नामांकन अवधि में नामांकन करें',
    detail:
        'जब प्रशासक नामांकन खोलता है, पात्र सदस्य अध्यक्ष, उपाध्यक्ष, सचिव, कोषाध्यक्ष या कार्यकारिणी सदस्य हेतु संक्षिप्त विवरण सहित स्वयं नामांकन कर सकते हैं। निवृत्त सदस्य पुनः निर्वाचन लड़ सकते हैं। नामांकन केवल निर्धारित तिथियों में और बकाया से अयोग्य न होने पर अनुमत है।',
    points: [
      'जब प्रशासक नामांकन अवधि खोलता है, पात्र सदस्य प्रबंध समिति के पदों—अध्यक्ष, उपाध्यक्ष, सचिव, कोषाध्यक्ष अथवा कार्यकारिणी सदस्य—हेतु स्वयं को प्रस्तावित कर सकते हैं।',
      'प्रत्येक नामांकित को संक्षिप्त विवरण लिखना होगा। निवृत्त सदस्य पुनः निर्वाचन हेतु पात्र रहते हैं।',
      'स्व-नामांकन केवल प्रशासक द्वारा निर्धारित नामांकन तिथियों में, तथा बकाया से अयोग्य न होने वाले सदस्यों के लिए ही अनुमत है।',
    ],
  ),
  VotingCharterStep(
    title: 'चरण 4 — कोरम पूरा करें, फिर मत डालें',
    detail:
        'चुनाव कोरम कुल सदस्यों का 3/4 है (30 सदस्यों के लिए न्यूनतम 23)। मतदान केवल निर्धारित अवधि में और कोरम पूरा होने पर खुलता है। मतदान से पहले गुप्त मतपत्र या हाथ उठाना दर्ज करें। एक सदस्य, एक मत—प्रति-पद अलग मतपत्र केवल स्पष्ट अनुमोदन पर। मत अंतिम हैं; दोहरा मतदान निषिद्ध है।',
    points: [
      'उपविधियाँ गुप्त मतपत्र तथा हाथ उठाकर मतदान दोनों की अनुमति देती हैं। चुनी गई विधि मतदान आरंभ होने से पूर्व दर्ज करनी होगी।',
      'प्रत्येक पात्र सदस्य एक मत डालता है। प्रति-पद पृथक मतपत्र केवल तभी जब वह मतदान विधि स्पष्ट रूप से स्थापित अथवा अनुमोदित हो।',
      'जमा होने के पश्चात् मत अंतिम हैं—सामान्य प्रशासक उन्हें संशोधित नहीं कर सकते। दोहरा मतदान निषिद्ध है; चुनाव अभिलेख अपरिवर्तनीय है।',
      'मतदान केवल प्रशासक द्वारा निर्धारित मतदान अवधि में तथा चुनाव कोरम (सदस्यों का 3/4) पूरा होने पर ही अनुमत है।',
    ],
  ),
  VotingCharterStep(
    title: 'चरण 5 — परिणाम, लेखापरीक्षा, रिक्ति और निष्कासन',
    detail:
        'मतदान बंद होने के पश्चात् परिणाम गिने जाते हैं और लेखापरीक्षा होती है। घोषित विजेता सात पद भरते हैं। रिक्तियाँ शेष समिति के बहुमत से भरी जाती हैं। निष्कासन हेतु विशेष प्रस्ताव एवं सुनवाई आवश्यक है; निष्कासित सदस्य दो वर्ष तक अयोग्य रहते हैं। पूर्ण होने पर चुनाव प्रतिवेदन तथा वार्षिक आम सभा का चुनाव कार्यवृत्त तैयार होते हैं।',
    points: [
      'मतदान बंद होने के पश्चात् परिणाम गिने जाते हैं और लेखापरीक्षा की जाती है। पूर्ण होने पर पूर्ण चुनाव प्रतिवेदन तथा वार्षिक आम सभा का चुनाव कार्यवृत्त तैयार होते हैं।',
      'रिक्तियाँ शेष समिति के बहुमत से उपविधि के अनुसार भरी जाती हैं। निष्कासन हेतु विशेष प्रस्ताव एवं सुनवाई आवश्यक है; निष्कासित सदस्य दो वर्ष तक अयोग्य रहते हैं।',
    ],
  ),
  VotingCharterStep(
    title: 'चरण 6 — दस्तावेज़, सूची प्रकाशन और पहली बैठक',
    detail:
        'प्रशासक चुनाव में परिपत्र और सोसायटी दस्तावेज़ संलग्न कर सकते हैं। निर्वाचित नाम निवासियों को तभी दिखते हैं जब सूची प्रकाशित हो। प्रबंध समिति की प्रथम बैठक चुनाव के 30 दिनों के भीतर होनी चाहिए। सामान्य बैठक कोरम 7 में से 5; नियमित बैठकें कम-से-कम मासिक, सात स्पष्ट दिनों की सूचना सहित। यह नियमपत्र पीडीएफ सभी सदस्यों को परिचालित करें।',
    points: [
      'प्रशासक चुनाव में परिपत्र, पत्र अथवा अन्य सोसायटी दस्तावेज़ संलग्न कर सकता है; सदस्य उन्हें मतदान से खोल सकते हैं।',
      'निर्वाचित समिति के नाम निवासी समिति खंड में तभी दिखते हैं जब प्रशासक सूची प्रकाशित करता है।',
      'समिति की प्रथम बैठक चुनाव के 30 दिनों के भीतर होनी चाहिए। सामान्य बैठक का कोरम 7 में से 5; नियमित बैठकें कम-से-कम मासिक, सात स्पष्ट दिनों की सूचना सहित।',
      'यह नियमपत्र पीडीएफ के रूप में प्राप्त कर सभी सदस्यों को (उदाहरणार्थ व्हाट्सऐप द्वारा) परिचालित किया जा सकता है।',
    ],
  ),
];

VotingCharterContent votingCharterContent(CharterLang lang) {
  if (lang == CharterLang.hi) {
    return const VotingCharterContent(
      title: 'समिति के 7 सदस्यों का चुनाव',
      summaryTitle: 'समिति के 7 सदस्यों का चुनाव',
      summaryPosts: 'अध्यक्ष • उपाध्यक्ष • सचिव • कोषाध्यक्ष • 3 कार्यकारिणी सदस्य',
      summaryPoints: [
        'प्रत्येक पात्र सदस्य को एक मत।',
        'प्रॉक्सी: लिखित प्राधिकरण के साथ, बैठक से कम-से-कम 48 घंटे पूर्व।',
        'कोरम: कुल सदस्यों का 3/4। 30 सदस्यों के लिए न्यूनतम 23 सदस्य।',
      ],
      programHeading: 'नियमपत्र एवं उपविधियाँ — सदस्यों के लिए चरणबद्ध मार्गदर्शिका',
      programIntro:
          'यह मार्गदर्शिका चुनाव नियमपत्र को सोसायटी की पंजीकृत उपविधियों से मिलाकर बनाई गई है। सात-सदस्यीय प्रबंध समिति (30 फ्लैट) के चुनाव हेतु प्रत्येक चरण क्रम से अपनाएँ।',
      steps: _hiSteps,
      footerNote:
          'यह नियमपत्र पीडीएफ के रूप में प्राप्त कर सभी सदस्यों को (उदाहरणार्थ व्हाट्सऐप द्वारा) परिचालित किया जा सकता है।',
      shareMessage:
          'सोसायटी चुनाव नियमपत्र — पंजीकृत उपविधियों के अनुसार समिति के 7 सदस्यों का चुनाव।',
    );
  }
  return const VotingCharterContent(
    title: votingCharterTitle,
    summaryTitle: 'Election of the 7-member Management Committee',
    summaryPosts: 'President • Vice-President • Secretary • Treasurer • 3 Executive Members',
    summaryPoints: [
      'Voting right: one vote for each eligible member.',
      'Proxy: with written authorisation, at least 48 hours before the meeting.',
      'Election quorum: 3/4 of members. For 30 members, minimum 23 members.',
    ],
    programHeading: 'Charter & bye-laws — step by step for members',
    programIntro:
        'This guide merges the Election Charter with the Society’s registered bye-laws. Follow each step in order for electing the seven-member Management Committee (30 flats).',
    steps: _enSteps,
    footerNote:
        'This charter can be downloaded as a PDF and shared with all members (for example via WhatsApp).',
    shareMessage: votingCharterShareMessage,
  );
}

String votingCharterShareMessageFor(CharterLang lang) => votingCharterContent(lang).shareMessage;

String buildVotingCharterPlainText({String? societyName, CharterLang lang = CharterLang.en}) {
  final c = votingCharterContent(lang);
  final buf = StringBuffer();
  if (societyName != null && societyName.trim().isNotEmpty) {
    buf.writeln(societyName.trim());
    buf.writeln();
  }
  buf.writeln(c.title);
  buf.writeln();
  buf.writeln(c.summaryTitle);
  buf.writeln(c.summaryPosts);
  for (final p in c.summaryPoints) {
    buf.writeln('• $p');
  }
  buf.writeln();
  buf.writeln(c.programHeading);
  buf.writeln(c.programIntro);
  buf.writeln();
  for (var i = 0; i < c.steps.length; i++) {
    final s = c.steps[i];
    buf.writeln('${i + 1}. ${s.title}');
    buf.writeln(s.detail);
    for (final p in s.points) {
      buf.writeln('  • $p');
    }
    buf.writeln();
  }
  return buf.toString().trim();
}

Future<bool> shareVotingCharterOnWhatsApp({String? societyName, CharterLang lang = CharterLang.en}) async {
  final programOnly = () {
    final c = votingCharterContent(lang);
    final buf = StringBuffer();
    if (societyName != null && societyName.trim().isNotEmpty) {
      buf.writeln(societyName.trim());
      buf.writeln();
    }
    buf.writeln(c.summaryTitle);
    buf.writeln(c.summaryPosts);
    for (final p in c.summaryPoints) {
      buf.writeln('• $p');
    }
    buf.writeln();
    buf.writeln(c.programHeading);
    buf.writeln(c.programIntro);
    buf.writeln();
    for (var i = 0; i < c.steps.length; i++) {
      final s = c.steps[i];
      buf.writeln('${i + 1}. ${s.title}');
      buf.writeln(s.detail);
      buf.writeln();
    }
    buf.writeln(lang == CharterLang.hi
        ? 'पूर्ण नियम पीडीएफ में देखें (ऐप से हिंदी / अंग्रेज़ी पीडीएफ प्राप्त करें)।'
        : 'See full bye-law points in the PDF (download Hindi / English PDF from the app).');
    return buf.toString().trim();
  }();

  final body = '${votingCharterShareMessageFor(lang)}\n\n$programOnly';
  var text = body;
  const maxLen = 3500;
  if (text.length > maxLen) {
    final ellipsis = lang == CharterLang.hi ? '\n\n…(ऐप में जारी)' : '\n\n…(continued in app)';
    text = '${text.substring(0, maxLen - ellipsis.length)}$ellipsis';
  }
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
