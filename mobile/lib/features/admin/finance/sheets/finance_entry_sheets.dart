// Transactions modals → bottom sheets: Payment details (+ letterhead receipt PDF), Ledger entry,
// Edit payment, Edit ledger entry.

import 'package:flutter/material.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import '../export/finance_exports.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../logic/finance_ledger_display.dart';
import '../logic/finance_models.dart';
import '../state/finance_actions.dart';
import '../state/finance_controller.dart';
import '../tabs/finance_record_receipt_tab.dart' show GroupedChargeDropdown;
import '../widgets/fin_kit.dart';

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: builder(ctx)),
        ),
      ),
    );

Widget _header(BuildContext context, String title, String? subtitle, {String? closeLabel}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sectionTitle(context)),
                if ((subtitle ?? '').isNotEmpty) Text(subtitle!, style: AppText.caption(context)),
              ],
            ),
          ),
          FinMiniButton(label: closeLabel ?? context.fin('fin.close'), onTap: () => Navigator.pop(context)),
        ],
      ),
    );

Widget _kv(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: ', style: TextStyle(color: context.tokens.mutedForeground)),
          TextSpan(text: value.isEmpty ? '-' : value),
        ]),
        style: AppText.body(context).copyWith(fontSize: 12),
      ),
    );

Widget _link(BuildContext context, String label, String url) => InkWell(
      onTap: () => ExportKit.openUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: TextStyle(fontSize: 12, color: context.tokens.primary, decoration: TextDecoration.underline)),
      ),
    );

bool _looksLikeImage(String url) => !url.split('?').first.toLowerCase().endsWith('.pdf');

