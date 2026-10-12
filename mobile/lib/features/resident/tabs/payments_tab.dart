import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/maintenance_receipt_pdf.dart';
import '../data/payment_rules.dart';
import '../data/payment_statement_pdf.dart';
import '../data/resident_media.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';
import '../widgets/pay_to_account_card.dart';
import '../widgets/resident_i18n.dart';
import '../widgets/resident_widgets.dart';

/// Payments tab — web `tab === 'payments'`: pay-to-society card, resident payment
/// submission for admin verification (UPI / bank / cash / gateway, UTR, screenshot or PDF
/// proof), history with official letterhead receipts. Mobile adds the current-period dues
/// card and a period statement PDF.
class ResidentPaymentsTab extends StatefulWidget {
  const ResidentPaymentsTab({super.key, required this.session});

  final SessionResident session;

  @override
  State<ResidentPaymentsTab> createState() => _ResidentPaymentsTabState();
}

class _ResidentPaymentsTabState extends State<ResidentPaymentsTab> {
  final _repo = const ResidentRepository();
  final _amount = TextEditingController();
  final _upi = TextEditingController();
  final _txn = TextEditingController();
  final _shotUrl = TextEditingController();
  final _notes = TextEditingController();

  List<MaintenancePaymentRow> _payments = const [];
  List<MaintenanceChargeRow> _charges = const [];
  SocietyBankAccountRow? _bank;
  bool _loading = true;
  bool _failed = false;
  bool _showForm = false;
  String _chargeId = '';
  String _method = 'bank_transfer';
  String _paidOn = Fmt.todayIso();
  String _dueDate = Fmt.todayIso();
  PickedMedia? _file;
  bool _uploading = false;
  bool _saving = false;
  String? _busyReceiptId;

