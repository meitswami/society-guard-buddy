// Finance → Record → Record receipt (web `subTab === 'payments'` panel + `recordPayment`).

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ui/ui.dart';
import '../data/finance_repository.dart';
import '../logic/finance_charge_helpers.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_expense_head.dart';
import '../logic/finance_format.dart';
import '../logic/finance_models.dart';
import '../logic/finance_receipt_conflicts.dart';
import '../logic/flat_sort.dart';
import '../logic/record_receipt_plan.dart';
import '../state/finance_controller.dart';
import '../state/finance_forms.dart';
import '../widgets/fin_kit.dart';
import '../widgets/finance_widgets.dart';

const _methods = ['cash', 'upi', 'razorpay', 'bank_transfer'];
const _modes = [kModeSocietyPool, kModeFlatsOnly, kModeFlatsPlusOutsider, kModeOutsiderOnly];

/// Grouped "receipt type" options (`<optgroup>` per major head): null entries are headings.
List<({String? id, String label})> groupedChargeOptions(FinanceController c, String placeholder) {
  final byMajor = c.derived.chargesByMajorHead;
  return [
    (id: '', label: placeholder),
    for (final major in [...kSocietyPaymentMajorHeads, kUncategorizedHead])
      if ((byMajor[major] ?? const []).isNotEmpty) ...[
        (id: null, label: major),
        for (final ch in byMajor[major]!) (id: ch.id, label: '${ch.title} — ₹${localeNumber(ch.amount)}'),
      ],
  ];
}

/// Dropdown with major-head group headings (web `renderGroupedChargeOptions`).
class GroupedChargeDropdown extends StatelessWidget {
  const GroupedChargeDropdown({super.key, required this.c, required this.value, required this.onChanged, required this.placeholder});

  final FinanceController c;
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final opts = groupedChargeOptions(c, placeholder);
    final ids = opts.where((o) => o.id != null).map((o) => o.id!).toSet();
    return DropdownButtonFormField<String>(
      key: ValueKey('charge-$value'),
      initialValue: ids.contains(value) ? value : '',
      isExpanded: true,
      dropdownColor: t.card,
      style: TextStyle(fontSize: 14, color: t.foreground),
      onChanged: (v) {
        if (v != null && !v.startsWith('__h__')) onChanged(v);
      },
      items: [
        for (var i = 0; i < opts.length; i++)
          opts[i].id == null
              ? DropdownMenuItem<String>(
                  value: '__h__$i',
                  enabled: false,
                  child: Text(opts[i].label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.mutedForeground, letterSpacing: 0.4)),
                )
              : DropdownMenuItem<String>(
                  value: opts[i].id,
                  child: Padding(
                    padding: EdgeInsets.only(left: opts[i].id!.isEmpty ? 0 : 8),
                    child: Text(opts[i].label, overflow: TextOverflow.ellipsis),
                  ),
                ),
      ],
    );
  }
}

class FinanceRecordReceiptTab extends StatefulWidget {
  const FinanceRecordReceiptTab({super.key, required this.c, required this.form});

  final FinanceController c;
  final RecordReceiptFormModel form;

  @override
  State<FinanceRecordReceiptTab> createState() => _FinanceRecordReceiptTabState();
}

class _FinanceRecordReceiptTabState extends State<FinanceRecordReceiptTab> {
  FinanceController get c => widget.c;
  RecordReceiptFormModel get f => widget.form;

