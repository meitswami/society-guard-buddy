import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import 'english_only_note.dart';
import 'legal_page_layout.dart';
import 'public_nav.dart';

/// Port of web `TermsOfServicePage` (`/terms`).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalPageScaffold(
      title: context.t('login.footerTerms'),
      children: [
        const EnglishOnlyNote(),
        LegalText('', foreground: true, spans: [legalStrong(context, 'Last updated:'), const TextSpan(text: ' April 5, 2026')]),
        const LegalText(
          'These Terms of Service (“Terms”) govern your access to and use of Kutumbika (the “Service”), provided by BrandZaha '
          '(“we,” “us,” or “our”). By using the Service, you agree to these Terms. If you do not agree, do not use the Service.',
          bottom: 20,
        ),
        const LegalSection(title: '1. The Service', children: [
          LegalText(
            'Kutumbika offers tools for residential societies and related workflows, such as visitor management, logs, and '
            'associated features. Features may change over time. We do not guarantee uninterrupted or error-free operation.',
          ),
        ]),
        const LegalSection(title: '2. Eligibility and accounts', children: [
          LegalText(
            'You must have authority to use the Service on behalf of yourself or your organization. You are responsible for '
            'safeguarding credentials and for all activity under your account. Notify us promptly of unauthorized use via the '
            'contact details on our Contact page.',
          ),
        ]),
        LegalSection(title: '3. Acceptable use', children: [
          const LegalText('You agree not to:'),
          LegalList(items: LegalList.plain(const [
            'Violate applicable law or third-party rights;',
            'Attempt to gain unauthorized access to the Service, other accounts, or underlying systems;',
            'Interfere with or disrupt the Service or its infrastructure;',
            'Use the Service to harass, harm, or mislead others, or to collect data without proper basis;',
            'Reverse engineer, scrape, or automate the Service in violation of these Terms or our technical policies.',
          ])),
        ]),
        const LegalSection(title: '4. Societies and administrators', children: [
          LegalText(
            'Where the Service is deployed for a society or building, administrators may configure policies, access roles, and data '
            'practices. Their instructions may affect how your information is processed. Separate agreements between you and your '
            'society may also apply.',
          ),
        ]),
        const LegalSection(title: '5. Intellectual property', children: [
          LegalText(
            'The Service, including software, branding, and documentation, is owned by us or our licensors. We grant you a limited, '
            'non-exclusive, non-transferable right to use the Service according to these Terms. You retain rights in content you '
            'submit; you grant us a license to host, process, and display that content as needed to operate the Service.',
          ),
        ]),
        const LegalSection(title: '6. Disclaimers', children: [
          LegalText(
            'THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE,” WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, '
            'INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT, TO THE MAXIMUM EXTENT PERMITTED BY LAW.',
          ),
        ]),
        const LegalSection(title: '7. Limitation of liability', children: [
          LegalText(
            'TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR '
            'PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, OR GOODWILL, ARISING FROM YOUR USE OF THE SERVICE. OUR AGGREGATE '
            'LIABILITY FOR ANY CLAIM RELATING TO THE SERVICE SHALL NOT EXCEED THE GREATER OF (A) THE AMOUNTS YOU PAID US FOR THE '
            'SERVICE IN THE TWELVE MONTHS BEFORE THE CLAIM OR (B) ONE HUNDRED INDIAN RUPEES, IF NO FEES APPLIED.',
          ),
        ]),
        const LegalSection(title: '8. Indemnity', children: [
          LegalText(
            'You will defend and indemnify us and our affiliates against claims, damages, losses, and expenses (including reasonable '
            'legal fees) arising from your misuse of the Service, your content, or your violation of these Terms or applicable law.',
          ),
        ]),
        const LegalSection(title: '9. Suspension and termination', children: [
          LegalText(
            'We may suspend or terminate access to the Service for breach of these Terms, risk to security, or legal requirements. '
            'Provisions that by their nature should survive will survive termination.',
          ),
        ]),
        const LegalSection(title: '10. Governing law', children: [
          LegalText(
            'These Terms are governed by the laws of India, without regard to conflict-of-law principles. Courts in India shall have '
            'exclusive jurisdiction, subject to mandatory consumer protections where applicable.',
          ),
        ]),
        const LegalSection(title: '11. Changes', children: [
          LegalText(
            'We may modify these Terms by posting an updated version. Material changes may be communicated through the Service or '
            'other reasonable means. Continued use after the effective date constitutes acceptance unless law requires otherwise.',
          ),
        ]),
        LegalSection(title: '12. Contact', children: [
          LegalText('For questions about these Terms, visit our ', spans: [
            legalPageLink(context, 'Contact', PublicPage.contact),
            const TextSpan(text: ' page.'),
          ]),
        ]),
      ],
    );
  }
}
