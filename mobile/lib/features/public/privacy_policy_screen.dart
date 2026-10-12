import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import 'english_only_note.dart';
import 'legal_page_layout.dart';
import 'public_nav.dart';

/// Port of web `PrivacyPolicyPage` (`/privacy`).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalPageScaffold(
      title: context.t('login.footerPrivacy'),
      children: [
        const EnglishOnlyNote(),
        LegalText('', foreground: true, spans: [legalStrong(context, 'Last updated:'), const TextSpan(text: ' April 5, 2026')]),
        const LegalText(
          'BrandZaha (“we,” “us,” or “our”) operates Kutumbika (the “Service”). This Privacy Policy describes how we collect, '
          'use, and share information when you use our websites, mobile applications, and related services.',
          bottom: 20,
        ),
        LegalSection(title: '1. Information we collect', children: [
          LegalList(items: [
            [
              legalStrong(context, 'Account and profile data:'),
              const TextSpan(
                  text: ' such as name, phone number, email (if provided), society or building identifiers, and role (for example '
                      'guard, resident, or administrator).'),
            ],
            [
              legalStrong(context, 'Operational data:'),
              const TextSpan(
                  text: ' visitor and vehicle logs, directory information you or your society chooses to store, photos or notes '
                      'captured as part of entry workflows, and similar records needed to run the Service.'),
            ],
            [
              legalStrong(context, 'Device and technical data:'),
              const TextSpan(
                  text: ' device type, operating system, app version, push notification tokens, and diagnostic or security logs.'),
            ],
          ]),
        ]),
        LegalSection(title: '2. How we use information', children: [
          const LegalText('We use information to:'),
          LegalList(
              items: LegalList.plain(const [
            'Provide, maintain, and improve the Service;',
            'Authenticate users, enforce access controls, and protect against fraud or abuse;',
            'Send service-related messages (including security alerts and, where enabled, push notifications);',
            'Comply with law and respond to lawful requests.',
          ])),
        ]),
        const LegalSection(title: '3. Sharing', children: [
          LegalText(
            'We may share information with service providers who assist us (for example hosting, authentication, messaging, or '
            'analytics), strictly as needed to operate the Service. We may disclose information if required by law or to protect '
            'rights, safety, and security. Societies or administrators may access data submitted within their own deployment '
            'according to their policies.',
          ),
        ]),
        const LegalSection(title: '4. Retention', children: [
          LegalText(
            'We retain information for as long as necessary to provide the Service, meet legal obligations, resolve disputes, and '
            'enforce our agreements. Retention periods may depend on your society’s configuration and applicable law.',
          ),
        ]),
        const LegalSection(title: '5. Security', children: [
          LegalText(
            'We implement reasonable technical and organizational measures designed to protect information. No method of '
            'transmission or storage is completely secure; use the Service at your own risk alongside your organization’s policies.',
          ),
        ]),
        LegalSection(title: '6. Your choices', children: [
          const LegalText(
            'Depending on your region, you may have rights to access, correct, delete, or restrict processing of your personal '
            'information, or to object to certain processing. Contact us using the details on the Contact page. We may need to '
            'verify your request.',
          ),
          LegalText('For account deletion instructions, see ', spans: [
            legalPageLink(context, 'Delete Account', PublicPage.deleteAccount),
            const TextSpan(text: '.'),
          ]),
        ]),
        const LegalSection(title: '7. Children', children: [
          LegalText(
            'The Service is not directed at children under 13 (or the minimum age in your jurisdiction). We do not knowingly collect '
            'personal information from children.',
          ),
        ]),
        const LegalSection(title: '8. International transfers', children: [
          LegalText(
            'If you use the Service from outside the country where our systems are located, your information may be transferred and '
            'processed in other countries where laws may differ.',
          ),
        ]),
        const LegalSection(title: '9. Changes', children: [
          LegalText(
            'We may update this Privacy Policy from time to time. We will post the updated version and revise the “Last updated” '
            'date. Continued use of the Service after changes constitutes acceptance unless law requires otherwise.',
          ),
        ]),
        LegalSection(title: '10. Contact', children: [
          LegalText('Questions about this policy: see our ', spans: [
            legalPageLink(context, 'Contact', PublicPage.contact),
            const TextSpan(text: ' page.'),
          ]),
        ]),
      ],
    );
  }
}
