import 'package:url_launcher/url_launcher.dart';

/// Member-facing election charter (EN + HI) — registered bye-laws controlling.
enum CharterLang { en, hi }

class VotingCharterStep {
  const VotingCharterStep({required this.title, required this.detail});
  final String title;
  final String detail;
}

class VotingCharterSection {
  const VotingCharterSection({required this.heading, required this.points});
  final String heading;
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
    required this.rulesHeading,
    required this.steps,
    required this.sections,
    required this.footerNote,
    required this.shareMessage,
  });

  final String title;
  final String summaryTitle;
  final String summaryPosts;
  final List<String> summaryPoints;
  final String programHeading;
  final String programIntro;
  final String rulesHeading;
  final List<VotingCharterStep> steps;
  final List<VotingCharterSection> sections;
  final String footerNote;
  final String shareMessage;
}

const votingCharterTitle = 'Election of the 7-member Management Committee';

const votingCharterShareMessage =
    'Society Election Charter — election of the 7-member Management Committee under the registered bye-laws.';

const electionProgramIntro =
    'Follow these steps for electing the Society’s seven-member Management Committee under the registered bye-laws.';

const electionProgramSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'Know the seven Management Committee seats',
    detail:
        'The Management Committee has seven members: President, Vice-President, Secretary, Treasurer, and three Executive Members. The term is two years; retiring members may seek re-election.',
  ),
  VotingCharterStep(
    title: 'Nominate during the nomination window',
    detail:
        'When nominations are open, eligible members (not in maintenance arrears over 60 days) may self-nominate for an open seat with a short statement.',
  ),
  VotingCharterStep(
    title: 'Cast your vote',
    detail:
        'Each eligible member has one vote. Voting is by Secret Ballot or Show of Hands — the method is recorded before polling. Proxy voting needs written authorisation at least 48 hours before the meeting (one person may proxy for only one member).',
  ),
  VotingCharterStep(
    title: 'Quorum and eligibility',
    detail:
        'Election quorum is 3/4 of members (for 30 members: at least 23 represented). A member with maintenance/common-expense arrears exceeding 60 days on election day cannot vote or contest. Joint owners follow the designated-member rule.',
  ),
  VotingCharterStep(
    title: 'Results and the seven seats',
    detail:
        'Declared results fill the seven Management Committee seats. Second- or third-place candidates are not automatically made committee members. Vacancies follow the bye-law vacancy procedure.',
  ),
  VotingCharterStep(
    title: 'Publish roster and first meeting',
    detail:
        'After publication, members see the committee in the Committee module. The first Management Committee meeting must be scheduled within 30 days of the election. Ordinary MC quorum is 5 of 7; regular meetings are at least monthly with seven clear days’ notice.',
  ),
];

const votingCharterSections = <VotingCharterSection>[
  VotingCharterSection(
    heading: 'Eligibility',
    points: [
      'Each Society member has one voting right, irrespective of the number of apartments owned.',
      'Joint ownership follows the designated-member rule in the bye-laws — only the designated member votes for that holding.',
      'A member with maintenance or common-expense arrears exceeding 60 days on the election date is disqualified from voting and contesting.',
      'Voting may be in person or through a valid written proxy submitted at least 48 hours before the meeting; one person may not act as proxy for more than one member.',
    ],
  ),
  VotingCharterSection(
    heading: 'Nomination',
    points: [
      'When the admin opens the nomination window, eligible members may propose themselves for Management Committee seats: President, Vice-President, Secretary, Treasurer, or Executive Member.',
      'Each nominee must write a short statement. Retiring members remain eligible for re-election.',
      'Self-nomination is only allowed inside the admin-set nomination open and close dates, and only for members not disqualified by arrears.',
    ],
  ),
  VotingCharterSection(
    heading: 'Voting method',
    points: [
      'Bye-laws permit Secret Ballot and Show of Hands. The chosen method must be recorded before polling begins.',
      'Each eligible member casts one vote. Separate per-office ballots are used only when that voting method is expressly established or approved.',
      'Votes are final after submission — ordinary administrators cannot edit them. Duplicate voting is blocked; the election record is immutable.',
      'Voting is only allowed inside the admin-set voting window and only once election quorum (3/4 of members) is satisfied.',
    ],
  ),
  VotingCharterSection(
    heading: 'Management Committee',
    points: [
      'The Management Committee has exactly seven members: President, Vice-President, Secretary, Treasurer, and three Executive Members, for a two-year term.',
      'Second- or third-place candidates are not automatically made members of the Management Committee.',
      'Vacancies are filled by majority of the remaining committee per the bye-laws. Removal requires Special Resolution and hearing; removed members are disqualified for two years.',
      'The first committee meeting must be within 30 days of election. Ordinary meeting quorum is 5 of 7; regular meetings at least monthly with seven clear days’ notice.',
    ],
  ),
  VotingCharterSection(
    heading: 'Documents & results',
    points: [
      'Admin may attach circulars, letters, or other society documents to the election; members can open them from the poll.',
      'After voting closes, results are tallied and audited. A complete Election Report and AGM Election Minutes are generated on completion.',
      'Elected committee names appear in the residents’ Committee module only after the admin publishes the roster.',
      'This charter can be downloaded as a PDF and shared with all members (for example via WhatsApp).',
    ],
  ),
];

