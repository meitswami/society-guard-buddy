import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/maintenance_models.dart';
import '../../../models/session_models.dart';
import '../../../services/maintenance_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _service = MaintenanceService();
  List<MaintenanceCharge> _charges = const [];
  List<MaintenancePayment> _payments = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final charges = await _service.fetchCharges(widget.session.societyId);
    final payments = await _service.fetchPaymentsForFlat(widget.session.resident.flatId);
    if (!mounted) return;
    setState(() {
      _charges = charges;
      _payments = payments;
      _loading = false;
    });
  }

  Future<void> _submitPayment() async {
    if (_charges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maintenance charges configured')),
      );
      return;
    }

    String chargeId = _charges.first.id;
    final amountCtrl = TextEditingController(text: _charges.first.amount.toStringAsFixed(0));
    final txnCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var method = 'upi';
    final paidOn = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dueDate = paidOn;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Submit payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: chargeId,
                  decoration: const InputDecoration(labelText: 'Charge'),
                  items: _charges
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.title} (₹${c.amount.toStringAsFixed(0)})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setDialog(() {
                      chargeId = v;
                      final c = _charges.firstWhere((x) => x.id == v);
                      amountCtrl.text = c.amount.toStringAsFixed(0);
                    });
                  },
                ),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  ],
                  onChanged: (v) => setDialog(() => method = v ?? 'upi'),
                ),
                TextField(
                  controller: txnCtrl,
                  decoration: const InputDecoration(labelText: 'Transaction ID (optional)'),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    await _service.submitPayment(
      chargeId: chargeId,
      flatId: widget.session.resident.flatId,
      flatNumber: widget.session.resident.flatNumber,
      residentName: widget.session.resident.name,
      residentId: widget.session.resident.id,
      amount: double.tryParse(amountCtrl.text) ?? 0,
      paymentMethod: method,
      paidOnDate: paidOn,
      dueDate: dueDate,
      transactionId: txnCtrl.text,
      notes: notesCtrl.text,
    );

    amountCtrl.dispose();
    txnCtrl.dispose();
    notesCtrl.dispose();

    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment submitted for admin verification')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brand.primary,
        onPressed: _submitPayment,
        icon: const Icon(Icons.add),
        label: const Text('Submit payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: brand.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Payment history', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No payments submitted yet'),
                    )
                  else
                    ..._payments.map(
                      (p) => Card(
                        child: ListTile(
                          title: Text('₹ ${p.amount.toStringAsFixed(0)}'),
                          subtitle: Text('${p.paymentMethod} · Due ${p.dueDate.substring(0, 10)}'),
                          trailing: Chip(
                            label: Text(p.paymentStatus),
                            backgroundColor: p.paymentStatus == 'verified'
                                ? KutumbikaColors.successBg
                                : brand.primaryLight,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
