import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_colors.dart';
import '../../services/notification_service.dart';
import 'models/announcement.dart';
import 'models/quick_action.dart';
import 'widgets/home_header.dart';
import 'widgets/kutumbika_bottom_nav.dart';
import 'widgets/promo_banner.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/recent_announcements.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({
    super.key,
    required this.residentName,
    required this.societyName,
    this.societyId = '',
    this.residentId = '',
    this.flatNumber = '',
  });

  final String residentName;
  final String societyName;
  final String societyId;
  final String residentId;
  final String flatNumber;

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final _notificationService = NotificationService();
  HomeNavTab _navTab = HomeNavTab.home;
  List<Announcement> _announcements = const [];
  int _notificationCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    final announcements = await _notificationService.fetchRecentForResident(
      societyId: widget.societyId,
      residentId: widget.residentId,
      flatNumber: widget.flatNumber,
    );
    final unread = await _notificationService.countUnreadForResident(
      societyId: widget.societyId,
      residentId: widget.residentId,
      flatNumber: widget.flatNumber,
    );
    if (!mounted) return;
    setState(() {
      _announcements = announcements;
      _notificationCount = unread;
      _loading = false;
    });
  }

  List<QuickActionItem> get _quickActions => [
        QuickActionItem(
          kind: QuickActionKind.announcements,
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          badgeCount: _notificationCount > 0 ? _notificationCount : 12,
        ),
        const QuickActionItem(
          kind: QuickActionKind.societyGroups,
          label: 'Society Groups',
          icon: Icons.groups_outlined,
          badgeCount: 8,
        ),
        const QuickActionItem(
          kind: QuickActionKind.visitors,
          label: 'Visitors',
          icon: Icons.badge_outlined,
          badgeCount: 3,
        ),
        const QuickActionItem(
          kind: QuickActionKind.maintenance,
          label: 'Maintenance',
          icon: Icons.account_balance_wallet_outlined,
          statusText: '₹ 12,450 Collected',
          statusColor: KutumbikaColors.success,
        ),
        const QuickActionItem(
          kind: QuickActionKind.complaints,
          label: 'Complaints',
          icon: Icons.description_outlined,
          badgeCount: 2,
        ),
        const QuickActionItem(
          kind: QuickActionKind.events,
          label: 'Events',
          icon: Icons.event_outlined,
          statusText: '2 Upcoming',
          statusColor: KutumbikaColors.success,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFeed,
          color: KutumbikaColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              HomeHeader(
                residentName: widget.residentName,
                societyName: widget.societyName,
                notificationCount: _notificationCount,
              ),
              const SizedBox(height: 24),
              QuickActionGrid(actions: _quickActions),
              const SizedBox(height: 28),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: KutumbikaColors.primary,
                    ),
                  ),
                )
              else
                RecentAnnouncements(items: _announcements),
              const SizedBox(height: 24),
              const PromoBanner(),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: KutumbikaBottomNav(
        selected: _navTab,
        onSelected: (tab) => setState(() => _navTab = tab),
        onCenterTap: () {},
      ),
    );
  }
}
