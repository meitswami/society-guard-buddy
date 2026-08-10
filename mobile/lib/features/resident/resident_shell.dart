import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../../services/society_sound_service.dart';
import '../shared/widgets/biometric_enrollment_prompt.dart';
import '../home/resident_home_screen.dart';
import 'screens/approvals_screen.dart';
import 'screens/directory_screen.dart';
import 'screens/more_menu_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/passes_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/profile_screen.dart';

class ResidentShell extends ConsumerStatefulWidget {
  const ResidentShell({super.key});

  @override
  ConsumerState<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends ConsumerState<ResidentShell> {
  int _index = 0;
  final _soundService = SocietySoundService();
  String? _signatureTuneSocietyId;

  void _goTo(int index) => setState(() => _index = index);

  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }

  Future<void> _maybePlaySignatureTune(SessionResident session) async {
    if (_signatureTuneSocietyId == session.societyId) return;
    _signatureTuneSocietyId = session.societyId;
    await _soundService.playSignatureTuneOnOpen(session.societyId);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionResident) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_signatureTuneSocietyId != session.societyId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybePlaySignatureTune(session));
      });
    }

    final brand = KutumbikaBrandTheme.of(context);
    final pages = [
      ResidentHomeScreen(
        session: session,
        onNavigate: (tab) {
          switch (tab) {
            case ResidentHomeTab.approvals:
              _goTo(2);
            case ResidentHomeTab.passes:
              _goTo(3);
            case ResidentHomeTab.notifications:
              _goTo(1);
            case ResidentHomeTab.directory:
              _goTo(4);
            case ResidentHomeTab.more:
              _goTo(5);
            case ResidentHomeTab.maintenance:
              _goTo(6);
            default:
              break;
          }
        },
      ),
      NotificationsScreen(session: session),
      ApprovalsScreen(session: session),
      PassesScreen(session: session),
      DirectoryScreen(session: session),
      MoreMenuScreen(session: session, onSelect: _goTo),
      PaymentsScreen(session: session),
      ProfileScreen(session: session),
    ];

    return BiometricEnrollmentPrompt(
      session: session,
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index > 4 ? 4 : _index,
          onDestinationSelected: (i) {
            if (i == 4) {
              _goTo(7);
            } else {
              _goTo(i);
            }
          },
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            const NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
            const NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg), label: 'Approvals'),
            const NavigationDestination(icon: Icon(Icons.key_outlined), selectedIcon: Icon(Icons.key), label: 'Passes'),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: _index == 6 ? brand.primary : null),
              selectedIcon: Icon(Icons.person, color: brand.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