/// Web "Payment details" modal.
Future<void> showPaymentDetailSheet(BuildContext context, FinanceController c, FinancePayment p) {
  final charge = c.derived.chargeById[p.chargeId ?? ''];
  return _sheet(context, (ctx) {
    Future<FinExportFile> buildPdf() => buildMaintenanceReceiptPdf(MaintenanceReceiptPdfInput(
          societyId: c.societyId,
          receiptNumber: p.receiptNumber!,
          flatNumber: p.flatNumber,
          residentName: p.residentName,
          amount: p.amount,
          paymentMethod: p.paymentMethod,
          paymentDate: p.paymentDate,
          dueDate: p.dueDate,
          chargeTitle: charge?.title,
          transactionId: p.transactionId,
          verifiedBy: p.verifiedBy,
          verifiedAt: p.verifiedAt,
          notes: p.notes,
          generatedBy: c.adminName,
        ));

    Future<void> shareReceipt({bool whatsappText = false}) async {
      final file = await buildPdf();
      if (file.warning != null && ctx.mounted) {
        AppFeedback.toast(ctx, ctx.tr(file.warning!, 'सोसाइटी का आधिकारिक लेटरहेड सेट नहीं है।'), tone: BadgeTone.warning);
      }
      await shareFinanceFile(
        file,
        message: whatsappText ? '${c.data.societyName} — Maintenance receipt ${p.receiptNumber} · Flat ${p.flatNumber}' : null,
      );
      if (file.warning == null && ctx.mounted) {
        AppFeedback.toast(ctx, ctx.tr('Receipt ready', 'रसीद तैयार'), tone: BadgeTone.success);
      }
    }

    String dt(String? v) => (v ?? '').isEmpty ? '-' : fmtDateTimeFullLocal(v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(ctx, ctx.tr('Payment details', 'भुगतान विवरण'), (charge?.title ?? '').isEmpty ? ctx.fin('fin.unknownCharge') : charge!.title),
        _kv(ctx, ctx.tr('Flat', 'फ्लैट'), p.flatNumber),
        _kv(ctx, ctx.tr('Resident', 'निवासी'), p.residentName ?? ''),
        _kv(ctx, ctx.tr('Amount', 'राशि'), inrRaw(p.amount)),
        _kv(ctx, ctx.tr('Type', 'प्रकार'), charge?.frequency ?? ''),
        _kv(ctx, ctx.tr('Payment method', 'भुगतान माध्यम'), p.paymentMethod),
        _kv(ctx, ctx.tr('Status', 'स्थिति'), p.paymentStatus),
        _kv(ctx, ctx.tr('Payment month', 'भुगतान माह'), paymentMonthLabel(p, unknownLabel: ctx.tr('Unknown month', 'अज्ञात माह'))),
        _kv(ctx, ctx.fin('fin.billingDate'), (p.dueDate ?? '').isEmpty ? '-' : isoDateToDisplay(p.dueDate)),
        _kv(ctx, ctx.tr('Paid at', 'भुगतान समय'), dt(p.paymentDate)),
        _kv(ctx, ctx.tr('Created at', 'बनाया गया'), dt(p.createdAt)),
        _kv(ctx, ctx.tr('Transaction ID', 'लेन-देन आईडी'), p.transactionId ?? ''),
        _kv(ctx, ctx.tr('Receipt No.', 'रसीद सं.'), p.receiptNumber ?? ''),
        _kv(ctx, ctx.tr('Verified by', 'सत्यापनकर्ता'), p.verifiedBy ?? ''),
        _kv(ctx, ctx.tr('Verified at', 'सत्यापन समय'), dt(p.verifiedAt)),
        _kv(ctx, ctx.tr('Reviewed at', 'समीक्षा समय'), dt(p.reviewedAt)),
        _kv(ctx, ctx.tr('Rejected reason', 'अस्वीकृति कारण'), p.rejectionReason ?? ''),
        _kv(ctx, ctx.tr('Notes', 'टिप्पणी'), p.notes ?? ''),
        if (p.paymentStatus == 'verified' && (p.receiptNumber ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          AppButton(
            icon: Icons.picture_as_pdf_outlined,
            label: ctx.tr('Download letterhead receipt', 'लेटरहेड रसीद डाउनलोड करें'),
            onPressed: () => shareReceipt(),
          ),
          const SizedBox(height: 8),
          FinShareButton(label: ctx.fin('fin.shareWhatsApp'), onShare: () => shareReceipt(whatsappText: true)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FinMiniButton(
              label: ctx.tr('Print', 'प्रिंट करें'),
              icon: Icons.print_outlined,
              onTap: () async {
                final f = await buildPdf();
                await ExportKit.printPdf(f.bytes, name: f.fileName);
              },
            ),
          ),
        ],
        if ((p.screenshotUrl ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _link(ctx, ctx.tr('Open receipt in new tab', 'रसीद खोलें'), p.screenshotUrl!),
          if (_looksLikeImage(p.screenshotUrl!))
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: Image.network(
                p.screenshotUrl!,
                height: 256,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ],
    );
  });
}

/// Web "Ledger entry" modal.
Future<void> showLedgerDetailSheet(BuildContext context, FinanceController c, FinanceLedgerRow e) {
  final actions = FinanceActions(c);
  return _sheet(context, (ctx) {
    final t = ctx.tokens;
    final cp = e.counterparty;
    var distributing = false;
    return StatefulBuilder(builder: (ctx, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(ctx, ctx.tr('Ledger entry', 'खाता प्रविष्टि'), (e.title ?? '').isEmpty ? ctx.tr('Finance entry', 'वित्त प्रविष्टि') : e.title),
          _kv(ctx, ctx.tr('Mode / destination', 'विधि / गंतव्य'), '${e.recordMode ?? ''} · ${e.destination ?? ''}'),
          _kv(ctx, ctx.tr('Month', 'माह'), ledgerMonthDisplay(e)),
          _kv(ctx, ctx.fin('fin.total'), inrRaw(e.totalAmount)),
          _kv(ctx, ctx.tr('Flats in entry', 'प्रविष्टि में फ्लैट'), '${e.aggregateFlatCount}'),
          _kv(ctx, ctx.tr('Allocation style', 'आवंटन शैली'), e.allocationStyle),
          if ((e.distributedAt ?? '').isNotEmpty)
            _kv(ctx, ctx.tr('Distributed at', 'बाँटा गया'), fmtDateTimeFullLocal(e.distributedAt))
          else if (isLedgerInSocietyPool(e))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(ctx.tr('In society pool — not yet split across flats.', 'सोसाइटी पूल में — अभी फ्लैटों में नहीं बाँटा गया।'),
                  style: TextStyle(fontSize: 12, color: t.warning)),
            ),
          if (cp != null) _kv(ctx, ctx.tr('Counterparty', 'प्रतिपक्ष'), cp.name),
          _kv(ctx, ctx.tr('Method', 'माध्यम'), e.paymentMethod),
          _kv(ctx, ctx.tr('Txn', 'लेन-देन'), e.transactionId ?? ''),
          _kv(ctx, ctx.tr('Notes', 'टिप्पणी'), e.notes ?? ''),
          if (e.allocations.isNotEmpty) ...[
            Divider(color: t.border),
            FinMicroLabel(ctx.tr('Flat allocations', 'फ्लैट आवंटन')),
            for (final a in e.allocations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${ctx.tr('Flat', 'फ्लैट')} ${a.flatNumber}', style: AppText.body(ctx).copyWith(fontSize: 12))),
                    Text(inrRaw(a.amount), style: AppText.mono(ctx, size: 12)),
                  ],
                ),
              ),
          ],
          if ((e.screenshotUrl ?? '').isNotEmpty) _link(ctx, ctx.tr('Open attachment', 'संलग्नक खोलें'), e.screenshotUrl!),
          if (isLedgerInSocietyPool(e)) ...[
            const SizedBox(height: 12),
            AppButton(
              icon: Icons.groups_outlined,
              loading: distributing,
              label: ctx.fin('fin.distribute'),
              onPressed: () async {
                setState(() => distributing = true);
                final done = await actions.distribute(ctx, e);
                if (!ctx.mounted) return;
                if (done) {
                  Navigator.pop(ctx);
                } else {
                  setState(() => distributing = false);
                }
              },
            ),
          ],
        ],
      );
    });
  });
}

