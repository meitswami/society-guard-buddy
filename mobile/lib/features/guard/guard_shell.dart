import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/gate_actor.dart';
import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../comms/emergency_alert_view.dart';
import '../comms/guard_settings_view.dart';
import '../comms/tour/tour_guide_first_login.dart';
import '../comms/tour/tour_guide_hub_view.dart';
import '../gate/blacklist_view.dart';
import '../gate/data/gate_store.dart';
import '../gate/delivery_entry_view.dart';
import '../gate/gate_i18n.dart';
import '../gate/guard_duty_view.dart';
import '../gate/guard_home_view.dart';
import '../gate/quick_entry_view.dart';
import '../gate/vehicle_view.dart';
import '../gate/visitor_entry_view.dart';
import '../kiosk/kiosk_view.dart';
import '../shared/directory/directory_view.dart';
import 'guard_geofence_monitor.dart';

/// Guard tabs in the web order (`Index.tsx` `guardTabs`, tour last).
enum GuardTab {
  dashboard,
  duty,
  quick,
  visitor,
  kiosk,
  delivery,
  vehicle,
  blacklist,
  emergency,
  directory,
  settings,
  tour
}

/// Whole guard area — web `Index.tsx` guard section: one tab at a time above the horizontally
/// scrollable bottom nav, Android back → Home, then "press back again to exit"; the AI kiosk
/// opens full screen over the nav and blocks back while running; geofence monitoring while on
/// duty; gate data loaded once at login; first-login tour.
class GuardShell extends ConsumerStatefulWidget {
  const GuardShell({super.key});

  @override
  ConsumerState<GuardShell> createState() => _GuardShellState();
}

