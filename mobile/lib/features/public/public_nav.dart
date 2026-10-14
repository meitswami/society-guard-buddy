import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'about_screen.dart';
import 'contact_screen.dart';
import 'delete_account_screen.dart';
import 'privacy_policy_screen.dart';
import 'society_signup_screen.dart';
import 'society_signup_status_screen.dart';
import 'terms_screen.dart';

/// Public pages (web routes `/privacy`, `/terms`, `/contact`, `/delete-account`, `/about`,
/// `/society-signup`, `/society-signup/status`).
enum PublicPage { privacy, terms, contact, deleteAccount, about, societySignup, societySignupStatus }

abstract final class PublicNav {
  static Widget build(PublicPage page) => switch (page) {
        PublicPage.privacy => const PrivacyPolicyScreen(),
        PublicPage.terms => const TermsScreen(),
        PublicPage.contact => const ContactScreen(),
        PublicPage.deleteAccount => const DeleteAccountScreen(),
        PublicPage.about => const AboutScreen(),
        PublicPage.societySignup => const SocietySignupScreen(),
        PublicPage.societySignupStatus => const SocietySignupStatusScreen(),
      };

  /// Pushes a public page on the current navigator (works with or without router paths).
  static Future<void> open(BuildContext context, PublicPage page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => build(page)));

  /// Web "← Home": pop back, or go to the login route when the page was opened directly.
  static void leave(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    GoRouter.maybeOf(context)?.go('/login');
  }

  /// Back to the login screen from deep inside the signup flow.
  static void goToLogin(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    GoRouter.maybeOf(context)?.go('/login');
  }
}
