// Port of `src/components/SocietyPayToAccountCard.tsx` (+ `buildUpiPayUrl` / `maskAccountNumber`
// from `src/lib/societyBankAccount.ts`). Reusable by the resident payments screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import '../../../../models/society_bank_account.dart';

String maskAccountNumber(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp(r'\s+'), '');
  if (digits.length <= 4) return digits;
  return '${'•' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
}

String buildUpiPayUrl(
    {required String upiVpa,
    required String payeeName,
    double? amount,
    String? note}) {
  final params = <String, String>{
    'pa': upiVpa.trim(),
    'pn': payeeName.trim().isEmpty ? 'Society' : payeeName.trim(),
    'cu': 'INR',
    if (amount != null && amount > 0)
      'am': amount == amount.roundToDouble() ? '${amount.round()}' : '$amount',
    if ((note ?? '').trim().isNotEmpty) 'tn': note!.trim(),
  };
  return 'upi://pay?${Uri(queryParameters: params).query}';
}

class SocietyPayToAccountCard extends StatelessWidget {
  const SocietyPayToAccountCard(
      {super.key,
      required this.account,
      this.amount,
      this.note,
      this.compact = false});

  final SocietyBankAccount account;
  final double? amount;
  final String? note;
  final bool compact;

  Future<void> _copy(BuildContext context, String label, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        AppFeedback.toast(
            context, context.tr('$label copied', '$label कॉपी हुआ'),
            tone: BadgeTone.success);
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.toast(
            context, context.tr('Could not copy', 'कॉपी नहीं हो सका'),
            tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _openUpi(BuildContext context) async {
    final vpa = account.upiVpa?.trim() ?? '';
    if (vpa.isEmpty) {
      AppFeedback.toast(
        context,
        context.tr(
            'Society UPI ID is not configured yet. Use bank transfer with account number & IFSC.',
            'सोसाइटी UPI ID अभी सेट नहीं है। खाता संख्या व IFSC से बैंक ट्रांसफ़र करें।'),
        tone: BadgeTone.alert,
      );
      return;
    }
    if (amount == null || amount! <= 0) {
      AppFeedback.toast(
          context, context.tr('Enter amount first', 'पहले राशि दर्ज करें'),
          tone: BadgeTone.alert);
      return;
    }
    final ok = await ExportKit.openUrl(buildUpiPayUrl(
        upiVpa: vpa,
        payeeName: account.accountHolderName,
        amount: amount,
        note: note));
    if (!ok && context.mounted) {
      AppFeedback.toast(
          context, context.tr('No UPI app found', 'कोई UPI ऐप नहीं मिला'),
          tone: BadgeTone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget row(String label, String value, {bool mono = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style:
                            AppText.tiny(context).copyWith(letterSpacing: 0.8)),
                    SelectableText(value,
                        style: mono
                            ? AppText.mono(context, size: 14)
                            : AppText.bodyMedium(context)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _copy(context, label, value),
                child: Text(context.tr('Copy', 'कॉपी'),
                    style: TextStyle(fontSize: 11, color: t.primary)),
              ),
            ],
          ),
        );
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.primary, 0.05),
        border: Border.all(color: AppTokens.tint(t.primary, 0.2)),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_outlined, size: 16, color: t.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        context.tr('Pay to society account',
                            'सोसाइटी खाते में भुगतान करें'),
                        style: AppText.bodyMedium(context).copyWith(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(account.bankName, style: AppText.tiny(context)),
                  ],
                ),
              ),
              AppButton.secondary(
                label: context.tr('Copy all', 'सब कॉपी करें'),
                icon: Icons.copy,
                dense: true,
                expand: false,
                onPressed: () => _copy(
                    context,
                    context.tr('All bank details', 'सभी बैंक विवरण'),
                    account.copyableDetails),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(context.tr('Account name', 'खाता नाम'),
              account.accountHolderName),
          row(context.tr('Account no.', 'खाता सं.'), account.accountNumber,
              mono: true),
          row('IFSC', account.ifsc, mono: true),
          if ((account.branchName ?? '').isNotEmpty)
            row(context.tr('Branch', 'शाखा'), account.branchName!),
          if ((account.upiVpa ?? '').isNotEmpty)
            row('UPI ID', account.upiVpa!, mono: true),
          if ((account.upiVpa ?? '').isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: context.tr('Open UPI app', 'UPI ऐप खोलें'),
                icon: Icons.smartphone,
                dense: true,
                expand: false,
                onPressed: () => _openUpi(context),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Transfer via UPI / NEFT / IMPS to this account, then submit your UTR / reference and receipt below for verification.',
              'इस खाते में UPI / NEFT / IMPS से भेजें, फिर सत्यापन के लिए नीचे UTR / संदर्भ और रसीद जमा करें।',
            ),
            style: AppText.tiny(context),
          ),
        ],
      ),
    );
  }
}
