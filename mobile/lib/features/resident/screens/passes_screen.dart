import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';
import '../../../models/visitor_pass.dart';
import '../../../services/visitor_pass_service.dart';

class PassesScreen extends StatefulWidget {
  const PassesScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  final _service = VisitorPassService();
  List<VisitorPass> _items = const [];
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

  Future<void> _createPass() async {
    final guestName = TextEditingController();
    final guestPhone = TextEditingController();
    final validDate = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New visitor pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: guestName,
              decoration: const InputDecoration(labelText: 'Guest name'),
            ),
            TextField(
              controller: guestPhone,
              decoration: const InputDecoration(labelText: 'Guest phone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: validDate,
              decoration: const InputDecoration(labelText: 'Valid date (YYYY-MM-DD)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (ok != true) return;

    final otp = await _service.createPass(
      flatId: widget.session.resident.flatId,
      flatNumber: widget.session.resident.flatNumber,
      residentId: widget.session.resident.id,
      residentName: widget.session.resident.name,
      guestName: guestName.text.trim(),
      guestPhone: guestPhone.text.trim(),
      validDate: validDate.text.trim(),
    );

    guestName.dispose();
    guestPhone.dispose();
    validDate.dispose();

    await _load();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pass created'),
        content: Text('Share OTP with your guest: $otp'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: brand.primary,
        onPressed: _createPass,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No visitor passes yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: KutumbikaColors.textSecondary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: brand.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = _items[index];
                      return Card(
                        child: ListTile(
                          title: Text(p.guestName ?? 'Guest'),
                          subtitle: Text(
                            'OTP ${p.otpCode} · Valid ${p.validDate}',
                          ),
                          trailing: Text(p.status),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
