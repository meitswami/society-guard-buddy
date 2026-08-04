import 'package:url_launcher/url_launcher.dart';

/// Member-facing election & committee formation charter (EN + HI for PDF).
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
    required this.programHeading,
    required this.programIntro,
    required this.rulesHeading,
    required this.steps,
    required this.sections,
    required this.footerNote,
    required this.shareMessage,
  });

  final String title;
  final String programHeading;
  final String programIntro;
  final String rulesHeading;
  final List<VotingCharterStep> steps;
  final List<VotingCharterSection> sections;
  final String footerNote;
  final String shareMessage;
}

const votingCharterTitle = 'Voting & Committee Formation Charter';

const votingCharterShareMessage =
    'Society Voting & Committee Formation Charter — please read the step-by-step program for the executive election and Managing Committee formation.';

const electionProgramIntro =
    'Follow these steps to understand the executive election poll and how the Managing Committee of the society is formed.';

const electionProgramSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'Know the three executive posts',
    detail:
        'The election poll is for President, Secretary and Treasurer only. Ranked voting (Borda) decides the winner of each post.',
  ),
  VotingCharterStep(
    title: 'Nominate during the nomination window',
    detail:
        'When nominations are open, eligible members may self-nominate for any of the three posts with a short statement.',
  ),
  VotingCharterStep(
    title: 'Cast your ranked ballot',
    detail:
        'In the voting window, rank every candidate in each post (1 = highest preference). One vote per person; up to two ballots per flat when both spouses vote.',
  ),
  VotingCharterStep(
    title: 'Winners take the three posts',
    detail:
        'After tally, the highest-scoring candidate for each post is elected (if they meet any minimum winning score set by the admin).',
  ),
  VotingCharterStep(
    title: '2nd & 3rd place may join the Committee',
    detail:
        'Candidates who remain unelected in 2nd or 3rd place for President, Secretary or Treasurer may be nominated as other executive members of the Managing Committee.',
  ),
  VotingCharterStep(
    title: 'Committee size: at least 7, target 15',
    detail:
        'The Managing Committee is formed with seven or more members. The Society proposes a committee of minimum fifteen members.',
  ),
  VotingCharterStep(
    title: 'Fill remaining seats',
    detail:
        'If the committee does not reach 15 through winners and 2nd/3rd place nominations, interested members may join voluntarily. If seats still remain, the executive committee proposes names.',
  ),
  VotingCharterStep(
    title: 'Publish the full roster',
    detail:
        'When formation is complete (minimum 7), the admin publishes the roster. Members then see the full committee in the Committee module.',
  ),
];

const votingCharterSections = <VotingCharterSection>[
  VotingCharterSection(
    heading: 'Eligibility',
    points: [
      'Every registered owner and their spouse may cast one ranked ballot each.',
      'One vote per person — even if you own more than one flat, you vote only once (matched by login / phone).',
      'Up to two ballots may come from the same flat when both spouses vote separately.',
    ],
  ),
  VotingCharterSection(
    heading: 'Nomination',
    points: [
      'When the admin opens the nomination window, members may propose themselves for three executive posts: President, Secretary, or Treasurer.',
      'Each nominee must write a short statement explaining why they should be chosen or given preference.',
      'Self-nomination is only allowed inside the admin-set nomination open and close dates.',
    ],
  ),
  VotingCharterSection(
    heading: 'Voting method',
    points: [
      'Rank every candidate in each post — 1 = highest preference (maximum rating).',
      'You must rank all candidates in a post; duplicate ranks are not allowed.',
      'Scores use Borda priority points: top rank gets the highest score; the candidate with the highest total is elected if they meet the admin’s minimum winning score for that post.',
      'You may include yourself in your rankings.',
      'Voting is only allowed inside the admin-set voting open and close dates.',
    ],
  ),
  VotingCharterSection(
    heading: 'Managing Committee formation',
    points: [
      'After the three executive winners are declared, candidates placed 2nd or 3rd (unelected) for President, Secretary or Treasurer may be nominated into the Managing Committee as other executive members.',
      'The committee is formed with seven or more members. The Society proposes a minimum of fifteen members.',
      'If 15 seats are not filled by winners plus 2nd/3rd place nominations, members who volunteer may be included.',
      'If seats still remain after voluntary interest, the executive committee proposes names of members to complete the roster.',
      'The full committee appears for residents only after the admin publishes the formed roster.',
    ],
  ),
  VotingCharterSection(
    heading: 'Documents & results',
    points: [
      'Admin may attach circulars, letters, or other society/personal documents to the election; members can open them from the poll.',
      'After the voting window closes, the admin tallies results. Winners and 2nd/3rd place candidates are visible in the admin portal first.',
      'Elected and formed committee names appear in the residents’ Committee module only after the admin publishes them to the roster.',
      'This charter can be downloaded as a PDF and shared with all members (for example via WhatsApp).',
    ],
  ),
];

