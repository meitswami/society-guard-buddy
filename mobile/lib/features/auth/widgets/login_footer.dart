import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../public/public_nav.dart';

/// Port of web `LoginFooter`: Privacy | Terms | Contact | About + copyright line.
class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget link(String key, PublicPage page) => InkWell(
          onTap: () => PublicNav.open(context, page),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(context.t(key), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, height: 1.2, color: t.mutedForeground)),
          ),
        );
    final sep = Text('|', style: TextStyle(fontSize: 10, color: t.border));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTokens.tint(t.background, 0.95),
        border: Border(top: BorderSide(color: AppTokens.tint(t.border, 0.6))),
      ),
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom * 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              link('login.footerPrivacy', PublicPage.privacy),
              sep,
              link('login.footerTerms', PublicPage.terms),
              sep,
              link('login.footerContact', PublicPage.contact),
              sep,
              link('login.footerAbout', PublicPage.about),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.t('app.footer'), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: t.mutedForeground)),
        ],
      ),
    );
  }
}