const _editMethods = ['cash', 'upi', 'razorpay', 'bank_transfer'];
const _ledgerMethods = ['cash', 'upi', 'razorpay', 'bank_transfer', 'cheque', 'other'];

/// Web "Edit payment" modal.
Future<void> showPaymentEditSheet(BuildContext context, FinanceController c, FinancePayment p) {
  return _sheet(context, (_) => _PaymentEditForm(c: c, p: p));
}

class _PaymentEditForm extends StatefulWidget {
  const _PaymentEditForm({required this.c, required this.p});

  final FinanceController c;
  final FinancePayment p;

  @override
  State<_PaymentEditForm> createState() => _PaymentEditFormState();
}

class _PaymentEditFormState extends State<_PaymentEditForm> {
  late String chargeId = widget.p.chargeId ?? '';
  late final amount = TextEditingController(text: numToInput(widget.p.amount));
  late String method = _editMethods.contains(widget.p.paymentMethod) ? widget.p.paymentMethod : 'cash';
  late final txn = TextEditingController(text: widget.p.transactionId ?? '');
  late final notes = TextEditingController(text: widget.p.notes ?? '');
  late String dueDate = paymentBillingDate(widget.p.dueDate);
  late final String recordingDate = () {
    final r = (widget.p.recordingDate ?? '').isNotEmpty ? widget.p.recordingDate! : widget.p.createdAt;
    return r.length > 10 ? r.substring(0, 10) : r;
  }();
  late String status = ['pending', 'verified', 'rejected'].contains(widget.p.paymentStatus) ? widget.p.paymentStatus : 'pending';
  late final reason = TextEditingController(text: widget.p.rejectionReason ?? '');
  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    txn.dispose();
    notes.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final ok = await FinanceActions(widget.c).savePaymentEdit(
      context,
      original: widget.p,
      chargeId: chargeId,
      amount: amount.text,
      paymentMethod: method,
      transactionId: txn.text,
      notes: notes.text,
      dueDate: dueDate,
      recordingDate: recordingDate,
      paymentStatus: status,
      rejectionReason: reason.text,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, context.tr('Edit payment', 'भुगतान संपादित करें'), null, closeLabel: context.fin('fin.cancel')),
        GroupedChargeDropdown(
          c: widget.c,
          value: chargeId,
          placeholder: context.tr('Select receipt type', 'रसीद प्रकार चुनें'),
          onChanged: (v) => setState(() => chargeId = v),
        ),
        gap,
        AppTextField(
          controller: amount,
          hint: context.tr('Amount (₹)', 'राशि (₹)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: kAmountFormatters,
        ),
        gap,
        AppDropdown<String>(
          items: _editMethods,
          value: method,
          labelOf: (m) => m == 'razorpay' ? 'Razorpay' : context.finMethod(m),
          onChanged: (v) => setState(() => method = v ?? 'cash'),
        ),
        gap,
        AppTextField(controller: txn, caps: false, hint: context.tr('Transaction / reference ID', 'लेन-देन / संदर्भ आईडी')),
        gap,
        FinDateField(label: context.fin('fin.billingDate'), value: dueDate, onChanged: (v) => setState(() => dueDate = v)),
        FinHint(context.tr(
          'Recorded on: ${recordingDate.isEmpty ? '—' : isoDateToDisplay(recordingDate)} (not used in period reports)',
          'दर्ज तिथि: ${recordingDate.isEmpty ? '—' : isoDateToDisplay(recordingDate)} (अवधि रिपोर्ट में उपयोग नहीं)',
        )),
        gap,
        AppTextField(controller: notes, caps: false, maxLines: 3, minLines: 2, hint: context.tr('Notes', 'टिप्पणी')),
        gap,
        AppDropdown<String>(
          items: const ['pending', 'verified', 'rejected'],
          value: status,
          labelOf: context.finStatus,
          onChanged: (v) => setState(() => status = v ?? 'pending'),
        ),
        if (status == 'rejected') ...[
          gap,
          AppTextField(controller: reason, caps: false, hint: context.tr('Rejection reason', 'अस्वीकृति कारण')),
        ],
        gap,
        AppButton(label: context.fin('fin.saveChanges'), loading: saving, onPressed: _save),
      ],
    );
  }
}