class _GuardShellState extends ConsumerState<GuardShell>
    with WidgetsBindingObserver {
  GuardTab _tab = GuardTab.dashboard;
  bool _kioskOpen = false;
  DateTime? _lastBackAt;
  GuardGeofenceMonitor? _monitor;
  String? _startedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitor?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = ref.read(sessionProvider).value;
    if (state == AppLifecycleState.resumed && s is SessionGuard) {
      GateStore.of(s.societyId).refreshVisitorsIfStale();
    }
  }

  /// Once per guard session: load gate data, start the geofence watch, maybe show the tour.
  void _startSession(SessionGuard s) {
    final key = s.shiftId;
    if (_startedFor == key) return;
    _startedFor = key;
    GateStore.of(s.societyId).ensureLoaded();
    _monitor?.stop();
    _monitor = GuardGeofenceMonitor(
      societyId: s.societyId,
      guardId: s.guard.guardId,
      guardName: s.guard.name,
      onBreach: (reason) {
        if (!mounted) return;
        AppFeedback.toast(
          context,
          context.t(reason == GeofenceBreach.outsideRadius
              ? 'guard.geofenceLeftZone'
              : 'guard.geofenceLocationOff'),
          tone: BadgeTone.alert,
          duration: const Duration(seconds: 10),
        );
      },
    )..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TourGuideFirstLogin.maybeShow(context,
            role: 'guard', userId: s.guard.guardId);
      }
    });
  }

  void _goHome() {
    if (mounted) setState(() => _tab = GuardTab.dashboard);
  }

  void _onBack() {
    if (_tab != GuardTab.dashboard) {
      setState(() => _tab = GuardTab.dashboard);
      AppFeedback.toast(context, context.gt('gate.pressBackAgain'));
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    AppFeedback.toast(context, context.gt('gate.pressBackAgain'));
  }

  Future<void> _openKiosk(SessionGuard s) async {
    if (_kioskOpen) return;
    setState(() => _kioskOpen = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => _KioskRoute(session: s)),
    );
    if (!mounted) return;
    setState(() {
      _kioskOpen = false;
      _tab = GuardTab.dashboard;
    });
    // Kiosk entries are written by the kiosk module: refresh the gate log.
    GateStore.of(s.societyId).loadVisitors();
  }

  void _select(GuardTab tab, SessionGuard s) {
    if (tab == GuardTab.kiosk) {
      _openKiosk(s);
      return;
    }
    setState(() => _tab = tab);
  }

  Widget _body(SessionGuard s) {
    final actor = GateActor.fromGuard(s);
    return switch (_tab) {
      GuardTab.dashboard || GuardTab.kiosk => GuardHomeView(session: s),
      GuardTab.duty => GuardDutyView(session: s),
      GuardTab.quick => QuickEntryView(actor: actor),
      GuardTab.visitor => VisitorEntryView(actor: actor, onDone: _goHome),
      GuardTab.delivery => DeliveryEntryView(actor: actor, onDone: _goHome),
      GuardTab.vehicle => VehicleView(actor: actor),
      GuardTab.blacklist => BlacklistView(actor: actor),
      GuardTab.emergency => EmergencyAlertView(
          societyId: s.societyId,
          senderName: s.guard.name,
          senderRole: 'guard'),
      GuardTab.directory => DirectoryView(
          societyId: s.societyId,
          viewerRole: 'guard',
          viewerName: s.guard.name),
      GuardTab.settings => GuardSettingsView(session: s),
      GuardTab.tour => TourGuideHubView(role: 'guard', userId: s.guard.guardId),
    };
  }

  List<NavItem<GuardTab>> _items(BuildContext context) => [
        NavItem(
            id: GuardTab.dashboard,
            label: context.t('nav.home'),
            icon: Icons.dashboard_outlined),
        NavItem(
            id: GuardTab.duty,
            label: context.t('nav.duty'),
            icon: Icons.assignment_turned_in_outlined),
        NavItem(
            id: GuardTab.quick,
            label: context.t('nav.quick'),
            icon: Icons.bolt),
        NavItem(
            id: GuardTab.visitor,
            label: context.t('nav.visitor'),
            icon: Icons.person_add_alt_1_outlined),
        NavItem(
            id: GuardTab.kiosk,
            label: context.t('nav.kiosk'),
            icon: Icons.face_retouching_natural),
        NavItem(
            id: GuardTab.delivery,
            label: context.t('nav.delivery'),
            icon: Icons.local_shipping_outlined),
        NavItem(
            id: GuardTab.vehicle,
            label: context.t('nav.vehicles'),
            icon: Icons.directions_car_outlined),
        NavItem(
            id: GuardTab.blacklist,
            label: context.t('nav.blacklist'),
            icon: Icons.gpp_maybe_outlined),
        NavItem(
            id: GuardTab.emergency,
            label: context.t('nav.emergency'),
            icon: Icons.campaign_outlined),
        NavItem(
            id: GuardTab.directory,
            label: context.t('nav.directory'),
            icon: Icons.contacts_outlined),
        NavItem(
            id: GuardTab.settings,
            label: context.t('nav.settings'),
            icon: Icons.settings_outlined),
        NavItem(
            id: GuardTab.tour,
            label: context.t('nav.tour'),
            icon: Icons.auto_awesome_outlined),
      ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session is! SessionGuard) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _startSession(session);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: SafeArea(
            bottom: false,
            child: KeyedSubtree(key: ValueKey(_tab), child: _body(session))),
        bottomNavigationBar: ScrollableBottomNav<GuardTab>(
          items: _items(context),
          active: _kioskOpen ? GuardTab.kiosk : _tab,
          onTap: (tab) => _select(tab, session),
        ),
      ),
    );
  }
}

/// Full-screen AI kiosk above the bottom nav (web `fixed inset-0` overlay). Back is ignored
/// while the kiosk lock (`kioskLockedListenable`) is set; otherwise it returns to Home like the web `onExit`.
class _KioskRoute extends StatelessWidget {
  const _KioskRoute({required this.session});

  final SessionGuard session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: kioskLockedListenable,
      builder: (context, locked, child) =>
          PopScope(canPop: !locked, child: child!),
      child: Scaffold(
        body: KioskView(
          session: session,
          onExit: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
