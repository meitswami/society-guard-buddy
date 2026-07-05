import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../shared/widgets/biometric_enrollment_prompt.dart';
import 'guard_dashboard_screen.dart';
import 'guard_entry_screen.dart';
import 'guard_more_menu_screen.dart';
import 'guard_visitors_screen.dart';

class GuardShell extends ConsumerStatefulWidget {
  const GuardShell({super.key});

  @override
  ConsumerState<GuardShell> createState() => _GuardShellState();
}

class _GuardShellState extends ConsumerState<GuardShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionGuard) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final brand = KutumbikaBrandTheme.of(context);
    final pages = [
      GuardDashboardScreen(session: session),
      GuardEntryScreen(session: session),
      GuardVisitorsScreen(session: session),
      GuardMoreMenuScreen(session: session),
    ];

    return BiometricEnrollmentPrompt(
      session: session,
      child: Scaffold(
      appBar: AppBar(
        title: Text('Guard · ${session.guard.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout(
                    guardShiftId: session.shiftId,
                  );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: brand.primaryLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_outlined),
            selectedIcon: Icon(Icons.person_add),
            label: 'Entry',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Visitors',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    ),
    );
  }
}