/// Web "Edit ledger entry" modal.
Future<void> showLedgerEditSheet(BuildContext context, FinanceController c, FinanceLedgerRow e) {
  return _sheet(context, (_) => _LedgerEditForm(c: c, e: e));
}

class _LedgerEditForm extends StatefulWidget {
  const _LedgerEditForm({required this.c, required this.e});

  final FinanceController c;
  final FinanceLedgerRow e;

  @override
  State<_LedgerEditForm> createState() => _LedgerEditFormState();
}

class _LedgerEditFormState extends State<_LedgerEditForm> {
  late final title = TextEditingController(text: widget.e.title ?? '');
  late final total = TextEditingController(text: numToInput(widget.e.totalAmount));
  late String method = _ledgerMethods.contains(widget.e.paymentMethod) ? widget.e.paymentMethod : 'cash';
  late final txn = TextEditingController(text: widget.e.transactionId ?? '');
  late String txDate = ledgerTransactionDate(widget.e);
  late final notes = TextEditingController(text: widget.e.notes ?? '');
  late String status = widget.e.paymentStatus == 'pending' ? 'pending' : 'verified';
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    total.dispose();
    txn.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final ok = await FinanceActions(widget.c).saveLedgerEdit(
      context,
      original: widget.e,
      title: title.text,
      notes: notes.text,
      paymentStatus: status,
      transactionId: txn.text,
      paymentMethod: method,
      totalAmount: total.text,
      transactionDate: txDate,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, context.tr('Edit ledger entry', 'खाता प्रविष्टि संपादित करें'), null, closeLabel: context.fin('fin.cancel')),
        AppTextField(controller: title, hint: context.tr('Title', 'शीर्षक')),
        gap,
        AppTextField(
          controller: total,
          hint: context.tr('Total amount (₹)', 'कुल राशि (₹)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: kAmountFormatters,
        ),
        gap,
        AppDropdown<String>(
          items: _ledgerMethods,
          value: method,
          labelOf: (m) => m == 'razorpay' ? 'Razorpay' : context.finMethod(m),
          onChanged: (v) => setState(() => method = v ?? 'cash'),
        ),
        gap,
        AppTextField(controller: txn, caps: false, hint: context.tr('Transaction / reference ID', 'लेन-देन / संदर्भ आईडी')),
        gap,
        FinDateField(label: context.fin('fin.billingDate'), value: txDate, onChanged: (v) => setState(() => txDate = v)),
        FinHint('${context.tr('Entry month', 'प्रविष्टि माह')}: ${isoMonthToDisplay(billingMonthFromDate(txDate))}'),
        gap,
        AppTextField(controller: notes, caps: false, maxLines: 3, minLines: 2, hint: context.tr('Notes', 'टिप्पणी')),
        gap,
        AppDropdown<String>(
          items: const ['verified', 'pending'],
          value: status,
          labelOf: context.finStatus,
          onChanged: (v) => setState(() => status = v ?? 'verified'),
        ),
        gap,
        AppButton(label: context.fin('fin.saveChanges'), loading: saving, onPressed: _save),
      ],
    );
  }
}
