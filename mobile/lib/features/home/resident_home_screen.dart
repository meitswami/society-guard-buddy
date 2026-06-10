import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/approval_service.dart';
import '../../services/notification_service.dart';
import '../../services/visitor_pass_service.dart';
import '../shared/widgets/branded_background.dart';
import 'models/announcement.dart';
import 'models/quick_action.dart';
import 'widgets/home_header.dart';
import 'widgets/promo_banner.dart';
import 'widgets/quick_action_grid.dart';
import '../resident/screens/resident_emergency_screen.dart';
import 'widgets/recent_announcements.dart';

enum ResidentHomeTab {
  approvals,
  passes,
  notifications,
  directory,
  more,
  maintenance,
  complaints,
  events,
  announcements,
  societyGroups,
  visitors,
}

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({
    super.key,
    required this.session,
    this.onNavigate,
  });

  final SessionResident session;
  final void Function(ResidentHomeTab tab)? onNavigate;

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final _notificationService = NotificationService();
  final _approvalService = ApprovalService();
  final _passService = VisitorPassService();

  List<Announcement> _announcements = const [];
  int _notificationCount = 0;
  int _pendingApprovals = 0;
  int _passCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    final r = widget.session.resident;
    final announcements = await _notificationService.fetchRecentForResident(
      societyId: widget.session.societyId,
      residentId: r.id,
      flatNumber: r.flatNumber,
    );
    final unread = await _notificationService.countUnreadForResident(
      societyId: widget.session.societyId,
      residentId: r.id,
      flatNumber: r.flatNumber,
    );
    final pending = await _approvalService.countPending(r.flatId);
    final passes = await _passService.fetchForFlat(r.flatId);
    if (!mounted) return;
    setState(() {
      _announcements = announcements;
      _notificationCount = unread;
      _pendingApprovals = pending;
      _passCount = passes.length;
      _loading = false;
    });
  }

  void _tap(ResidentHomeTab tab) => widget.onNavigate?.call(tab);

  List<QuickActionItem> get _quickActions => [
        QuickActionItem(
          kind: QuickActionKind.announcements,
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          badgeCount: _notificationCount > 0 ? _notificationCount : null,
        ),
        QuickActionItem(
          kind: QuickActionKind.visitors,
          label: 'Visitors',
          icon: Icons.badge_outlined,
          badgeCount: _pendingApprovals > 0 ? _pendingApprovals : null,
        ),
        QuickActionItem(
          kind: QuickActionKind.societyGroups,
          label: 'Visitor passes',
          icon: Icons.key_outlined,
          badgeCount: _passCount > 0 ? _passCount : null,
        ),
        QuickActionItem(
          kind: QuickActionKind.maintenance,
          label: 'Maintenance',
          icon: Icons.account_balance_wallet_outlined,
          statusText: 'Payments',
          statusColor: KutumbikaColors.success,
        ),
        const QuickActionItem(
          kind: QuickActionKind.complaints,
          label: 'Complaints',
          icon: Icons.description_outlined,
        ),
        const QuickActionItem(
          kind: QuickActionKind.events,
          label: 'Directory',
          icon: Icons.apartment_outlined,
        ),
        const QuickActionItem(
          kind: QuickActionKind.emergency,
          label: 'Emergency',
          icon: Icons.warning_amber_rounded,
          statusColor: Color(0xFFD32F2F),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final r = widget.session.resident;

    return Scaffold(
      body: BrandedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadFeed,
            color: brand.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                HomeHeader(
                  residentName: r.name,
                  societyName: widget.session.societyName,
                  notificationCount: _notificationCount,
                  onNotificationsTap: () => _tap(ResidentHomeTab.notifications),
                ),
                const SizedBox(height: 24),
                QuickActionGrid(
                  actions: _quickActions,
                  onActionTap: (kind) {
                    switch (kind) {
                      case QuickActionKind.announcements:
                        _tap(ResidentHomeTab.notifications);
                      case QuickActionKind.visitors:
                        _tap(ResidentHomeTab.approvals);
                      case QuickActionKind.societyGroups:
                        _tap(ResidentHomeTab.passes);
                      case QuickActionKind.complaints:
                        _tap(ResidentHomeTab.more);
                      case QuickActionKind.events:
                        _tap(ResidentHomeTab.directory);
                      case QuickActionKind.maintenance:
                        _tap(ResidentHomeTab.maintenance);
                      case QuickActionKind.emergency:
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ResidentEmergencyScreen(session: widget.session),
                          ),
                        );
                      default:
                        break;
                    }
                  },
                ),
                const SizedBox(height: 28),
                if (_loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: brand.primary),
                    ),
                  )
                else
                  RecentAnnouncements(
                    items: _announcements,
                    onViewAll: () => _tap(ResidentHomeTab.notifications),
                  ),
                const SizedBox(height: 24),
                const PromoBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
