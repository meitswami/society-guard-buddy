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
  bool _clearing = false;

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

  Future<void> _clearTillToday() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear alerts till today?'),
        content: const Text(
          'Notifications on or before today will be removed from your inbox. Other residents are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    final cleared = await _service.clearTillDateForResident(
      societyId: widget.session.societyId,
      residentId: widget.session.resident.id,
      flatNumber: widget.session.resident.flatNumber,
      tillDateInclusive: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _clearing = false);

    if (cleared == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No alerts to clear')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared $cleared alert${cleared == 1 ? '' : 's'}')),
    );
    await _load();
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
          if (_items.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearing ? null : _clearTillToday,
                icon: _clearing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: Text(_clearing ? 'Clearing…' : 'Clear till today'),
              ),
            ),
          RecentAnnouncements(items: _items),
        ],
      ),
    );
  }
}
