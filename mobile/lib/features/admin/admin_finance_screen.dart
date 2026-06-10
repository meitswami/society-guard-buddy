import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/admin_finance_service.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final _service = AdminFinanceService();
  List<AdminMaintenancePayment> _payments = const [];
  bool _loading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _payments = await _service.fetchPayments(widget.session.societyId);
    if (mounted) setState(() => _loading = false);
  }

  List<AdminMaintenancePayment> get _filtered {
    if (_filter == 'all') return _payments;
    return _payments.where((p) => p.paymentStatus == _filter).toList();
  }

  Future<void> _verify(AdminMaintenancePayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify payment?'),
        content: Text('Confirm ₹${p.amount.toStringAsFixed(0)} from Flat ${p.flatNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify')),
        ],
      ),
    );
    if (ok != true) return;

    await _service.verifyPayment(
      paymentId: p.id,
      adminName: widget.session.admin.name,
      societyId: widget.session.societyId,
      flatNumber: p.flatNumber,
      amount: p.amount,
      chargeTitle: p.chargeTitle,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified')));
      await _load();
    }
  }

  Future<void> _reject(AdminMaintenancePayment p) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject payment?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason *'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );

    if (ok != true) {
      reasonCtrl.dispose();
      return;
    }

    try {
      await _service.rejectPayment(
        paymentId: p.id,
        adminName: widget.session.admin.name,
        societyId: widget.session.societyId,
        flatNumber: p.flatNumber,
        reason: reasonCtrl.text,
        chargeTitle: p.chargeTitle,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment rejected')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      reasonCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final pending = _payments.where((p) => p.paymentStatus == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  label: Text('$pending pending'),
                  backgroundColor: brand.primaryLight,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'verified', label: Text('Verified')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Review resident maintenance payments. Full ledger, receipts, and splits remain on web.',
              style: TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    color: brand.primary,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No payments', style: TextStyle(color: KutumbikaColors.textMuted))),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final p = _filtered[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Flat ${p.flatNumber}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Text(
                                            '₹${p.amount.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: brand.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        p.chargeTitle ?? 'Maintenance',
                                        style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
                                      ),
                                      if (p.residentName != null)
                                        Text(p.residentName!, style: const TextStyle(fontSize: 12)),
                                      Text(
                                        '${p.paymentMethod} · ${p.paymentStatus}',
                                        style: const TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                                      ),
                                      if (p.transactionId != null && p.transactionId!.isNotEmpty)
                                        Text('Txn: ${p.transactionId}', style: const TextStyle(fontSize: 11)),
                                      if (p.paymentStatus == 'pending') ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () => _verify(p),
                                                child: const Text('Verify'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _reject(p),
                                                child: const Text('Reject'),
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
                  ),
          ),
        ],
      ),
    );
  }
}
