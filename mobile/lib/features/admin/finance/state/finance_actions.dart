// FinanceManager row actions: verifyPayment, rejectPayment, applyMaintenancePaymentStatus,
// deleteMaintenancePaymentRow, updateLedgerEntryStatus, deleteLedgerRow, distributePoolToAllFlats,
// savePaymentEdit, saveLedgerEdit, bulk delete / status.

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/finance_repository.dart';
import '../logic/finance_charge_helpers.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../logic/finance_ledger_display.dart';
import '../logic/finance_models.dart';
import '../logic/flat_sort.dart';
import '../logic/record_receipt_plan.dart';
import '../widgets/fin_kit.dart';
import 'finance_controller.dart';

class FinanceActions {
  FinanceActions(this.c);

  final FinanceController c;

  String _chargeTitle(FinancePayment p) {
    final t = c.derived.chargeById[p.chargeId ?? '']?.title ?? '';
    return t.isEmpty ? 'Maintenance charge' : t;
  }

  void _toast(BuildContext context, String m, {BadgeTone tone = BadgeTone.success, bool long = false}) {
    if (context.mounted) AppFeedback.toast(context, m, tone: tone, duration: long ? const Duration(seconds: 8) : null);
  }

  Future<void> _notifyDecision(FinancePayment row, String status, String? reason) async {
    if (row.flatNumber.isEmpty) return;
    final title = _chargeTitle(row);
    if (status == 'verified') {
      await c.repo.notifyPaymentDecision(
        societyId: c.societyId,
        adminName: c.adminName,
        flatNumber: row.flatNumber,
        title: 'Payment approved: $title',
        message: 'Your payment of ${inrLocale(row.amount)} has been approved by ${c.adminName}.',
      );
    } else if (status == 'rejected') {
      final r = (reason ?? '').trim().isEmpty ? 'Rejected by admin' : reason!.trim();
      await c.repo.notifyPaymentDecision(
        societyId: c.societyId,
        adminName: c.adminName,
        flatNumber: row.flatNumber,
        title: 'Payment rejected: $title',
        message: 'Your payment entry was rejected by ${c.adminName}. Reason: $r',
      );
    }
  }

