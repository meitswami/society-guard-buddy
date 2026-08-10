import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/maintenance_models.dart';
import '../../../models/session_models.dart';
import '../../../models/society_bank_account.dart';
import '../../../services/maintenance_service.dart';
import '../../../services/society_bank_account_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _service = MaintenanceService();
  final _bankService = SocietyBankAccountService();
  List<MaintenanceCharge> _charges = const [];
  List<MaintenancePayment> _payments = const [];
  SocietyBankAccount? _bank;
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
    final bank = await _bankService.fetchPrimary(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _charges = charges;
      _payments = payments;
      _bank = bank;
      _loading = false;
    });
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _openUpi(double amount) async {
    final vpa = _bank?.upiVpa?.trim();
    if (vpa == null || vpa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI ID configured. Use bank transfer with account & IFSC.')),
      );
      return;
    }
    final note = 'Maintenance for Flat ${widget.session.resident.flatNumber}';
    final uri = Uri.parse(
      'upi://pay?pa=${Uri.encodeComponent(vpa)}'
      '&pn=${Uri.encodeComponent(_bank!.accountHolderName)}'
      '&am=${Uri.encodeComponent(amount.toStringAsFixed(0))}'
      '&cu=INR'
      '&tn=${Uri.encodeComponent(note)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open UPI app')));
    }
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
    var method = 'bank_transfer';
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_bank != null) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pay to society account', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          Text(_bank!.accountHolderName),
                          Text('${_bank!.bankName} · ${_bank!.ifsc}'),
                          Text(_bank!.accountNumber, style: const TextStyle(fontFamily: 'monospace')),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _copy('Bank details', _bank!.copyableDetails),
                                child: const Text('Copy details'),
                              ),
                              if (_bank!.upiVpa != null && _bank!.upiVpa!.trim().isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    final amt = double.tryParse(amountCtrl.text) ?? 0;
                                    if (amt <= 0) return;
                                    _openUpi(amt);
                                  },
                                  child: const Text('Open UPI'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer (NEFT / IMPS)')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  ],
                  onChanged: (v) => setDialog(() => method = v ?? 'bank_transfer'),
                ),
                TextField(
                  controller: txnCtrl,
                  decoration: const InputDecoration(labelText: 'UTR / UPI reference'),
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
                  if (_bank != null) ...[
                    Card(
                      color: KutumbikaColors.surfaceMuted,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Society bank account', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(_bank!.accountHolderName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(_bank!.bankName),
                            const SizedBox(height: 4),
                            SelectableText(_bank!.accountNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
                            Text('IFSC ${_bank!.ifsc}', style: const TextStyle(fontFamily: 'monospace')),
                            if (_bank!.branchName != null) Text('Branch: ${_bank!.branchName}'),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _copy('Bank details', _bank!.copyableDetails),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy for payment'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                          trailing: Text(p.paymentStatus),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
