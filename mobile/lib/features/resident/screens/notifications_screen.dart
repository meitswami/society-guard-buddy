import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../features/home/models/announcement.dart';
import '../../../features/home/widgets/recent_announcements.dart';
import '../../../models/session_models.dart';
import '../../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  List<Announcement> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.fetchRecentForResident(
      societyId: widget.session.societyId,
      residentId: widget.session.resident.id,
      flatNumber: widget.session.resident.flatNumber,
      limit: 50,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: brand.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RecentAnnouncements(items: _items),
        ],
      ),
    );
  }
}
