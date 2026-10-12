import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';

/// Legal documents are published in English only (same text as the web pages); in Hindi
/// mode a short note says so.
class EnglishOnlyNote extends StatelessWidget {
  const EnglishOnlyNote({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.lang != AppLang.hi) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: NoticeBanner(
        message: 'यह दस्तावेज़ केवल अंग्रेज़ी में उपलब्ध है (वेबसाइट के समान)।',
        tone: BadgeTone.info,
        icon: Icons.translate_rounded,
      ),
    );
  }
}
