import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/guard/guard_shell.dart';
import '../../features/public/about_screen.dart';
import '../../features/public/contact_screen.dart';
import '../../features/public/delete_account_screen.dart';
import '../../features/public/privacy_policy_screen.dart';
import '../../features/public/society_signup_screen.dart';
import '../../features/public/society_signup_status_screen.dart';
import '../../features/public/terms_screen.dart';
import '../../features/resident/resident_shell.dart';
import '../../features/superadmin/superadmin_shell.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';

/// Public pages (web `App.tsx` routes) that anyone can open, signed in or not.
const kPublicPaths = <String>{
  '/privacy',
  '/terms',
  '/contact',
  '/delete-account',
  '/about',
  '/society-signup',
  '/society-signup/status',
};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = ref.read(sessionProvider);

      if (session.isLoading) return null;
      if (kPublicPaths.contains(loc)) return null;

      final s = session.value;
      if (s is SessionUnauthenticated || s == null) {
        return loc == '/login' ? null : '/login';
      }
      if (s is SessionResident) {
        return loc.startsWith('/resident') ? null : '/resident';
      }
      if (s is SessionGuard) {
        return loc.startsWith('/guard') ? null : '/guard';
      }
      if (s is SessionAdmin) {
        return loc.startsWith('/admin') ? null : '/admin';
      }
      if (s is SessionSuperadmin) {
        return loc.startsWith('/superadmin') ? null : '/superadmin';
      }
      return '/login';
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/resident', builder: (_, __) => const ResidentShell()),
      GoRoute(path: '/guard', builder: (_, __) => const GuardShell()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminShell()),
      GoRoute(path: '/superadmin', builder: (_, __) => const SuperadminShell()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
      GoRoute(path: '/delete-account', builder: (_, __) => const DeleteAccountScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/society-signup', builder: (_, __) => const SocietySignupScreen()),
      GoRoute(path: '/society-signup/status', builder: (_, __) => const SocietySignupStatusScreen()),
    ],
  );
});
