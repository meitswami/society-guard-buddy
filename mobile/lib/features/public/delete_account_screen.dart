import 'package:flutter/material.dart';

import '../../core/export/export_kit.dart';
import '../../core/ui/ui.dart';
import 'contact_screen.dart';
import 'english_only_note.dart';
import 'legal_page_layout.dart';
import 'public_nav.dart';

/// Port of web `DeleteAccountPage` (`/delete-account`) — the Play Store account-deletion page.
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalPageScaffold(
      title: context.tr('Delete Account', 'खाता हटाएँ'),
      children: [
        const EnglishOnlyNote(),
        LegalText('', foreground: true, spans: [legalStrong(context, 'Last updated:'), const TextSpan(text: ' April 14, 2026')]),
        LegalText('This page is for account deletion requests for ', spans: [
          legalStrong(context, 'Kutumbika'),
          const TextSpan(text: ' by '),
          legalStrong(context, 'BrandZaha'),
          const TextSpan(text: '.'),
        ], bottom: 20),
        LegalSection(title: 'How to request account deletion', children: [
          LegalList(ordered: true, items: [
            [const TextSpan(text: 'Open the app and sign in using your registered account.')],
            [
              const TextSpan(
                  text: 'Go to your profile/settings screen and choose account deletion request, or contact your society administrator.'),
            ],
            [
              const TextSpan(text: 'If you cannot access the app, submit a request from the '),
              legalPageLink(context, 'Contact', PublicPage.contact),
              const TextSpan(text: ' page with your registered phone number and society/flat details.'),
            ],
            [
              const TextSpan(text: 'You can also email '),
              legalLink(context, kSupportEmail, () => ExportKit.email(kSupportEmail)),
              const TextSpan(text: ' or call '),
              legalLink(context, kSupportPhoneDisplay, () => ExportKit.call(kSupportPhoneE164)),
              const TextSpan(text: '.'),
            ],
          ]),
        ]),
        LegalSection(title: 'What data is deleted', children: [
          LegalList(items: LegalList.plain(const [
            'Account profile details linked to your login (for example name, phone, role, and login mapping).',
            'Push notification token registrations for your account/device.',
            'Any account-specific settings and access entries tied directly to your user record.',
          ])),
        ]),
        LegalSection(title: 'What data may be retained', children: [
          LegalList(items: LegalList.plain(const [
            'Society operational records (for example visitor approvals, guard logs, payment records, and audit/security logs) may '
                'be retained as required by society policy or legal obligations.',
            'Backups may retain deleted data for a limited period before permanent purge.',
          ])),
        ]),
        const LegalSection(title: 'Deletion timeline', children: [
          LegalText(
            'We typically process verified deletion requests within 7-30 days. Some legal/audit data may be retained longer where '
            'required by law.',
          ),
        ]),
      ],
    );
  }
}