const _hiSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'तीन कार्यकारी पद जानें',
    detail:
        'चुनाव पोल केवल अध्यक्ष, सचिव और कोषाध्यक्ष के लिए है। प्रत्येक पद का विजेता क्रमबद्ध (बोर्डा) मतदान से तय होता है।',
  ),
  VotingCharterStep(
    title: 'नामांकन विंडो में नामांकन करें',
    detail:
        'नामांकन खुला होने पर पात्र सदस्य संक्षिप्त विवरण के साथ तीन में से किसी भी पद के लिए स्वयं नामांकन कर सकते हैं।',
  ),
  VotingCharterStep(
    title: 'अपना क्रमबद्ध मतपत्र डालें',
    detail:
        'मतदान विंडो में प्रत्येक पद के सभी उम्मीदवारों को रैंक दें (1 = सर्वोच्च प्राथमिकता)। प्रति व्यक्ति एक वोट; दोनों जीवनसाथी मतदान करें तो प्रति फ्लैट अधिकतम दो मतपत्र।',
  ),
  VotingCharterStep(
    title: 'विजेता तीन पद ग्रहण करते हैं',
    detail:
        'परिणाम गणना के बाद प्रत्येक पद पर सर्वाधिक अंक वाला उम्मीदवार निर्वाचित होता है (यदि एडमिन की न्यूनतम जीत अंक सीमा पूरी हो)।',
  ),
  VotingCharterStep(
    title: 'दूसरे व तीसरे स्थान समिति में शामिल हो सकते हैं',
    detail:
        'अध्यक्ष, सचिव या कोषाध्यक्ष के चुनाव में दूसरे या तीसरे स्थान पर रहकर निर्वाचित न हुए उम्मीदवार प्रबंध समिति के अन्य कार्यकारी सदस्यों के रूप में नामांकित हो सकते हैं।',
  ),
  VotingCharterStep(
    title: 'समिति आकार: कम से कम 7, लक्ष्य 15',
    detail:
        'प्रबंध समिति सात या अधिक सदस्यों से गठित होती है। सोसाइटी न्यूनतम पंद्रह सदस्यों की समिति प्रस्तावित करती है।',
  ),
  VotingCharterStep(
    title: 'शेष सीटें भरें',
    detail:
        'यदि विजेताओं और दूसरे/तीसरे स्थान के नामांकन से समिति 15 तक न पहुँचे, इच्छुक सदस्य स्वेच्छा से जुड़ सकते हैं। फिर भी सीटें बचें तो कार्यकारी समिति नाम प्रस्तावित करेगी।',
  ),
  VotingCharterStep(
    title: 'पूर्ण रोस्टर प्रकाशित करें',
    detail:
        'गठन पूरा होने पर (न्यूनतम 7) एडमिन रोस्टर प्रकाशित करता है। इसके बाद सदस्य समिति मॉड्यूल में पूरी समिति देख सकते हैं।',
  ),
];