  Future<void> verify(BuildContext context, FinancePayment p) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Verify Payment?', 'भुगतान सत्यापित करें?'),
      message: context.tr('Confirm this payment as verified?', 'क्या इस भुगतान को सत्यापित मानें?'),
      confirmLabel: context.tr('Yes, Verify', 'हाँ, सत्यापित करें'),
      cancelLabel: context.fin('fin.cancel'),
    );
    if (!ok) return;
    try {
      await c.repo.updatePaymentStatus(p.id, 'verified', c.adminName);
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) _toast(context, financeErrorMessage(e, 'Could not verify payment'), tone: BadgeTone.alert);
      return;
    }
    await _notifyDecision(p, 'verified', null);
    if (context.mounted) {
      await AppFeedback.success(context,
          title: context.tr('Verified!', 'सत्यापित!'), message: context.tr('Payment verified successfully', 'भुगतान सफलतापूर्वक सत्यापित'));
    }
  }

  Future<String?> _askReason(BuildContext context, String title, {String initial = ''}) => AppFeedback.prompt(
        context,
        title: title,
        initial: initial,
        hint: context.tr('Reason', 'कारण'),
        confirmLabel: context.tr('OK', 'ठीक'),
      );

  Future<void> reject(BuildContext context, FinancePayment p) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Reject Payment?', 'भुगतान अस्वीकार करें?'),
      message: context.tr('Are you sure you want to reject this payment?', 'क्या आप यह भुगतान अस्वीकार करना चाहते हैं?'),
      confirmLabel: context.tr('Yes, Reject', 'हाँ, अस्वीकार करें'),
      cancelLabel: context.fin('fin.cancel'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final input = await _askReason(context, context.tr('Enter rejection reason (required):', 'अस्वीकृति का कारण दर्ज करें (आवश्यक):'));
    if (input == null || !context.mounted) return;
    final reason = input.trim();
    if (reason.isEmpty) {
      _toast(context, context.tr('Rejection reason is required', 'अस्वीकृति का कारण आवश्यक है'), tone: BadgeTone.alert);
      return;
    }
    try {
      await c.repo.updatePaymentStatus(p.id, 'rejected', c.adminName, reason);
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) _toast(context, financeErrorMessage(e, 'Could not reject payment'), tone: BadgeTone.alert);
      return;
    }
    await _notifyDecision(p, 'rejected', reason);
    if (context.mounted) {
      await AppFeedback.success(context,
          title: context.tr('Rejected', 'अस्वीकृत'), message: context.tr('Payment has been rejected', 'भुगतान अस्वीकार किया गया'));
    }
  }

  /// Web `applyMaintenancePaymentStatus`.
  Future<bool> applyStatus(BuildContext context, FinancePayment p, String next, {String? reason, bool notify = true, bool reload = true}) async {
    try {
      await c.repo.updatePaymentStatus(p.id, next, c.adminName, reason);
    } catch (e) {
      if (context.mounted) _toast(context, financeErrorMessage(e), tone: BadgeTone.alert);
      return false;
    }
    if (notify) await _notifyDecision(p, next, reason);
    if (reload) await c.invalidateAll();
    return true;
  }

  /// Status dropdown on a payment card.
  Future<void> changeStatus(BuildContext context, FinancePayment p, String next) async {
    if (next == p.paymentStatus) return;
    if (next == 'rejected') {
      final r = await _askReason(context, context.tr('Rejection reason:', 'अस्वीकृति का कारण:'), initial: p.rejectionReason ?? '');
      if (r == null || !context.mounted) return;
      if (r.trim().isEmpty) {
        _toast(context, context.tr('Reason required', 'कारण आवश्यक'), tone: BadgeTone.alert);
        return;
      }
      await applyStatus(context, p, 'rejected', reason: r.trim());
      return;
    }
    await applyStatus(context, p, next);
  }

  Future<bool> deletePayment(BuildContext context, FinancePayment p) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete this payment?', 'यह भुगतान हटाएँ?'),
      message: context.tr('This removes the payment record and updates linked ledger rows when applicable.',
          'इससे भुगतान रिकॉर्ड हटेगा और जुड़ी खाता पंक्तियाँ अपडेट होंगी।'),
      confirmLabel: context.fin('fin.delete'),
      cancelLabel: context.fin('fin.cancel'),
      destructive: true,
    );
    if (!ok) return false;
    await c.repo.deletePaymentRow(id: p.id, flatNumber: p.flatNumber, financeEntryId: p.financeEntryId);
    await c.invalidateAll();
    if (context.mounted) _toast(context, context.tr('Payment deleted', 'भुगतान हटाया गया'));
    return true;
  }

  Future<void> setLedgerStatus(BuildContext context, FinanceLedgerRow e, String status) async {
    if (status == e.paymentStatus) return;
    try {
      await c.repo.updateLedgerStatus(e.id, status);
      await c.invalidateAll();
    } catch (err) {
      if (context.mounted) _toast(context, financeErrorMessage(err, 'Could not update status'), tone: BadgeTone.alert);
      return;
    }
    if (context.mounted) _toast(context, context.tr('Status updated', 'स्थिति अपडेट हुई'));
  }

  Future<bool> deleteLedger(BuildContext context, FinanceLedgerRow e) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete this ledger entry?', 'यह खाता प्रविष्टि हटाएँ?'),
      message: context.tr('Removes ledger allocations and counterparty data. Ledger-only rows have no maintenance payments.',
          'खाता आवंटन और प्रतिपक्ष डेटा हटेगा। केवल-खाता पंक्तियों में रखरखाव भुगतान नहीं होते।'),
      confirmLabel: context.fin('fin.delete'),
      cancelLabel: context.fin('fin.cancel'),
      destructive: true,
    );
    if (!ok) return false;
    try {
      await c.repo.deleteLedger(e.id);
      await c.invalidateAll();
    } catch (err) {
      if (context.mounted) _toast(context, financeErrorMessage(err, 'Could not delete ledger entry'), tone: BadgeTone.alert);
      return false;
    }
    if (context.mounted) _toast(context, context.tr('Ledger entry deleted', 'खाता प्रविष्टि हटाई गई'));
    return true;
  }

  /// Web `distributePoolToAllFlats`.
  Future<bool> distribute(BuildContext context, FinanceLedgerRow entry) async {
    if (!isLedgerInSocietyPool(entry)) return false;
    final d = c.data;
    final scope = entry.includeVacant ? d.flats : d.flats.where((f) => f.occupied).toList();
    if (scope.isEmpty) {
      _toast(context, context.tr('No flats available to distribute to', 'बाँटने के लिए कोई फ्लैट नहीं'), tone: BadgeTone.alert);
      return false;
    }
    final amounts = distributePoolAmounts(entry.totalAmount, scope.length);
    final perFlat = amounts.first;
    final postsMp = entry.destination == kDestCurrentMonth && (entry.chargeId ?? '').isNotEmpty;
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Distribute to all flats equally?', 'सभी फ्लैटों में बराबर बाँटें?'),
      message: context.tr(
        '${inrLocale(entry.totalAmount)} across ${scope.length} flat(s) ≈ ${inrLocale(perFlat)} each.${postsMp ? ' Verified maintenance payment rows will be created per flat.' : ''}',
        '${inrLocale(entry.totalAmount)} को ${scope.length} फ्लैटों में ≈ ${inrLocale(perFlat)} प्रति फ्लैट।${postsMp ? ' हर फ्लैट के लिए सत्यापित रखरखाव भुगतान पंक्ति बनेगी।' : ''}',
      ),
      confirmLabel: context.tr('Distribute', 'बाँटें'),
      cancelLabel: context.fin('fin.cancel'),
    );
    if (!ok || !context.mounted) return false;

    final chargeTitle = (entry.chargeId ?? '').isNotEmpty ? (c.derived.chargeById[entry.chargeId]?.title ?? '') : '';
    final billingDate = ledgerTransactionDate(entry);
    if (postsMp) {
      final conflicts = await c.repo.queryReceiptHeadConflicts(
        chargeId: entry.chargeId!,
        paymentMethod: entry.paymentMethod,
        targets: [for (final f in scope) (flatNumber: f.flatNumber, dueDate: billingDate)],
        monthlyMaintenanceChargeIds: c.derived.monthlyMaintenanceChargeIds.toList(),
      );
      if (conflicts.isNotEmpty) {
        final flatList = {for (final p in conflicts) p.flatNumber}.join(', ');
        final ym = billingDate.length >= 7 ? billingDate.substring(0, 7) : billingDate;
        if (context.mounted) {
          _toast(
            context,
            context.tr(
              'Cannot distribute — monthly maintenance already recorded for Flat $flatList in $ym. Edit or delete in Audit → Finance Alarms.',
              'बाँट नहीं सकते — फ्लैट $flatList का $ym का मासिक रखरखाव पहले से दर्ज है। लेखा-परीक्षा → वित्त चेतावनी में संपादित करें या हटाएँ।',
            ),
            tone: BadgeTone.alert,
            long: true,
          );
        }
        return false;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final allocations = <AllocationInsert>[];
    final mpRows = <Map<String, dynamic>>[];
    for (var i = 0; i < scope.length; i++) {
      final flat = scope[i];
      allocations.add(AllocationInsert(flatNumber: flat.flatNumber, flatId: flat.id, amount: amounts[i]));
      if (postsMp) {
        mpRows.add({
          'charge_id': entry.chargeId,
          'flat_id': flat.id,
          'flat_number': flat.flatNumber,
          'resident_name': residentLabelForFlatRow(flat.id, flat.ownerName, d.primaryByFlatId),
          'amount': amounts[i],
          'payment_method': entry.paymentMethod,
          'payment_status': 'verified',
          'payment_date': now,
          'due_date': billingDate,
          'recording_date': todayRecordingDate(),
          'transaction_id': entry.transactionId,
          'screenshot_url': entry.screenshotUrl,
          'notes': entry.notes,
          'submitted_by': 'admin',
          'submitted_by_user_id': null,
          'verified_by': c.adminName,
          'verified_at': now,
          'reviewed_at': now,
          'rejection_reason': null,
          'finance_entry_id': entry.id,
        });
      }
    }
    try {
      await c.repo.distributePool(
        entryId: entry.id,
        allocationRows: allocations,
        maintenancePaymentRows: mpRows,
        aggregateFlatCount: scope.length,
        title: (entry.title ?? '').isNotEmpty
            ? entry.title!
            : (chargeTitle.isNotEmpty ? chargeTitle : 'Society receipt (distributed)'),
      );
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) _toast(context, financeErrorMessage(e, 'Could not distribute pool'), tone: BadgeTone.alert);
      return false;
    }
    if (context.mounted) _toast(context, context.tr('Distributed across ${scope.length} flat(s)', '${scope.length} फ्लैटों में बाँटा गया'));
    return true;
  }

  /// Web `savePaymentEdit`; returns true when saved.
  Future<bool> savePaymentEdit(
    BuildContext context, {
    required FinancePayment original,
    required String chargeId,
    required String amount,
    required String paymentMethod,
    required String transactionId,
    required String notes,
    required String dueDate,
    required String recordingDate,
    required String paymentStatus,
    required String rejectionReason,
  }) async {
    final charge = c.derived.chargeById[chargeId];
    if (charge != null && !chargeTitleMatchesBillingMonth(charge.title, dueDate)) {
      _toast(
        context,
        context.tr('Billing date must fall in the month named by the receipt type ("${charge.title}").',
            'बिलिंग तिथि रसीद प्रकार ("${charge.title}") में लिखे माह में होनी चाहिए।'),
        tone: BadgeTone.alert,
        long: true,
      );
      return false;
    }
    if (charge != null && isMonthlyMaintenanceCharge(charge) && (paymentStatus == 'verified' || paymentStatus == 'pending')) {
      final conflicts = await c.repo.queryReceiptHeadConflicts(
        chargeId: chargeId,
        targets: [(flatNumber: original.flatNumber, dueDate: dueDate)],
        monthlyMaintenanceChargeIds: c.derived.monthlyMaintenanceChargeIds.toList(),
      );
      if (conflicts.any((x) => x.id != original.id)) {
        if (context.mounted) {
          final ym = dueDate.length >= 7 ? dueDate.substring(0, 7) : dueDate;
          _toast(
            context,
            context.tr('Flat ${original.flatNumber} already has monthly maintenance for $ym. Double entry for the same month is not allowed.',
                'फ्लैट ${original.flatNumber} का $ym का मासिक रखरखाव पहले से है। एक ही माह की दोहरी प्रविष्टि अनुमत नहीं।'),
            tone: BadgeTone.alert,
            long: true,
          );
        }
        return false;
      }
    }
    final reviewedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'charge_id': chargeId.isEmpty ? null : chargeId,
      'amount': jsNumber(amount),
      'payment_method': paymentMethod,
      'transaction_id': transactionId.trim().isEmpty ? null : transactionId.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
      'due_date': dueDate,
      'recording_date': recordingDate,
      'payment_status': paymentStatus,
    };
    if (paymentStatus == 'verified') {
      payload.addAll({'verified_by': c.adminName, 'verified_at': reviewedAt, 'reviewed_at': reviewedAt, 'rejection_reason': null});
    } else if (paymentStatus == 'rejected') {
      payload.addAll({
        'verified_by': c.adminName,
        'verified_at': reviewedAt,
        'reviewed_at': reviewedAt,
        'rejection_reason': rejectionReason.trim().isEmpty ? 'Rejected by admin' : rejectionReason.trim(),
      });
    } else {
      payload.addAll({'verified_by': null, 'verified_at': null, 'reviewed_at': null, 'rejection_reason': null});
    }
    try {
      await c.repo.updatePayment(original.id, payload);
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) _toast(context, financeErrorMessage(e, 'Could not update payment'), tone: BadgeTone.alert);
      return false;
    }
    if (context.mounted) _toast(context, context.tr('Payment updated', 'भुगतान अपडेट हुआ'));
    return true;
  }

  /// Web `saveLedgerEdit`.
  Future<bool> saveLedgerEdit(
    BuildContext context, {
    required FinanceLedgerRow original,
    required String title,
    required String notes,
    required String paymentStatus,
    required String transactionId,
    required String paymentMethod,
    required String totalAmount,
    required String transactionDate,
  }) async {
    final entryMonth = ledgerEntryMonthFromBilling(transactionDate);
    if (!isBillingDateInEntryMonth(transactionDate, entryMonth)) {
      _toast(context, context.tr('Billing date must fall within the entry month.', 'बिलिंग तिथि प्रविष्टि माह में होनी चाहिए।'), tone: BadgeTone.alert);
      return false;
    }
    final amt = jsNumber(totalAmount);
    try {
      await c.repo.updateLedger(original.id, {
        'title': title.trim().isEmpty ? null : title.trim(),
        'notes': notes.trim().isEmpty ? null : notes.trim(),
        'payment_status': paymentStatus,
        'transaction_id': transactionId.trim().isEmpty ? null : transactionId.trim(),
        'payment_method': paymentMethod,
        'total_amount': amt.isNaN ? 0 : amt,
        'entry_month': entryMonth,
        'transaction_date': transactionDate,
      });
      await c.invalidateAll();
    } catch (e) {
      if (context.mounted) _toast(context, financeErrorMessage(e, 'Could not update ledger entry'), tone: BadgeTone.alert);
      return false;
    }
    if (context.mounted) _toast(context, context.tr('Ledger entry updated', 'खाता प्रविष्टि अपडेट हुई'));
    return true;
  }

  /// Web `bulkDeleteSelectedReceipts`.
  Future<bool> bulkDelete(BuildContext context, Set<String> keys) async {
    if (keys.isEmpty) return false;
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete ${keys.length} selected entries?', '${keys.length} चयनित प्रविष्टियाँ हटाएँ?'),
      message: context.tr('This cannot be undone.', 'यह वापस नहीं होगा।'),
      confirmLabel: context.tr('Delete all', 'सब हटाएँ'),
      cancelLabel: context.fin('fin.cancel'),
      destructive: true,
    );
    if (!ok) return false;
    final byId = {for (final p in c.data.payments) p.id: p};
    for (final key in keys) {
      if (key.startsWith('mp-')) {
        final p = byId[key.substring(3)];
        if (p != null) await c.repo.deletePaymentRow(id: p.id, flatNumber: p.flatNumber, financeEntryId: p.financeEntryId);
      } else if (key.startsWith('ledger-')) {
        try {
          await c.repo.deleteLedger(key.substring(7));
        } catch (_) {
          // continue with the remaining rows (web awaits each mutation)
        }
      }
    }
    await c.invalidateAll();
    if (context.mounted) _toast(context, context.tr('Selected entries deleted', 'चयनित प्रविष्टियाँ हटाई गईं'));
    return true;
  }

  /// Web `bulkSetPaymentStatus` (residents are not notified in bulk mode).
  Future<bool> bulkStatus(BuildContext context, Set<String> keys, String next) async {
    final ids = keys.where((k) => k.startsWith('mp-')).map((k) => k.substring(3)).toList();
    if (ids.isEmpty) {
      _toast(context, context.tr('Select maintenance payment rows (not ledger-only) for bulk status', 'बल्क स्थिति के लिए रखरखाव भुगतान पंक्तियाँ चुनें (केवल-खाता नहीं)'),
          tone: BadgeTone.alert);
      return false;
    }
    var reason = '';
    if (next == 'rejected') {
      reason = (await _askReason(context, context.tr('Rejection reason for all selected (required):', 'सभी चयनितों के लिए अस्वीकृति कारण (आवश्यक):'))) ?? '';
      if (!context.mounted) return false;
      if (reason.trim().isEmpty) {
        _toast(context, context.tr('Reason required', 'कारण आवश्यक'), tone: BadgeTone.alert);
        return false;
      }
    }
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Set ${ids.length} payments to $next?', '${ids.length} भुगतानों को ${context.finStatus(next)} करें?'),
      message: next == 'rejected'
          ? '${context.tr('Reason', 'कारण')}: $reason'
          : context.tr('Residents will not be notified in bulk mode.', 'बल्क मोड में निवासियों को सूचना नहीं जाएगी।'),
      confirmLabel: context.tr('Apply', 'लागू करें'),
      cancelLabel: context.fin('fin.cancel'),
    );
    if (!ok || !context.mounted) return false;
    final byId = {for (final p in c.data.payments) p.id: p};
    for (final id in ids) {
      final p = byId[id];
      if (p == null || !context.mounted) continue;
      await applyStatus(context, p, next, reason: reason.trim(), notify: false, reload: false);
    }
    await c.invalidateAll();
    if (context.mounted) _toast(context, context.tr('Status updated for selected payments', 'चयनित भुगतानों की स्थिति अपडेट हुई'));
    return true;
  }
}