const _hiSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'प्रबंध समिति के सात पद जानें',
    detail:
        'प्रबंध समिति में सात सदस्य होते हैं: अध्यक्ष, उपाध्यक्ष, सचिव, कोषाध्यक्ष और तीन कार्यकारिणी सदस्य। कार्यकाल दो वर्ष है; सेवानिवृत्त सदस्य पुनः चुनाव लड़ सकते हैं।',
  ),
  VotingCharterStep(
    title: 'नामांकन विंडो में नामांकन करें',
    detail:
        'नामांकन खुला होने पर पात्र सदस्य (60 दिनों से अधिक रखरखाव बकाया न हो) खुली सीट के लिए संक्षिप्त विवरण के साथ स्वयं नामांकन कर सकते हैं।',
  ),
  VotingCharterStep(
    title: 'अपना मत डालें',
    detail:
        'प्रत्येक पात्र सदस्य को एक मत है। मतदान गुप्त मतपत्र या हाथ उठाकर — विधि मतदान से पहले दर्ज की जाती है। प्रॉक्सी के लिए बैठक से कम-से-कम 48 घंटे पूर्व लिखित प्राधिकरण आवश्यक है (एक व्यक्ति केवल एक सदस्य का प्रॉक्सी हो सकता है)।',
  ),
  VotingCharterStep(
    title: 'कोरम और पात्रता',
    detail:
        'चुनाव कोरम कुल सदस्यों का 3/4 है (30 सदस्यों के लिए न्यूनतम 23)। चुनाव तिथि पर 60 दिनों से अधिक रखरखाव/साझा व्यय बकाया वाले सदस्य मतदान या चुनाव नहीं लड़ सकते। संयुक्त स्वामित्व में नामित सदस्य नियम लागू होता है।',
  ),
  VotingCharterStep(
    title: 'परिणाम और सात पद',
    detail:
        'घोषित परिणाम प्रबंध समिति के सात पद भरते हैं। दूसरे या तीसरे स्थान के उम्मीदवार स्वतः समिति सदस्य नहीं बनते। रिक्तियाँ उपविधि की रिक्ति प्रक्रिया से भरी जाती हैं।',
  ),
  VotingCharterStep(
    title: 'रोस्टर प्रकाशित करें और पहली बैठक',
    detail:
        'प्रकाशन के बाद सदस्य समिति मॉड्यूल में समिति देख सकते हैं। पहली प्रबंध समिति बैठक चुनाव के 30 दिनों के भीतर निर्धारित होनी चाहिए। सामान्य बैठक कोरम 7 में से 5 है; नियमित बैठकें कम-से-कम मासिक, सात स्पष्ट दिनों की सूचना के साथ।',
  ),
];

