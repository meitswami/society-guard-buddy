import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import 'superadmin_console.dart';
import 'superadmin_i18n.dart';
import 'tabs/admins_tab.dart';
import 'tabs/maintenance_tab.dart';
import 'tabs/onboarding_tab.dart';
import 'tabs/roles_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/societies_tab.dart';
import 'tabs/support_tickets_tab.dart';
import 'tabs/tab_page.dart';
import 'tabs/tour_tab.dart';

/// Web `Tab` ids of `SuperadminDashboard.tsx`, in bottom-nav order.
enum SuperTab {
  societies,
  roles,
  admins,
  maintenance,
  onboarding,
  settings,
  support,
  tour
}

/// Superadmin console — port of `SuperadminDashboard.tsx`: header (crown, name, logout),
/// shared society selection, the eight tabs and the bottom navigation with footer.
class SuperadminShell extends ConsumerStatefulWidget {
  const SuperadminShell({super.key});

  @override
  ConsumerState<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends ConsumerState<SuperadminShell> {
  SuperTab _tab = SuperTab.societies;
  final Set<SuperTab> _visited = {SuperTab.societies};
  SuperadminConsole? _console;
  DateTime? _lastBack;
  bool _tourChecked = false;

  SuperadminConsole _consoleFor(SessionSuperadmin s) {
    final existing = _console;
    if (existing != null && existing.session.id == s.id) return existing;
    existing?.dispose();
    final c = SuperadminConsole(session: s);
    _console = c;
    Future.microtask(c.loadAll);
    return c;
  }

  @override
  void dispose() {
    _console?.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmLogoutUser'),
      message: context.t('swal.confirmLogoutUserText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
    );
    if (ok) await ref.read(sessionProvider.notifier).logout();
  }

  void _go(SuperTab tab) => setState(() {
        _tab = tab;
        _visited.add(tab);
      });

  void _onBack() {
    if (_tab != SuperTab.societies) {
      _go(SuperTab.societies);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null &&
        now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    AppFeedback.toast(
        context,
        context.tr(
            'Press back again to exit', 'बाहर जाने के लिए फिर से बैक दबाएँ'));
  }

  String _label(SuperTab tab) => switch (tab) {
        SuperTab.societies => context.t('superadmin.societies'),
        SuperTab.roles => context.t('superadmin.roles'),
        SuperTab.admins => context.t('superadmin.admins'),
        SuperTab.maintenance => context.st('sa.tab.maintenance'),
        SuperTab.onboarding => context.st('sa.tab.payments'),
        SuperTab.settings => context.t('nav.settings'),
        SuperTab.support => context.st('sa.tab.support'),
        SuperTab.tour => context.t('nav.tour'),
      };

  IconData _icon(SuperTab tab) => switch (tab) {
        SuperTab.societies => Icons.apartment_outlined,
        SuperTab.roles => Icons.sell_outlined,
        SuperTab.admins => Icons.group_outlined,
        SuperTab.maintenance => Icons.storage_outlined,
        SuperTab.onboarding => Icons.credit_card_outlined,
        SuperTab.settings => Icons.workspace_premium_outlined,
        SuperTab.support => Icons.headset_mic_outlined,
        SuperTab.tour => Icons.auto_awesome_outlined,
      };

  Widget _body(SuperTab tab, SuperadminTabContext ctx) => switch (tab) {
        SuperTab.societies => SocietiesTab(ctx: ctx),
        SuperTab.roles => RolesTab(ctx: ctx),
        SuperTab.admins => AdminsTab(ctx: ctx),
        SuperTab.maintenance => MaintenanceTab(ctx: ctx),
        SuperTab.onboarding =>
          OnboardingTab(ctx: ctx, active: _tab == SuperTab.onboarding),
        SuperTab.settings =>
          SettingsTab(ctx: ctx, active: _tab == SuperTab.settings),
        SuperTab.support =>
          SupportTicketsTab(ctx: ctx, active: _tab == SuperTab.support),
        SuperTab.tour => SuperadminTourTab(ctx: ctx),
      };

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionSuperadmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final console = _consoleFor(session);
    if (!_tourChecked) {
      _tourChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeShowSuperadminFirstTour(context, session.id);
      });
    }
    final ctx = SuperadminTabContext(session: session, onLogout: _logout);
    return SuperadminScope(
      console: console,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab.index,
              children: [
                for (final tab in SuperTab.values)
                  _visited.contains(tab)
                      ? KeyedSubtree(key: ValueKey(tab), child: _body(tab, ctx))
                      : const SizedBox.shrink(),
              ],
            ),
          ),
          bottomNavigationBar: ScrollableBottomNav<SuperTab>(
            items: [
              for (final tab in SuperTab.values)
                NavItem(id: tab, label: _label(tab), icon: _icon(tab))
            ],
            active: _tab,
            onTap: _go,
          ),
        ),
      ),
    );
  }
}