const _hiSections = <VotingCharterSection>[
  VotingCharterSection(
    heading: 'पात्रता',
    points: [
      'प्रत्येक पंजीकृत मालिक और उनके जीवनसाथी एक-एक क्रमबद्ध मतपत्र डाल सकते हैं।',
      'प्रति व्यक्ति एक वोट — एक से अधिक फ्लैट होने पर भी आप केवल एक बार मतदान करते हैं (लॉगिन / फोन से मिलाया जाता है)।',
      'जब दोनों जीवनसाथी अलग-अलग मतदान करें तो एक ही फ्लैट से अधिकतम दो मतपत्र आ सकते हैं।',
    ],
  ),
  VotingCharterSection(
    heading: 'नामांकन',
    points: [
      'जब एडमिन नामांकन विंडो खोलता है, सदस्य तीन कार्यकारी पदों — अध्यक्ष, सचिव या कोषाध्यक्ष — के लिए स्वयं को प्रस्तावित कर सकते हैं।',
      'प्रत्येक नामांकित को यह बताते हुए एक संक्षिप्त विवरण लिखना होगा कि उन्हें क्यों चुना जाए या प्राथमिकता दी जाए।',
      'स्व-नामांकन केवल एडमिन द्वारा निर्धारित नामांकन आरंभ और समाप्ति तिथियों के बीच ही अनुमत है।',
    ],
  ),
  VotingCharterSection(
    heading: 'मतदान विधि',
    points: [
      'प्रत्येक पद में सभी उम्मीदवारों को रैंक दें — 1 = उच्चतम प्राथमिकता (अधिकतम रेटिंग)।',
      'एक पद में सभी उम्मीदवारों को रैंक देना अनिवार्य है; समान रैंक की अनुमति नहीं है।',
      'अंक बोर्डा प्राथमिकता पद्धति से मिलते हैं: शीर्ष रैंक को सर्वाधिक अंक; सबसे अधिक कुल अंक वाला उम्मीदवार चुना जाता है यदि वह उस पद के लिए एडमिन की न्यूनतम जीत अंक सीमा पूरी करता है।',
      'आप अपनी रैंकिंग में स्वयं को भी शामिल कर सकते हैं।',
      'मतदान केवल एडमिन द्वारा निर्धारित मतदान आरंभ और समाप्ति तिथियों के बीच ही अनुमत है।',
    ],
  ),
  VotingCharterSection(
    heading: 'प्रबंध समिति का गठन',
    points: [
      'तीन कार्यकारी विजेताओं की घोषणा के बाद, अध्यक्ष/सचिव/कोषाध्यक्ष में दूसरे या तीसरे स्थान पर रहकर निर्वाचित न हुए उम्मीदवार प्रबंध समिति में अन्य कार्यकारी सदस्यों के रूप में नामांकित हो सकते हैं।',
      'समिति सात या अधिक सदस्यों से गठित होती है। सोसाइटी न्यूनतम पंद्रह सदस्यों का प्रस्ताव करती है।',
      'यदि विजेताओं और दूसरे/तीसरे स्थान के नामांकन से 15 सीटें न भरें, स्वेच्छा से इच्छुक सदस्यों को शामिल किया जा सकता है।',
      'स्वैच्छिक रुचि के बाद भी सीटें बचें तो कार्यकारी समिति रोस्टर पूरा करने हेतु सदस्यों के नाम प्रस्तावित करेगी।',
      'गठित रोस्टर एडमिन द्वारा प्रकाशित करने के बाद ही निवासियों को पूरी समिति दिखती है।',
    ],
  ),
  VotingCharterSection(
    heading: 'दस्तावेज़ और परिणाम',
    points: [
      'एडमिन चुनाव में परिपत्र, पत्र या अन्य सोसाइटी/व्यक्तिगत दस्तावेज़ संलग्न कर सकता है; सदस्य उन्हें पोल से खोल सकते हैं।',
      'मतदान विंडो बंद होने के बाद एडमिन परिणाम गिनता है। विजेता और दूसरे/तीसरे स्थान पहले एडमिन पोर्टल में दिखते हैं।',
      'निर्वाचित और गठित समिति के नाम निवासी समिति मॉड्यूल में तभी दिखते हैं जब एडमिन उन्हें रोस्टर पर प्रकाशित करता है।',
      'यह चार्टर PDF के रूप में डाउनलोड करके सभी सदस्यों को (जैसे WhatsApp से) परिचालित किया जा सकता है।',
    ],
  ),
];

VotingCharterContent votingCharterContent(CharterLang lang) {
  if (lang == CharterLang.hi) {
    return const VotingCharterContent(
      title: 'मतदान और समिति गठन चार्टर',
      programHeading: 'सदस्यों के लिए चरणबद्ध कार्यक्रम',
      programIntro:
          'कार्यकारी चुनाव पोल और सोसाइटी की प्रबंध समिति कैसे बनती है — यह समझने के लिए ये चरण अपनाएँ।',
      rulesHeading: 'चार्टर नियम',
      steps: _hiSteps,
      sections: _hiSections,
      footerNote: 'यह चार्टर PDF के रूप में डाउनलोड करके सभी सदस्यों को (जैसे WhatsApp से) परिचालित किया जा सकता है।',
      shareMessage:
          'सोसाइटी मतदान और समिति गठन चार्टर — कार्यकारी चुनाव और प्रबंध समिति गठन का चरणबद्ध कार्यक्रम कृपया पढ़ें।',
    );
  }
  return VotingCharterContent(
    title: votingCharterTitle,
    programHeading: 'Step-by-step program for members',
    programIntro: electionProgramIntro,
    rulesHeading: 'Charter rules',
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
  final body = '${votingCharterShareMessageFor(lang)}\n\n${buildVotingCharterPlainText(societyName: societyName, lang: lang)}';
  // WhatsApp URL length limits — keep share message + full program; truncate rules if needed.
  var text = body;
  const maxLen = 3500;
  if (text.length > maxLen) {
    text = '${text.substring(0, maxLen - 20)}\n\n…(continued in app)';
  }
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