const _hiSections = <VotingCharterSection>[
  VotingCharterSection(
    heading: 'पात्रता',
    points: [
      'प्रत्येक सोसाइटी सदस्य को एक मतदान अधिकार है — चाहे उनके पास कितने भी अपार्टमेंट हों।',
      'संयुक्त स्वामित्व में उपविधि का नामित-सदस्य नियम लागू होता है — उस धारण के लिए केवल नामित सदस्य मतदान करता है।',
      'चुनाव तिथि पर 60 दिनों से अधिक रखरखाव या साझा व्यय बकाया वाले सदस्य मतदान और चुनाव लड़ने से अयोग्य हैं।',
      'मतदान व्यक्तिगत रूप से या बैठक से कम-से-कम 48 घंटे पूर्व जमा वैध लिखित प्रॉक्सी से हो सकता है; एक व्यक्ति एक से अधिक सदस्य का प्रॉक्सी नहीं हो सकता।',
    ],
  ),
  VotingCharterSection(
    heading: 'नामांकन',
    points: [
      'जब एडमिन नामांकन विंडो खोलता है, पात्र सदस्य प्रबंध समिति के पदों — अध्यक्ष, उपाध्यक्ष, सचिव, कोषाध्यक्ष या कार्यकारिणी सदस्य — के लिए स्वयं को प्रस्तावित कर सकते हैं।',
      'प्रत्येक नामांकित को संक्षिप्त विवरण लिखना होगा। सेवानिवृत्त सदस्य पुनः चुनाव के लिए पात्र रहते हैं।',
      'स्व-नामांकन केवल एडमिन द्वारा निर्धारित नामांकन तिथियों में, और बकाया से अयोग्य न होने वाले सदस्यों के लिए ही अनुमत है।',
    ],
  ),
  VotingCharterSection(
    heading: 'मतदान विधि',
    points: [
      'उपविधियाँ गुप्त मतपत्र और हाथ उठाकर मतदान दोनों की अनुमति देती हैं। चुनी गई विधि मतदान शुरू होने से पहले दर्ज करनी होगी।',
      'प्रत्येक पात्र सदस्य एक मत डालता है। प्रति-पद अलग मतपत्र केवल तभी जब वह मतदान विधि स्पष्ट रूप से स्थापित/अनुमोदित हो।',
      'जमा होने के बाद मत अंतिम हैं — सामान्य प्रशासक उन्हें संपादित नहीं कर सकते। दोहरा मतदान रोका जाता है; चुनाव अभिलेख अपरिवर्तनीय है।',
      'मतदान केवल एडमिन द्वारा निर्धारित मतदान विंडो में और चुनाव कोरम (सदस्यों का 3/4) पूरा होने पर ही अनुमत है।',
    ],
  ),
  VotingCharterSection(
    heading: 'प्रबंध समिति',
    points: [
      'प्रबंध समिति में ठीक सात सदस्य होते हैं: अध्यक्ष, उपाध्यक्ष, सचिव, कोषाध्यक्ष और तीन कार्यकारिणी सदस्य — दो वर्ष के कार्यकाल के लिए।',
      'दूसरे या तीसरे स्थान के उम्मीदवार स्वतः प्रबंध समिति के सदस्य नहीं बनते।',
      'रिक्तियाँ शेष समिति के बहुमत से उपविधि के अनुसार भरी जाती हैं। निष्कासन के लिए विशेष प्रस्ताव और सुनवाई आवश्यक है; निष्कासित सदस्य दो वर्ष के लिए अयोग्य रहते हैं।',
      'पहली समिति बैठक चुनाव के 30 दिनों के भीतर होनी चाहिए। सामान्य बैठक कोरम 7 में से 5; नियमित बैठकें कम-से-कम मासिक, सात स्पष्ट दिनों की सूचना के साथ।',
    ],
  ),
  VotingCharterSection(
    heading: 'दस्तावेज़ और परिणाम',
    points: [
      'एडमिन चुनाव में परिपत्र, पत्र या अन्य सोसाइटी दस्तावेज़ संलग्न कर सकता है; सदस्य उन्हें पोल से खोल सकते हैं।',
      'मतदान बंद होने के बाद परिणाम गिने और ऑडिट किए जाते हैं। पूर्ण होने पर पूर्ण चुनाव रिपोर्ट और वार्षिक आम सभा चुनाव कार्यवृत्त तैयार होते हैं।',
      'निर्वाचित समिति के नाम निवासी समिति मॉड्यूल में तभी दिखते हैं जब एडमिन रोस्टर प्रकाशित करता है।',
      'यह नियमपत्र पीडीएफ के रूप में प्राप्त करके सभी सदस्यों को (जैसे व्हाट्सऐप से) परिचालित किया जा सकता है।',
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
        'मतदान का अधिकार: प्रत्येक पात्र सदस्य को एक मत।',
        'प्रॉक्सी: लिखित प्राधिकरण के साथ, बैठक से कम-से-कम 48 घंटे पूर्व।',
        'चुनाव कोरम: कुल सदस्यों का 3/4। 30 सदस्यों के लिए न्यूनतम 23 सदस्य।',
      ],
      programHeading: 'सदस्यों के लिए चरणबद्ध कार्यक्रम',
      programIntro:
          'पंजीकृत उपविधियों के अनुसार सोसाइटी की सात-सदस्यीय प्रबंध समिति के चुनाव के लिए ये चरण अपनाएँ।',
      rulesHeading: 'उपविधि नियम',
      steps: _hiSteps,
      sections: _hiSections,
      footerNote: 'यह नियमपत्र पीडीएफ के रूप में प्राप्त करके सभी सदस्यों को (जैसे व्हाट्सऐप से) परिचालित किया जा सकता है।',
      shareMessage:
          'सोसाइटी चुनाव चार्टर — पंजीकृत उपविधियों के अनुसार समिति के 7 सदस्यों का चुनाव।',
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
    programHeading: 'Step-by-step program for members',
    programIntro: electionProgramIntro,
    rulesHeading: 'Bye-law rules',
    steps: electionProgramSteps,
    sections: votingCharterSections,
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
    buf.writeln();
  }
  buf.writeln(c.rulesHeading);
  buf.writeln();
  for (final sec in c.sections) {
    buf.writeln(sec.heading);
    for (final p in sec.points) {
      buf.writeln('• $p');
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
        : 'See full rules in the PDF (download Hindi / English PDF from the app).');
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
