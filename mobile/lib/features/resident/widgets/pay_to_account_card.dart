import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/ui.dart';
import '../data/payment_rules.dart';
import '../data/resident_models.dart';

/// Opens a UPI app with [url]; toasts when no UPI app is installed.
Future<void> launchUpi(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    AppFeedback.toast(context, context.tr('No UPI app found on this phone', 'इस फोन पर कोई यूपीआई ऐप नहीं मिला'),
        tone: BadgeTone.alert);
  }
}

/// Port of web `SocietyPayToAccountCard`.
class SocietyPayToAccountCard extends StatelessWidget {
  const SocietyPayToAccountCard({super.key, required this.account, this.amount, this.note});

  final SocietyBankAccountRow account;
  final double? amount;
  final String? note;

  Future<void> _copy(BuildContext context, String label, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        AppFeedback.toast(context, context.tr('$label copied', '$label कॉपी हुआ'), tone: BadgeTone.success);
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.toast(context, context.tr('Could not copy', 'कॉपी नहीं हो सका'), tone: BadgeTone.alert);
      }
    }
  }

  void _openUpi(BuildContext context) {
    if (!account.hasUpi) {
      AppFeedback.toast(
        context,
        context.tr('Society UPI ID is not configured yet. Use bank transfer with account number & IFSC.',
            'सोसाइटी की यूपीआई आईडी अभी सेट नहीं है। खाता संख्या व IFSC से बैंक ट्रांसफ़र करें।'),
        tone: BadgeTone.alert,
      );
      return;
    }
    if (amount == null || amount! <= 0) {
      AppFeedback.toast(context, context.tr('Enter amount first', 'पहले राशि दर्ज करें'), tone: BadgeTone.alert);
      return;
    }
    launchUpi(context,
        buildUpiPayUrl(upiVpa: account.upiVpa!, payeeName: account.accountHolderName, amount: amount, note: note));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget row(String label, String value, {bool mono = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: AppText.tiny(context).copyWith(letterSpacing: 0.8)),
                SelectableText(value, style: mono ? AppText.mono(context, size: 14) : AppText.bodyMedium(context)),
              ]),
            ),
            TextButton(
              style:
                  TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11)),
              onPressed: () => _copy(context, label, value),
              child: Text(context.tr('Copy', 'कॉपी')),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.primary, 0.05),
        border: Border.all(color: AppTokens.tint(t.primary, 0.2)),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.account_balance_outlined, size: 16, color: t.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Pay to society account', 'सोसाइटी खाते में भुगतान करें'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground)),
              Text(account.bankName, style: AppText.tiny(context)),
            ]),
          ),
          AppButton.secondary(
            label: context.tr('Copy all', 'सब कॉपी करें'),
            icon: Icons.copy,
            dense: true,
            expand: false,
            onPressed: () =>
                _copy(context, context.tr('All bank details', 'सभी बैंक विवरण'), copyableBankDetails(account)),
          ),
        ]),
        const SizedBox(height: 10),
        row(context.tr('Account name', 'खाताधारक'), account.accountHolderName),
        row(context.tr('Account no.', 'खाता सं.'), account.accountNumber, mono: true),
        row('IFSC', account.ifsc, mono: true),
        if ((account.branchName ?? '').isNotEmpty) row(context.tr('Branch', 'शाखा'), account.branchName!),
        if (account.hasUpi) row(context.tr('UPI ID', 'यूपीआई आईडी'), account.upiVpa!, mono: true),
        if (account.hasUpi) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: context.tr('Open UPI app', 'यूपीआई ऐप खोलें'),
              icon: Icons.smartphone,
              dense: true,
              expand: false,
              onPressed: () => _openUpi(context),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          context.tr(
              'Transfer via UPI / NEFT / IMPS to this account, then submit your UTR / reference and receipt below for verification.',
              'इस खाते में UPI / NEFT / IMPS से भुगतान करें, फिर सत्यापन के लिए नीचे UTR / संदर्भ और रसीद जमा करें।'),
          style: AppText.tiny(context),
        ),
      ]),
    );
  }
}
