import 'package:flutter/material.dart';

import '../../core/export/export_kit.dart';
import '../../core/ui/ui.dart';
import 'legal_page_layout.dart';
import 'public_nav.dart';

const kSupportPhoneDisplay = '+91 86194 36041';
const kSupportPhoneE164 = '+918619436041';
const kSupportEmail = 'info@brandzaha.com';

/// Port of web `ContactPage` (`/contact`).
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(BuildContext context, Future<bool> Function() action) async {
    var ok = false;
    try {
      ok = await action();
    } catch (_) {}
    if (!ok && context.mounted) {
      AppFeedback.toast(context, context.tr('Could not open the app for this action.', 'इस कार्य के लिए ऐप नहीं खुल सका।'), tone: BadgeTone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget card({required IconData icon, required String title, required String description, required String value, required VoidCallback onTap}) =>
        CardSection(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: t.primary),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.foreground)),
                ],
              ),
              const SizedBox(height: 4),
              Text(description, style: AppText.body(context).copyWith(color: t.mutedForeground)),
              const SizedBox(height: 12),
              InkWell(
                onTap: onTap,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary),
                ),
              ),
            ],
          ),
        );

    return LegalPageScaffold(
      title: context.t('login.footerContact'),
      children: [
        LegalText(
          context.tr(
            'Reach BrandZaha for support, billing, or questions about Kutumbika. We aim to respond within reasonable business hours.',
            'सहायता, बिलिंग या कुटुम्बिका से जुड़े प्रश्नों के लिए BrandZaha से संपर्क करें। हम उचित कार्य-समय में उत्तर देने का प्रयास करते हैं।',
          ),
          bottom: 24,
        ),
        card(
          icon: Icons.phone_outlined,
          title: context.tr('Phone', 'फोन'),
          description: context.tr('Call during business hours or leave a voicemail.', 'कार्य-समय में कॉल करें या वॉइसमेल छोड़ें।'),
          value: kSupportPhoneDisplay,
          onTap: () => _launch(context, () => ExportKit.call(kSupportPhoneE164)),
        ),
        card(
          icon: Icons.mail_outline,
          title: context.tr('Email', 'ई-मेल'),
          description: context.tr('For general inquiries and partnership questions.', 'सामान्य पूछताछ और साझेदारी प्रश्नों के लिए।'),
          value: kSupportEmail,
          onTap: () => _launch(context, () => ExportKit.email(kSupportEmail)),
        ),
        const SizedBox(height: 8),
        LegalText(context.tr('See also ', 'यह भी देखें: '), size: 12, spans: [
          legalPageLink(context, context.t('login.footerPrivacy'), PublicPage.privacy),
          TextSpan(text: context.tr(' and ', ' और ')),
          legalPageLink(context, context.t('login.footerTerms'), PublicPage.terms),
          const TextSpan(text: '.'),
        ]),
      ],
    );
  }
}