  SessionResident get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    for (final c in [_amount, _upi, _txn, _shotUrl, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        _repo.fetchPayments(_s.resident.flatId),
        _repo.fetchCharges(_s.societyId),
        _repo.fetchPrimaryBankAccount(_s.societyId).catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _payments = results[0] as List<MaintenancePaymentRow>;
        _charges = results[1] as List<MaintenanceChargeRow>;
        _bank = results[2] as SocietyBankAccountRow?;
        if (_upi.text.isEmpty && (_bank?.upiVpa ?? '').isNotEmpty) _upi.text = _bank!.upiVpa!;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _payments.isEmpty;
      });
    }
  }

  String? _chargeTitle(String? id) {
    for (final c in _charges) {
      if (c.id == id) return c.title;
    }
    return null;
  }

  /// Web effect: when the form opens without a charge, pre-select this month's maintenance.
  void _toggleForm() {
    setState(() {
      _showForm = !_showForm;
      if (_showForm && _chargeId.isEmpty) {
        final preferred = pickPreferredCharge(_charges, DateTime.now());
        if (preferred != null) {
          _chargeId = preferred.id;
          _amount.text = jsNumberString(preferred.amount);
          _dueDate = dueDateForDay(preferred.dueDay, DateTime.now());
        }
      }
    });
  }

  void _payDue(ChargeDue due) {
    setState(() {
      _showForm = true;
      _chargeId = due.charge.id;
      _amount.text = jsNumberString(due.charge.amount);
      _dueDate = due.dueDate;
    });
  }

  void _resetForm() {
    _chargeId = '';
    _amount.clear();
    _method = 'bank_transfer';
    _txn.clear();
    _notes.clear();
    _paidOn = Fmt.todayIso();
    _dueDate = Fmt.todayIso();
    _shotUrl.clear();
    _upi.text = _bank?.upiVpa ?? '';
    _file = null;
  }

  void _openUpiFromForm() {
    final payee = _upi.text.trim().isNotEmpty ? _upi.text.trim() : (_bank?.upiVpa ?? '').trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (payee.isEmpty) {
      AppFeedback.toast(
        context,
        _bank != null
            ? context.tr('No UPI ID on file. Use bank transfer with the society account number & IFSC shown above.',
                'यूपीआई आईडी उपलब्ध नहीं। ऊपर दिखाए सोसाइटी खाता संख्या व IFSC से बैंक ट्रांसफ़र करें।')
            : context.tr('Society payment account is not configured yet', 'सोसाइटी भुगतान खाता अभी सेट नहीं है'),
        tone: BadgeTone.alert,
      );
      return;
    }
    if (amount <= 0) {
      AppFeedback.toast(context, context.tr('Enter amount first', 'पहले राशि दर्ज करें'), tone: BadgeTone.alert);
      return;
    }
    launchUpi(
      context,
      buildUpiPayUrl(
        upiVpa: payee,
        payeeName: (_bank?.accountHolderName ?? '').isEmpty ? 'Society Maintenance' : _bank!.accountHolderName,
        amount: amount,
        note: maintenanceUpiNote(_s.resident.flatNumber),
      ),
    );
  }

  Future<void> _submit() async {
    final err = validateResidentPayment(
      chargeId: _chargeId,
      amountText: _amount.text,
      paidOn: _paidOn,
      dueDate: _dueDate,
      fileBytes: _file?.bytes.length,
    );
    if (err != null) {
      AppFeedback.toast(
        context,
        switch (err) {
          ResidentPaymentError.chargeRequired => context.tr('Select maintenance charge', 'रखरखाव शुल्क चुनें'),
          ResidentPaymentError.amountInvalid => context.tr('Enter valid amount', 'मान्य राशि दर्ज करें'),
          ResidentPaymentError.datesRequired => context.tr('Select paid date and due date', 'भुगतान तिथि व देय तिथि चुनें'),
          ResidentPaymentError.fileTooLarge => context.tr('Receipt file must be 8MB or smaller', 'रसीद फ़ाइल 8MB या छोटी होनी चाहिए'),
        },
        tone: BadgeTone.alert,
      );
      return;
    }
    var screenshot = _shotUrl.text.trim();
    final file = _file;
    if (file != null) {
      setState(() => _uploading = true);
      final url = await _repo.uploadMaintenanceReceipt(file.bytes, file.name, contentType: file.mimeType);
      if (!mounted) return;
      setState(() => _uploading = false);
      if (url == null) {
        AppFeedback.toast(context, context.tr('Could not upload receipt', 'रसीद अपलोड नहीं हो सकी'), tone: BadgeTone.alert);
        return;
      }
      screenshot = url;
    }
    setState(() => _saving = true);
    try {
      await _repo.submitPayment(
        chargeId: _chargeId,
        flatId: _s.resident.flatId,
        flatNumber: _s.resident.flatNumber,
        residentName: _s.resident.name,
        residentId: _s.resident.id,
        amount: double.parse(_amount.text.trim()),
        paymentMethod: _method,
        paidOn: _paidOn,
        dueDate: _dueDate,
        transactionId: _txn.text,
        screenshotUrl: screenshot,
        notes: _notes.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _showForm = false;
        _resetForm();
      });
      AppFeedback.toast(context, context.tr('Payment submitted for admin verification', 'भुगतान व्यवस्थापक सत्यापन के लिए जमा किया गया'),
          tone: BadgeTone.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _receipt(MaintenancePaymentRow p) async {
    setState(() => _busyReceiptId = p.id);
    try {
      final pdf = await buildMaintenanceReceiptPdf(MaintenanceReceiptInput.fromPayment(
        p,
        societyId: _s.societyId,
        fallbackFlat: _s.resident.flatNumber,
        fallbackName: _s.resident.name,
        chargeTitle: _chargeTitle(p.chargeId),
        generatedBy: _s.resident.name,
      ));
      if (!mounted) return;
      setState(() => _busyReceiptId = null);
      await showPdfActions(
        context,
        bytes: pdf.bytes,
        filename: pdf.filename,
        warning: pdf.warning,
        message: '${context.tr('Maintenance receipt', 'रखरखाव रसीद')} ${p.receiptNumber} · ${context.t('common.flat')} ${p.flatNumber}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyReceiptId = null);
      AppFeedback.toast(context, context.tr('Could not create the receipt PDF', 'रसीद PDF नहीं बन सकी'), tone: BadgeTone.alert);
    }
  }

  Future<void> _statement() async {
    final labels = {
      StatementPeriod.all: context.tr('All payments', 'सभी भुगतान'),
      StatementPeriod.thisMonth: context.tr('This month', 'इस माह'),
      StatementPeriod.last3Months: context.tr('Last 3 months', 'पिछले 3 माह'),
      StatementPeriod.thisFinancialYear: context.tr('This financial year', 'यह वित्त वर्ष'),
      StatementPeriod.lastFinancialYear: context.tr('Last financial year', 'पिछला वित्त वर्ष'),
    };
    final period = await showModalBottomSheet<StatementPeriod>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(ctx.rt('resident.m.statementTitle'), style: AppText.sectionTitle(ctx)),
          ),
          for (final e in labels.entries)
            ListTile(leading: const Icon(Icons.date_range_outlined), title: Text(e.value), onTap: () => Navigator.pop(ctx, e.key)),
        ]),
      ),
    );
    if (period == null || !mounted) return;
    final range = statementRange(period, DateTime.now());
    final periodLabel = range == null ? labels[period]! : '${Fmt.isoToDisplay(range.from)} – ${Fmt.isoToDisplay(range.to)}';
    try {
      final pdf = await buildPaymentStatementPdf(
        societyId: _s.societyId,
        flatNumber: _s.resident.flatNumber,
        residentName: _s.resident.name,
        periodLabel: periodLabel,
        payments: paymentsInRange(_payments, range),
        chargeTitles: {for (final c in _charges) c.id: c.title},
        generatedBy: _s.resident.name,
      );
      if (!mounted) return;
      await showPdfActions(
        context,
        bytes: pdf.bytes,
        filename: pdf.filename,
        warning: pdf.warning,
        message: '${context.rt('resident.m.statementTitle')} · ${context.t('common.flat')} ${_s.resident.flatNumber} · $periodLabel',
      );
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.tr('Could not create the statement', 'विवरण पत्र नहीं बन सका'), tone: BadgeTone.alert);
    }
  }

  BadgeTone _statusTone(String s) => switch (s) {
        'verified' => BadgeTone.success,
        'rejected' => BadgeTone.alert,
        _ => BadgeTone.warning,
      };

  Widget _dues() {
    final dues = computeChargeDues(_charges, _payments, DateTime.now());
    if (dues.isEmpty) return const SizedBox.shrink();
    final outstanding = totalOutstanding(dues);
    final t = context.tokens;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          context.rt('resident.m.dues'),
          icon: Icons.receipt_long_outlined,
          trailing: Text(
            outstanding > 0 ? '${context.tr('Due', 'देय')}: ${receiptMoney(outstanding)}' : context.tr('All clear', 'कोई बकाया नहीं'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: outstanding > 0 ? t.destructive : t.success),
          ),
        ),
        for (final d in dues)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.charge.title, style: AppText.bodyMedium(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${receiptMoney(d.charge.amount)} · ${d.periodLabel}', style: AppText.tiny(context)),
                ]),
              ),
              switch (d.state) {
                DueState.paid => ToneBadge(context.tr('Paid', 'भुगतान हुआ'), tone: BadgeTone.success),
                DueState.pending => ToneBadge(context.tr('Verifying', 'सत्यापन में'), tone: BadgeTone.warning),
                DueState.rejected || DueState.due => AppButton(
                    label: d.state == DueState.rejected ? context.tr('Pay again', 'फिर से भुगतान') : context.tr('Pay', 'भुगतान करें'),
                    dense: true,
                    expand: false,
                    onPressed: () => _payDue(d),
                  ),
              },
            ]),
          ),
      ]),
    );
  }

  Widget _form() {
    final hasUpiOnFile = (_bank?.upiVpa ?? '').isNotEmpty;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListLabel(context.tr('Submit payment for verification', 'सत्यापन के लिए भुगतान जमा करें')),
        AppDropdown<String>(
          items: [for (final c in _charges) c.id],
          value: _chargeId.isEmpty ? null : _chargeId,
          hint: context.tr('Select charge', 'शुल्क चुनें'),
          labelOf: (id) {
            final c = _charges.firstWhere((x) => x.id == id);
            return '${c.title} - ₹${jsNumberString(c.amount)}';
          },
          onChanged: (id) {
            if (id == null) return;
            final c = _charges.firstWhere((x) => x.id == id);
            setState(() {
              _chargeId = id;
              _amount.text = jsNumberString(c.amount);
            });
          },
        ),
        const SizedBox(height: 8),
        AppTextField(controller: _amount, hint: context.tr('Amount (₹)', 'राशि (₹)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 8),
        AppDropdown<String>(
          items: const ['bank_transfer', 'upi', 'cash', 'razorpay'],
          value: _method,
          labelOf: (m) => switch (m) {
            'bank_transfer' => context.tr('Bank transfer (NEFT / IMPS)', 'बैंक ट्रांसफ़र (NEFT / IMPS)'),
            'upi' => 'UPI',
            'cash' => context.tr('Cash', 'नकद'),
            _ => context.tr('Online gateway', 'ऑनलाइन गेटवे'),
          },
          onChanged: (m) => setState(() => _method = m ?? 'bank_transfer'),
        ),
        if (_method == 'upi') ...[
          if (!hasUpiOnFile) ...[
            const SizedBox(height: 8),
            AppTextField(controller: _upi, hint: context.tr('Society UPI ID (if shared separately)', 'सोसाइटी यूपीआई आईडी (यदि अलग से दी गई हो)'), caps: false),
          ],
          const SizedBox(height: 8),
          AppButton.secondary(label: context.tr('Open UPI app with amount', 'राशि के साथ यूपीआई ऐप खोलें'), icon: Icons.smartphone, onPressed: _openUpiFromForm),
          const SizedBox(height: 4),
          Text(
            context.tr('After paying to the society account, enter the UTR / UPI reference and upload screenshot below.',
                'सोसाइटी खाते में भुगतान के बाद नीचे UTR / यूपीआई संदर्भ दर्ज करें और स्क्रीनशॉट अपलोड करें।'),
            style: AppText.tiny(context),
          ),
        ],
        if (_method == 'bank_transfer' && _bank != null) ...[
          const SizedBox(height: 4),
          Text(
            context.tr('Send NEFT/IMPS to the account above. Paste the bank UTR in the transaction field below.',
                'ऊपर दिए खाते में NEFT/IMPS भेजें। बैंक UTR नीचे लेन-देन फ़ील्ड में डालें।'),
            style: AppText.tiny(context),
          ),
        ],
        const SizedBox(height: 8),
        AppTextField(controller: _txn, hint: context.tr('Transaction / UPI / UTR reference ID', 'लेन-देन / यूपीआई / UTR संदर्भ आईडी'), mono: true),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ResidentDateField(label: context.tr('Paid on', 'भुगतान तिथि'), value: _paidOn, onChanged: (v) => setState(() => _paidOn = v))),
          const SizedBox(width: 8),
          Expanded(child: ResidentDateField(label: context.tr('Due date', 'देय तिथि'), value: _dueDate, onChanged: (v) => setState(() => _dueDate = v))),
        ]),
        const SizedBox(height: 8),
        AppTextField(controller: _shotUrl, hint: context.tr('Screenshot URL (optional)', 'स्क्रीनशॉट URL (वैकल्पिक)'), keyboardType: TextInputType.url),
        const SizedBox(height: 8),
        Text(context.tr('Or upload payment screenshot', 'या भुगतान का स्क्रीनशॉट अपलोड करें').toUpperCase(),
            style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlineChipButton(
            icon: Icons.attach_file,
            label: _file == null ? context.tr('Choose file', 'फ़ाइल चुनें') : context.tr('Change file', 'फ़ाइल बदलें'),
            done: _file != null,
            onTap: () async {
              final f = await ResidentMedia.pickReceipt(context);
              if (f != null && mounted) setState(() => _file = f);
            },
          ),
          if (_file != null) ...[
            Text('${_file!.name} (${(_file!.bytes.length / 1024).round()} KB)', style: AppText.tiny(context)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _file = null),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        AppTextField(controller: _notes, hint: context.tr('Notes', 'टिप्पणी'), maxLines: 3, minLines: 2),
        const SizedBox(height: 12),
        AppButton(
          label: _uploading
              ? context.tr('Uploading receipt…', 'रसीद अपलोड हो रही है…')
              : _saving
                  ? context.tr('Submitting…', 'जमा हो रहा है…')
                  : context.tr('Submit for admin verification', 'व्यवस्थापक सत्यापन के लिए जमा करें'),
          loading: _uploading || _saving,
          onPressed: _submit,
        ),
      ]),
    );
  }

  Widget _payment(MaintenancePaymentRow p) {
    final t = context.tokens;
    final lines = <String>[
      '${p.paymentMethod} · ${Fmt.date(p.createdAt)}',
    ];
    return CardSection(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(receiptMoney(p.amount), style: AppText.bodyMedium(context)),
            if ((p.receiptNumber ?? '').isNotEmpty)
              Text('${context.tr('Receipt', 'रसीद')} ${p.receiptNumber}', style: AppText.mono(context, size: 10, color: t.mutedForeground)),
            if (_chargeTitle(p.chargeId) != null) Text(_chargeTitle(p.chargeId)!, style: AppText.caption(context)),
            for (final l in lines) Text(l, style: AppText.caption(context)),
            Text('${context.tr('Paid on', 'भुगतान तिथि')}: ${(p.paymentDate ?? '').isEmpty ? '-' : Fmt.date(p.paymentDate)}', style: AppText.tiny(context)),
            Text('${context.tr('Due date', 'देय तिथि')}: ${p.dueDate.isEmpty ? '-' : Fmt.isoToDisplay(p.dueDate)}', style: AppText.tiny(context)),
            if ((p.transactionId ?? '').isNotEmpty) Text('${context.tr('Ref', 'संदर्भ')}: ${p.transactionId}', style: AppText.tiny(context)),
            if ((p.notes ?? '').isNotEmpty) Text(p.notes!, style: AppText.tiny(context)),
            if ((p.rejectionReason ?? '').isNotEmpty)
              Text('${context.tr('Reason', 'कारण')}: ${p.rejectionReason}', style: TextStyle(fontSize: 10, color: t.destructive)),
            if ((p.screenshotUrl ?? '').isNotEmpty)
              _Link(label: context.tr('View receipt', 'रसीद देखें'), onTap: () => ExportKit.openUrl(p.screenshotUrl!)),
            if (p.isVerified && (p.receiptNumber ?? '').isNotEmpty && _s.societyId.isNotEmpty)
              _busyReceiptId == p.id
                  ? const Padding(padding: EdgeInsets.only(top: 6), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                  : _Link(
                      label: context.tr('Download official receipt (letterhead)', 'आधिकारिक रसीद डाउनलोड करें (लेटरहेड)'),
                      onTap: () => _receipt(p),
                    ),
          ]),
        ),
        ToneBadge(p.paymentStatus, tone: _statusTone(p.paymentStatus)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final amount = double.tryParse(_amount.text.trim());
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          title: context.t('resident.payments'),
          subtitle: context.tr('Maintenance dues, payments and receipts', 'रखरखाव देय, भुगतान और रसीदें'),
          icon: Icons.currency_rupee,
        ),
        if (_loading) const LoadingView(),
        if (_failed) ErrorView(onRetry: _load),
        if (!_loading) ...[
          if (_bank != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SocietyPayToAccountCard(
                account: _bank!,
                amount: amount != null && amount > 0 ? amount : null,
                note: maintenanceUpiNote(_s.resident.flatNumber),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.warning, 0.1),
                  border: Border.all(color: AppTokens.tint(t.warning, 0.2)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Text(
                  context.tr('Society bank account is not published yet. Ask the treasurer / admin to add it under Settings.',
                      'सोसाइटी बैंक खाता अभी प्रकाशित नहीं है। कोषाध्यक्ष / व्यवस्थापक से सेटिंग्स में जोड़ने को कहें।'),
                  style: TextStyle(fontSize: 12, color: t.warning),
                ),
              ),
            ),
          _dues(),
          AppButton(
            label: _showForm ? context.tr('Close payment form', 'भुगतान फ़ॉर्म बंद करें') : context.tr('Add maintenance payment', 'रखरखाव भुगतान जोड़ें'),
            onPressed: _toggleForm,
          ),
          const SizedBox(height: 12),
          if (_showForm) _form(),
          ListLabel(
            context.tr('My Payment History', 'मेरा भुगतान इतिहास'),
            trailing: _payments.isEmpty
                ? null
                : TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _statement,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: Text(context.rt('resident.m.statement'), style: const TextStyle(fontSize: 12)),
                  ),
          ),
          if (_payments.isEmpty) EmptyView(message: context.tr('No payment records', 'कोई भुगतान रिकॉर्ड नहीं')),
          for (final p in _payments) _payment(p),
        ],
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(label, style: TextStyle(fontSize: 11, color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary)),
      ),
    );
  }
}
