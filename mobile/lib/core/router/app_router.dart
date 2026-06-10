import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/guard/guard_shell.dart';
import '../../features/resident/resident_shell.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';

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
      return '/login';
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/resident', builder: (_, __) => const ResidentShell()),
      GoRoute(path: '/guard', builder: (_, __) => const GuardShell()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminShell()),
    ],
  );
});
