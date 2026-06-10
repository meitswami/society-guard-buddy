import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/approval_request.dart';
import '../../../models/session_models.dart';
import '../../../services/approval_service.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final _service = ApprovalService();
  List<ApprovalRequest> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.fetchForFlat(widget.session.resident.flatId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _respond(ApprovalRequest item, String status) async {
    final label = status == 'approved' ? 'Approve' : 'Reject';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label visitor?'),
        content: Text('${item.visitorName} at gate'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(label)),
        ],
      ),
    );
    if (ok != true) return;

    await _service.respond(
      id: item.id,
      flatId: widget.session.resident.flatId,
      status: status,
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status == 'approved' ? 'Approved' : 'Rejected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No visitor approval requests',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: KutumbikaColors.textSecondary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: brand.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          final pending = item.status == 'pending';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.visitorName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(item.status),
                        backgroundColor: pending
                            ? brand.primaryLight
                            : KutumbikaColors.successBg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Flat ${item.flatNumber} · Guard ${item.guardName}'),
                  if (item.purpose != null) Text(item.purpose!),
                  Text(
                    DateFormat('d MMM, h:mm a').format(item.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KutumbikaColors.textMuted,
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respond(item, 'rejected'),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: brand.primary,
                            ),
                            onPressed: () => _respond(item, 'approved'),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