  @override
  void initState() {
    super.initState();
    f.showPaymentForm = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectCharge());
  }

  /// Web effect: when the form opens without a receipt type, pick this month's maintenance.
  void _autoSelectCharge() {
    if (!mounted || !f.showPaymentForm || f.chargeId.isNotEmpty || c.data.charges.isEmpty) return;
    final preferred = c.derived.preferredRecordCharge;
    if (preferred == null) return;
    final isCurrent = isMonthlyMaintenanceCharge(preferred) && isCurrentMonthChargeTitle(preferred.title);
    f
      ..autoSelectedChargeHint = isCurrent ? 'Auto-selected ${preferred.title}' : ''
      ..chargeId = preferred.id
      ..amount.text = numToInput(preferred.amount)
      ..changed();
  }

  List<FinancePayment> _conflictsPreview() {
    if (f.chargeId.isEmpty || (f.recordMode != kModeFlatsOnly && f.recordMode != kModeFlatsPlusOutsider) || f.selectedFlats.isEmpty) {
      return const [];
    }
    if (f.dueDate.isEmpty) return const [];
    final monthly = c.derived.monthlyMaintenanceChargeIds;
    if (monthly.contains(f.chargeId)) {
      return findMonthlyMaintenanceMonthConflicts(
        c.data.payments,
        monthly,
        [for (final fl in f.selectedFlats) (flatNumber: fl, dueDate: f.dueDate)],
      );
    }
    return findReceiptHeadConflicts(c.data.payments, [
      for (final fl in f.selectedFlats)
        ReceiptHeadRecordingTarget(flatNumber: fl, dueDate: f.dueDate, chargeId: f.chargeId, paymentMethod: f.paymentMethod),
    ]);
  }

  String _issueMessage(RecordReceiptIssue issue, {String? chargeTitle, String? badDate, String? entryMonth}) => switch (issue) {
        RecordReceiptIssue.poolAmountMissing =>
          context.tr('Enter the total receipt amount for the society pool', 'सोसाइटी पूल के लिए कुल रसीद राशि दर्ज करें'),
        RecordReceiptIssue.noFlatsSelected => context.tr('Select at least one flat', 'कम से कम एक फ्लैट चुनें'),
        RecordReceiptIssue.silentAbort => context.tr('Select a receipt type and enter the amount', 'रसीद प्रकार चुनें और राशि दर्ज करें'),
        RecordReceiptIssue.outsiderNameMissing => context.tr('Enter outsider / payer name', 'बाहरी / भुगतानकर्ता का नाम दर्ज करें'),
        RecordReceiptIssue.outsiderAmountMissing => context.tr('Enter outsider amount', 'बाहरी राशि दर्ज करें'),
        RecordReceiptIssue.outsiderChargeMissing => context.tr(
            'Select a receipt type when adjusting current month maintenance', 'चालू माह रखरखाव समायोजित करते समय रसीद प्रकार चुनें'),
        RecordReceiptIssue.chargeAndAmountMissing => context.tr(
            'Select receipt type and enter maintenance amount per flat', 'रसीद प्रकार चुनें और प्रति फ्लैट रखरखाव राशि दर्ज करें'),
        RecordReceiptIssue.outsiderNameAndAmountMissing =>
          context.tr('Enter outsider name and outsider amount', 'बाहरी नाम और बाहरी राशि दर्ज करें'),
        RecordReceiptIssue.chargeMonthMismatch => context.tr(
            'Billing date must fall in the month named by the receipt type ("$chargeTitle"). Change the billing date or select the matching month\'s receipt type.',
            'बिलिंग तिथि रसीद प्रकार ("$chargeTitle") में लिखे माह में होनी चाहिए। बिलिंग तिथि बदलें या उसी माह का रसीद प्रकार चुनें।'),
        RecordReceiptIssue.entryMonthMismatch => badDate == null
            ? context.tr('Billing date must fall within the entry month shown below.', 'बिलिंग तिथि नीचे दिखाए प्रविष्टि माह में होनी चाहिए।')
            : context.tr('Each flat billing date must be in ${isoMonthToDisplay(entryMonth)}. Check: ${isoDateToDisplay(badDate)}',
                'हर फ्लैट की बिलिंग तिथि ${isoMonthToDisplay(entryMonth)} में होनी चाहिए। जाँचें: ${isoDateToDisplay(badDate)}'),
      };

  void _err(String msg, {bool long = false}) =>
      AppFeedback.toast(context, msg, tone: BadgeTone.alert, duration: long ? const Duration(seconds: 8) : null);

  Future<void> _pickFile(String source) async {
    try {
      if (source == 'pdf') {
        final res = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        final pf = res?.files.firstOrNull;
        if (pf == null || pf.bytes == null) return;
        final ext = (pf.extension ?? '').toLowerCase();
        f.file = (bytes: pf.bytes!, name: pf.name, mime: ext == 'pdf' ? 'application/pdf' : 'image/${ext == 'jpg' ? 'jpeg' : ext}');
      } else {
        final x = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2000,
        );
        if (x == null) return;
        f.file = (bytes: await x.readAsBytes(), name: x.name, mime: x.mimeType ?? 'image/jpeg');
      }
      f.changed();
    } catch (e) {
      if (mounted) _err(financeErrorMessage(e, 'Could not open file'));
    }
  }

  Future<void> _record() async {
    final input = f.snapshot();
    final d = c.data;
    final issue = validateRecordReceipt(input, d.charges);
    if (issue != null) {
      final title = d.charges.where((ch) => ch.id == input.chargeId).firstOrNull?.title;
      _err(_issueMessage(issue, chargeTitle: title), long: issue == RecordReceiptIssue.chargeMonthMismatch);
      return;
    }
    setState(() => f.saving = true);
    try {
      if (needsReceiptHeadConflictCheck(input)) {
        final conflicts = await c.repo.queryReceiptHeadConflicts(
          chargeId: input.chargeId,
          paymentMethod: input.paymentMethod,
          targets: [for (final fl in input.selectedFlats) (flatNumber: fl, dueDate: input.dueDate)],
          monthlyMaintenanceChargeIds: c.derived.monthlyMaintenanceChargeIds.toList(),
        );
        if (!mounted) return;
        if (conflicts.isNotEmpty) {
          final head = d.charges.where((ch) => ch.id == input.chargeId).firstOrNull?.title ?? context.t('finance.receiptHead');
          final flats = {for (final p in conflicts) p.flatNumber}.join(', ');
          _err(
            context.t('finance.receiptAlreadyRecordedDetail', {
              'flat': flats,
              'month': input.dueDate.length >= 7 ? input.dueDate.substring(0, 7) : input.dueDate,
              'head': head,
            }),
            long: true,
          );
          return;
        }
      }

      if (!mounted) return;
      String? screenshotUrl = f.screenshotUrl.text.trim().isEmpty ? null : f.screenshotUrl.text.trim();
      final file = f.file;
      if (file != null) {
        if (file.bytes.length > 8 * 1024 * 1024) {
          _err(context.tr('Receipt file must be 8MB or smaller', 'रसीद फ़ाइल 8MB या छोटी होनी चाहिए'));
          return;
        }
        setState(() => f.uploading = true);
        final url = await c.repo.uploadMaintenanceReceipt(Uint8List.fromList(file.bytes), file.name, contentType: file.mime);
        if (mounted) setState(() => f.uploading = false);
        if (url == null) {
          if (mounted) _err(context.tr('Could not upload receipt', 'रसीद अपलोड नहीं हो सकी'));
          return;
        }
        screenshotUrl = url;
        f.file = null;
      }

      final built = buildRecordReceiptPlan(
        f: input,
        societyId: c.societyId,
        adminName: c.adminName,
        flats: d.flats,
        charges: d.charges,
        primaryByFlatId: d.primaryByFlatId,
        screenshotUrl: screenshotUrl,
      );
      final plan = built.plan;
      if (plan == null) {
        if (mounted) {
          _err(_issueMessage(built.issue!, badDate: built.badDate, entryMonth: billingMonthFromDate(input.dueDate)));
        }
        return;
      }
      try {
        await c.repo.persistFinanceRecord(plan);
      } catch (e) {
        if (mounted) _err(financeErrorMessage(e, 'Could not save finance entry'));
        await c.invalidateAll();
        return;
      }
      await c.invalidateAll();

      final mode = input.recordMode;
      final audience = mode == kModeFlatsOnly && f.notifyAudience == 'all' ? 'selected_flats' : f.notifyAudience;
      final allFlatCount = d.flats.length;
      f
        ..reset()
        ..showPaymentForm = false
        ..changed();

      var notified = false;
      if (audience != 'none') {
        final methodLabel = input.paymentMethod.replaceAll('_', ' ');
        final lines = [
          '${c.adminName} recorded a $methodLabel finance entry (“${plan.entryTitle}”).',
          mode == kModeSocietyPool
              ? '${inrLocale(plan.totalAmount)} is in the society pool until you distribute it equally to flats.'
              : 'Flats in this record: ${input.selectedFlats.join(', ')}. Total ${inrLocale(plan.totalAmount)}.',
          if (audience == 'all') 'This update was shared with all $allFlatCount society flat(s).',
          if (input.transactionId.trim().isNotEmpty) 'Reference: ${input.transactionId.trim()}.',
          if (input.notes.trim().isNotEmpty) input.notes.trim(),
          if (screenshotUrl != null) 'Open the notification to view the attached receipt (if available).',
        ];
        notified = await c.repo.notifyResidentsOfRecord(
          societyId: c.societyId,
          adminName: c.adminName,
          audience: audience,
          selectedFlatNumbers: input.selectedFlats,
          title: 'Payment recorded: ${plan.entryTitle}',
          message: lines.join(' '),
          notificationType: 'maintenance_payment',
          billUrl: screenshotUrl,
        );
        if (!notified && mounted) {
          _err(context.tr('Payment saved, but notifying residents failed. You can send a manual notice from Notifications.',
              'भुगतान सहेजा गया, पर निवासियों को सूचना नहीं जा सकी। सूचनाएँ खंड से मैन्युअल सूचना भेजें।'));
        }
      }
      if (!mounted) return;
      final n = plan.recordedCount;
      AppFeedback.toast(
        context,
        (n > 1 ? context.tr('Recorded $n flat lines', '$n फ्लैट पंक्तियाँ दर्ज हुईं') : context.tr('Finance entry recorded', 'वित्त प्रविष्टि दर्ज हुई')) +
            (notified ? context.tr(' · Residents notified', ' · निवासियों को सूचित किया') : ''),
        tone: BadgeTone.success,
      );
      c.bumpHeadReconciliation();
    } finally {
      if (mounted) {
        setState(() {
          f.saving = false;
          f.uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: Listenable.merge([f, c]),
      builder: (context, _) {
        if (f.showPaymentForm && f.chargeId.isEmpty && c.data.charges.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectCharge());
        }
        final d = c.data;
        final pool = f.recordMode == kModeSocietyPool;
        final outsider = f.recordMode == kModeOutsiderOnly || f.recordMode == kModeFlatsPlusOutsider;
        final scopeFlats = f.allocationIncludeVacant ? d.flats : d.flats.where((x) => x.occupied).toList();
        final conflicts = _conflictsPreview();
        final showCharge = pool ||
            f.recordMode == kModeFlatsOnly ||
            f.recordMode == kModeFlatsPlusOutsider ||
            (f.recordMode == kModeOutsiderOnly && f.destination == kDestCurrentMonth);
        final destinations = [kDestCurrentMonth, kDestCorpus, if (!pool) kDestSeparate];
        const gap = SizedBox(height: 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardSection(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(context.fin('fin.tab.payments'), icon: Icons.upload_outlined, iconColor: t.foreground),
                  FinMicroLabel(context.tr('Recording style', 'दर्ज करने का तरीका')),
                  AppDropdown<String>(
                    items: _modes,
                    value: f.recordMode,
                    labelOf: (m) => context.fin('fin.mode.$m'),
                    onChanged: (v) {
                      f.recordMode = v ?? kModeFlatsOnly;
                      if (f.recordMode == kModeFlatsOnly && f.notifyAudience == 'all') f.notifyAudience = 'none';
                      f.changed();
                    },
                  ),
                  FinHint(pool
                      ? context.tr(
                          'Receipt stays in the society pool. Open it under Transactions and use “Distribute equally to all flats” when ready.',
                          'रसीद सोसाइटी पूल में रहेगी। तैयार होने पर लेन-देन में खोलकर “सभी फ्लैटों में बराबर बाँटें” दबाएँ।')
                      : context.tr('Amount is allocated to the flats you select below at record time.',
                          'राशि दर्ज करते समय नीचे चुने गए फ्लैटों में आवंटित होगी।')),
                  gap,
                  FinDateField(
                    label: context.fin('fin.billingDate'),
                    value: f.dueDate,
                    onChanged: (v) => f
                      ..dueDate = v
                      ..changed(),
                  ),
                  FinHint(context.tr(
                    'Entry month for reports: ${isoMonthToDisplay(billingMonthFromDate(f.dueDate))} (billing date must fall in this month)',
                    'रिपोर्ट हेतु प्रविष्टि माह: ${isoMonthToDisplay(billingMonthFromDate(f.dueDate))} (बिलिंग तिथि इसी माह में हो)',
                  )),
                  if (f.recordMode != kModeFlatsOnly) ...[
                    gap,
                    FinMicroLabel(pool
                        ? context.tr('Ledger destination', 'खाता गंतव्य')
                        : context.tr('Destination (outsider / ledger)', 'गंतव्य (बाहरी / खाता)')),
                    AppDropdown<String>(
                      items: destinations,
                      value: destinations.contains(f.destination) ? f.destination : kDestCurrentMonth,
                      labelOf: (v) => context.fin('fin.dest.$v'),
                      onChanged: (v) => f
                        ..destination = v ?? kDestCurrentMonth
                        ..changed(),
                    ),
                  ],
                  if (pool) ...[
                    gap,
                    FinTintBox(
                      color: t.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(context.tr('Society pool receipt', 'सोसाइटी पूल रसीद'), style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: f.amount,
                            hint: context.tr('Total amount received (₹)', 'प्राप्त कुल राशि (₹)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: kAmountFormatters,
                          ),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: f.outsiderName,
                            hint: context.tr('Payer name (flat owner, outsider, vendor — optional)', 'भुगतानकर्ता (फ्लैट मालिक, बाहरी, विक्रेता — वैकल्पिक)'),
                          ),
                          const SizedBox(height: 8),
                          AppTextField(controller: f.outsiderRelation, hint: context.tr('Reference / relation (optional)', 'संदर्भ / संबंध (वैकल्पिक)')),
                          const SizedBox(height: 8),
                          AppTextField(controller: f.entryTitle, hint: context.tr('Title override (optional)', 'शीर्षक बदलें (वैकल्पिक)')),
                        ],
                      ),
                    ),
                  ],
                  if (!pool) ...[
                    gap,
                    FieldLabel(context.tr('Flat allocation scope', 'फ्लैट आवंटन दायरा')),
                    AppDropdown<bool>(
                      items: const [false, true],
                      value: f.allocationIncludeVacant,
                      labelOf: (v) => v
                          ? context.tr('Include vacant flats', 'खाली फ्लैट भी शामिल करें')
                          : context.tr('Occupied / sold flats only', 'केवल आबाद / बिके फ्लैट'),
                      onChanged: (v) => f
                        ..allocationIncludeVacant = v ?? false
                        ..changed(),
                    ),
                  ],
                  if (outsider) ...[
                    gap,
                    FinTintBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(context.tr('Outsider / payer', 'बाहरी / भुगतानकर्ता'), style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
                          const SizedBox(height: 8),
                          AppTextField(controller: f.outsiderName, hint: context.tr('Name (vendor, guest sponsor, etc.)', 'नाम (विक्रेता, अतिथि प्रायोजक आदि)')),
                          const SizedBox(height: 8),
                          AppTextField(controller: f.outsiderRelation, hint: context.tr('Relation or reference (optional)', 'संबंध या संदर्भ (वैकल्पिक)')),
                          const SizedBox(height: 8),
                          AppTextField(controller: f.entryTitle, hint: context.tr('Entry title override (optional)', 'प्रविष्टि शीर्षक बदलें (वैकल्पिक)')),
                          const SizedBox(height: 8),
                          FinMicroLabel(context.tr('Outsider amount split', 'बाहरी राशि विभाजन')),
                          FinRadioRow<String>(
                            value: kAllocSamePerFlat,
                            group: f.allocationStyle,
                            label: context.tr('Same amount per selected flat', 'हर चयनित फ्लैट पर समान राशि'),
                            onChanged: (v) => f
                              ..allocationStyle = v
                              ..changed(),
                          ),
                          FinRadioRow<String>(
                            value: kAllocSplitTotal,
                            group: f.allocationStyle,
                            label: context.tr('One total split equally across selected flats', 'एक कुल राशि चयनित फ्लैटों में बराबर बाँटें'),
                            onChanged: (v) => f
                              ..allocationStyle = v
                              ..changed(),
                          ),
                          const SizedBox(height: 4),
                          AppTextField(
                            controller: f.outsiderAmount,
                            hint: f.allocationStyle == kAllocSamePerFlat
                                ? context.tr('₹ per flat (outsider portion)', '₹ प्रति फ्लैट (बाहरी हिस्सा)')
                                : context.tr('₹ total (outsider pool)', '₹ कुल (बाहरी पूल)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: kAmountFormatters,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (f.autoSelectedChargeHint.isNotEmpty)
                    FinHint(
                      context.tr(f.autoSelectedChargeHint, f.autoSelectedChargeHint.replaceFirst('Auto-selected', 'स्वतः चुना:')),
                      padding: const EdgeInsets.only(top: 8),
                    ),
                  if (showCharge) ...[
                    gap,
                    GroupedChargeDropdown(
                      c: c,
                      value: f.chargeId,
                      placeholder: context.tr('Select Receipt Type', 'रसीद प्रकार चुनें'),
                      onChanged: (id) {
                        final ch = d.charges.where((x) => x.id == id).firstOrNull;
                        f
                          ..autoSelectedChargeHint = ''
                          ..chargeId = id;
                        if (ch != null && ch.amount != 0) f.amount.text = numToInput(ch.amount);
                        f.changed();
                      },
                    ),
                  ],
                  if (!pool) ...[
                    gap,
                    FlatMultiSelect(
                      flats: flatOptionsWithPrimaryLabel(scopeFlats, d.primaryByFlatId),
                      selected: f.selectedFlats,
                      label: context.tr('Flats (multi-select)', 'फ्लैट (बहु-चयन)'),
                      onChanged: (nums) => f
                        ..selectedFlats = nums
                        ..changed(),
                    ),
                  ],
                  if (pool) ...[
                    gap,
                    FieldLabel(context.tr('Distribution scope (when splitting later)', 'वितरण दायरा (बाद में बाँटते समय)')),
                    AppDropdown<bool>(
                      items: const [false, true],
                      value: f.allocationIncludeVacant,
                      labelOf: (v) => v
                          ? context.tr('Include vacant flats in equal split', 'बराबर बँटवारे में खाली फ्लैट भी')
                          : context.tr('Occupied / sold flats only', 'केवल आबाद / बिके फ्लैट'),
                      onChanged: (v) => f
                        ..allocationIncludeVacant = v ?? false
                        ..changed(),
                    ),
                  ],
                  if (f.recordMode == kModeFlatsOnly || f.recordMode == kModeFlatsPlusOutsider) ...[
                    gap,
                    AppTextField(
                      controller: f.amount,
                      hint: context.tr('Maintenance amount (₹ per flat)', 'रखरखाव राशि (₹ प्रति फ्लैट)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: kAmountFormatters,
                    ),
                  ],
                  gap,
                  AppDropdown<String>(
                    items: _methods,
                    value: f.paymentMethod,
                    labelOf: context.finMethod,
                    onChanged: (v) => f
                      ..paymentMethod = v ?? 'cash'
                      ..changed(),
                  ),
                  gap,
                  AppTextField(
                    controller: f.transactionId,
                    caps: false,
                    hint: context.tr('Transaction / reference ID (optional)', 'लेन-देन / संदर्भ आईडी (वैकल्पिक)'),
                  ),
                  gap,
                  AppTextField(
                    controller: f.screenshotUrl,
                    caps: false,
                    keyboardType: TextInputType.url,
                    hint: context.tr('Screenshot URL (paste link, optional)', 'स्क्रीनशॉट URL (लिंक चिपकाएँ, वैकल्पिक)'),
                  ),
                  gap,
                  FinMicroLabel(context.tr('Or upload receipt / bill', 'या रसीद / बिल अपलोड करें')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FinMiniButton(label: context.tr('Camera', 'कैमरा'), icon: Icons.photo_camera_outlined, onTap: () => _pickFile('camera')),
                      FinMiniButton(label: context.tr('Gallery', 'गैलरी'), icon: Icons.photo_library_outlined, onTap: () => _pickFile('gallery')),
                      FinMiniButton(label: context.tr('File / PDF', 'फ़ाइल / PDF'), icon: Icons.attach_file, onTap: () => _pickFile('pdf')),
                    ],
                  ),
                  if (f.file != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, size: 14, color: t.mutedForeground),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('${f.file!.name} (${(f.file!.bytes.length / 1024).toStringAsFixed(0)} KB)',
                                style: AppText.caption(context), overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 16, color: t.mutedForeground),
                            onPressed: () => f
                              ..file = null
                              ..changed(),
                          ),
                        ],
                      ),
                    ),
                  gap,
                  AppTextField(controller: f.notes, maxLines: 3, minLines: 2, hint: context.tr('Notes', 'टिप्पणी')),
                  gap,
                  FinTintBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.tr('Notify residents', 'निवासियों को सूचित करें'), style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
                        FinHint(context.tr(
                          'After saving, send an in-app notification (and push, if configured) so flats know a committee payment or receipt was posted—e.g. society electricity, guard salary, or maintenance collected in cash/UPI.',
                          'सहेजने के बाद ऐप सूचना (और पुश, यदि सेट हो) भेजें ताकि फ्लैटों को समिति भुगतान या रसीद की जानकारी मिले — जैसे सोसाइटी बिजली, गार्ड वेतन या नकद/UPI में लिया रखरखाव।',
                        )),
                        const SizedBox(height: 4),
                        FinRadioRow<String>(
                          value: 'none',
                          group: f.notifyAudience,
                          label: context.tr('Do not notify', 'सूचित न करें'),
                          onChanged: (v) => f
                            ..notifyAudience = v
                            ..changed(),
                        ),
                        FinRadioRow<String>(
                          value: 'selected_flats',
                          group: f.notifyAudience,
                          label: context.tr('Flats in this payment only (${f.selectedFlats.length} selected above)',
                              'केवल इस भुगतान के फ्लैट (ऊपर ${f.selectedFlats.length} चयनित)'),
                          onChanged: (v) => f
                            ..notifyAudience = v
                            ..changed(),
                        ),
                        if (f.recordMode != kModeFlatsOnly)
                          FinRadioRow<String>(
                            value: 'all',
                            group: f.notifyAudience,
                            label: context.tr('All society flats (${d.flats.length}) — for transparency (e.g. common-area bills)',
                                'सोसाइटी के सभी फ्लैट (${d.flats.length}) — पारदर्शिता हेतु (जैसे साझा क्षेत्र बिल)'),
                            onChanged: (v) => f
                              ..notifyAudience = v
                              ..changed(),
                          ),
                      ],
                    ),
                  ),
                  if (conflicts.isNotEmpty) ...[
                    gap,
                    FinTintBox(
                      color: t.destructive,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 15, color: t.destructive),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(context.t('finance.receiptAlreadyRecorded'),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.destructive)),
                              ),
                            ],
                          ),
                          FinHint(context.tr(
                            'These flats already have monthly maintenance for the selected billing month (any payment mode). Double entry is blocked. Edit or delete the existing entry in Audit → Finance Alarms before recording again.',
                            'इन फ्लैटों का चुने बिलिंग माह का मासिक रखरखाव पहले से दर्ज है (किसी भी माध्यम से)। दोहरी प्रविष्टि रोकी गई है। फिर दर्ज करने से पहले लेखा-परीक्षा → वित्त चेतावनी में मौजूदा प्रविष्टि संपादित करें या हटाएँ।',
                          )),
                          const SizedBox(height: 4),
                          for (final p in conflicts)
                            Text(
                              '${context.tr('Flat', 'फ्लैट')} ${p.flatNumber} · ₹${localeNumber(p.amount)} · ${p.paymentMethod} · ${p.paymentStatus}',
                              style: AppText.tiny(context).copyWith(color: t.foreground),
                            ),
                        ],
                      ),
                    ),
                  ],
                  gap,
                  AppButton(
                    label: f.uploading ? context.tr('Uploading…', 'अपलोड हो रहा है…') : context.fin('fin.tab.payments'),
                    loading: f.saving,
                    onPressed: f.uploading || conflicts.isNotEmpty ? null : _record,
                  ),
                ],
              ),
            ),
            FinHint(context.tr(
              'Pool receipts and flat-wise records appear under Transactions. Food / catering for functions → Events & food (split by family). All other payments (vendors, utilities, repairs) → record here as society payment / expense.',
              'पूल रसीदें और फ्लैट-वार रिकॉर्ड लेन-देन में दिखते हैं। कार्यक्रमों का भोजन / कैटरिंग → कार्यक्रम व भोजन (परिवार अनुसार)। अन्य सभी भुगतान (विक्रेता, बिजली-पानी, मरम्मत) → यहाँ सोसाइटी भुगतान / व्यय के रूप में दर्ज करें।',
            )),
          ],
        );
      },
    );
  }
}
