// Tap-to-explain copy for finance numbers — `src/lib/descriptiveMetricCopy.ts`
// (SUM_INSIGHT_METRICS, FINANCE_TOTALS_METRICS, FINANCE_LEDGER_GROUP_METRICS, FINANCE_FLAT_REPORT_METRICS)
// with Hindi translations. Each entry is (title, description, howCalculated).

import 'package:flutter/widgets.dart';

import '../../../../core/ui/ui.dart';

typedef FinCopy = (String, String, String);

class FinMetrics {
  const FinMetrics._(this.hi);

  factory FinMetrics.of(BuildContext context) => FinMetrics._(context.lang == AppLang.hi);

  final bool hi;

  FinCopy _c(FinCopy en, FinCopy hiCopy) => hi ? hiCopy : en;

  // SUM_INSIGHT_METRICS
  FinCopy get channelCash => _c(
        ('Cash total', 'Sum of amounts on the cash payment channel in this grouped view.', 'Adds rows where payment_method normalizes to cash.'),
        ('नकद कुल', 'इस समूह दृश्य में नकद माध्यम की राशियों का योग।', 'वे पंक्तियाँ जोड़ी जाती हैं जिनका payment_method नकद माना जाता है।'),
      );
  FinCopy get channelBank => _c(
        ('Bank / UPI total', 'Sum of amounts on bank, UPI, online, or card channels in this view.', 'Adds rows where payment_method normalizes to bank.'),
        ('बैंक / यूपीआई कुल', 'इस दृश्य में बैंक, यूपीआई, ऑनलाइन या कार्ड माध्यम की राशियों का योग।', 'वे पंक्तियाँ जोड़ी जाती हैं जिनका payment_method बैंक माना जाता है।'),
      );
  FinCopy get channelOther => _c(
        ('Other channels total', 'Sum on payment methods not classified as cash or bank.', 'Adds rows where payment_method normalizes to other.'),
        ('अन्य माध्यम कुल', 'नकद या बैंक के अलावा भुगतान माध्यमों का योग।', 'वे पंक्तियाँ जोड़ी जाती हैं जिनका payment_method अन्य माना जाता है।'),
      );
  FinCopy get rowTotal => _c(
        ('Row total', 'Combined cash, bank, and other for this row.', 'Cash + bank + other amounts on this row.'),
        ('पंक्ति कुल', 'इस पंक्ति का नकद, बैंक और अन्य का संयुक्त योग।', 'इस पंक्ति की नकद + बैंक + अन्य राशि।'),
      );
  FinCopy get periodExpenseHead => _c(
        ('Expense head total', 'Outflow under this expense head in the selected period.', 'Sum of separate_entry entries for this head, split by cash / bank / other.'),
        ('व्यय शीर्ष कुल', 'चुनी अवधि में इस व्यय शीर्ष के अंतर्गत बहिर्वाह।', 'इस शीर्ष की separate_entry प्रविष्टियों का योग, नकद / बैंक / अन्य में विभाजित।'),
      );
  FinCopy get cashBankReceiptTotal => _c(
        ('Receipts total', 'All inflows in this cash/bank breakdown.', 'Cash + bank + other receipt amounts in the scoped set.'),
        ('कुल रसीदें', 'इस नकद/बैंक विवरण में सभी आवक।', 'चुने गए समूह में नकद + बैंक + अन्य रसीद राशियाँ।'),
      );
  FinCopy get cashBankPaymentTotal => _c(
        ('Payments total', 'All outflows in this cash/bank breakdown.', 'Cash + bank + other payment amounts in the scoped set.'),
        ('कुल भुगतान', 'इस नकद/बैंक विवरण में सभी जावक।', 'चुने गए समूह में नकद + बैंक + अन्य भुगतान राशियाँ।'),
      );
  FinCopy get cashBankNetTotal => _c(
        ('Net total', 'Receipts minus payments across all channels in this breakdown.', 'Receipt total − payment total (per channel and overall).'),
        ('कुल शुद्ध', 'इस विवरण में सभी माध्यमों पर रसीदें घटा भुगतान।', 'रसीद कुल − भुगतान कुल (प्रति माध्यम और कुल)।'),
      );
  FinCopy get transactionListTotal => _c(
        ('Filtered transaction total', 'Sum of all entries visible under the current transaction filters.', 'Adds amounts from filtered maintenance_payments and scoped ledger-only rows.'),
        ('छाँटे गए लेन-देन का कुल', 'वर्तमान फ़िल्टर में दिखने वाली सभी प्रविष्टियों का योग।', 'छाँटे गए maintenance_payments और केवल-खाता पंक्तियों की राशियाँ जोड़ी जाती हैं।'),
      );
  FinCopy get transactionReceiptHeadGrandTotal => _c(
        ('All receipt heads (total)', 'Grand total across all receipt heads in the head-wise summary.', 'Sum of row totals in the receipt head summary table for current filters.'),
        ('सभी रसीद शीर्ष (कुल)', 'शीर्ष-वार सारांश में सभी रसीद शीर्षों का महायोग।', 'वर्तमान फ़िल्टर के लिए रसीद शीर्ष तालिका की पंक्तियों का योग।'),
      );
  FinCopy get transactionPaymentHeadGrandTotal => _c(
        ('All expense heads (total)', 'Grand total across all expense heads in the head-wise summary.', 'Sum of row totals in the payment head summary table for current filters.'),
        ('सभी व्यय शीर्ष (कुल)', 'शीर्ष-वार सारांश में सभी व्यय शीर्षों का महायोग।', 'वर्तमान फ़िल्टर के लिए भुगतान शीर्ष तालिका की पंक्तियों का योग।'),
      );

  // FINANCE_TOTALS_METRICS
  FinCopy get inflow => _c(
        ('Inflow (ledger)', 'Money recorded as coming into society books for the selected month.', 'Sum of finance_entries with inflow destinations (maintenance/corpus), excluding separate-entry outflows.'),
        ('आवक (खाता)', 'चुने माह में सोसाइटी खातों में आई दर्ज राशि।', 'आवक गंतव्य (रखरखाव/कॉर्पस) वाली finance_entries का योग, अलग-प्रविष्टि जावक छोड़कर।'),
      );
  FinCopy get groups => _c(
        ('Ledger groups', 'Distinct combinations of recording mode and destination in this month.', 'Unique mode + destination keys from finance_entries for totalsMonth.'),
        ('खाता समूह', 'इस माह में दर्ज करने की विधि और गंतव्य के अलग-अलग संयोजन।', 'totalsMonth के लिए finance_entries की अनोखी विधि + गंतव्य कुंजियाँ।'),
      );
  FinCopy get flatUnits => _c(
        ('Flat allocation rows', 'Total flat-level allocation units posted in ledger entries.', 'Sum of aggregate_flat_count (and allocation rows) for inflow entries in the month.'),
        ('फ्लैट आवंटन पंक्तियाँ', 'खाता प्रविष्टियों में दर्ज फ्लैट-स्तर आवंटन इकाइयाँ।', 'माह की आवक प्रविष्टियों के aggregate_flat_count का योग।'),
      );
  FinCopy get outflow => _c(
        ('Outflow (payments made)', 'Money recorded as paid out (separate-entry expenses) in the selected month.', 'Sum of finance_entries with destination separate_entry for totalsMonth.'),
        ('जावक (किए गए भुगतान)', 'चुने माह में भुगतान के रूप में दर्ज राशि (अलग-प्रविष्टि व्यय)।', 'totalsMonth के लिए separate_entry गंतव्य वाली finance_entries का योग।'),
      );
  FinCopy get expenseHeads => _c(
        ('Expense heads', 'Distinct expense titles in outflow for the month.', 'Count of rows in totalsOutflowBreakdown.'),
        ('व्यय शीर्ष', 'माह के जावक में अलग-अलग व्यय शीर्षक।', 'totalsOutflowBreakdown की पंक्तियों की गिनती।'),
      );
  FinCopy get netInflowOutflow => _c(
        ('Net (Inflow − Outflow)', 'Ledger inflow minus outflow for the month.', 'totalsMonthNet − totalsMonthOutflow.'),
        ('शुद्ध (आवक − जावक)', 'माह का खाता आवक घटा जावक।', 'totalsMonthNet − totalsMonthOutflow।'),
      );

  // FINANCE_LEDGER_GROUP_METRICS
  FinCopy get inflowGroup => _c(
        ('Ledger inflow group total', 'Sum posted under this recording mode and destination for the selected month.', 'Adds total_amount from finance_entries in totalsMonth matching this record_mode + destination (maintenance/corpus inflows).'),
        ('खाता आवक समूह कुल', 'चुने माह में इस विधि और गंतव्य के अंतर्गत दर्ज योग।', 'totalsMonth में इस record_mode + गंतव्य वाली finance_entries का total_amount जोड़ा जाता है।'),
      );
  FinCopy get outflowHead => _c(
        ('Expense head total', 'Money recorded as paid out under this expense title in the selected month.', 'Sums finance_entries with destination separate_entry for this expense head and payment method in totalsMonth.'),
        ('व्यय शीर्ष कुल', 'चुने माह में इस व्यय शीर्षक के अंतर्गत भुगतान की गई राशि।', 'totalsMonth में इस व्यय शीर्ष की separate_entry प्रविष्टियों का योग।'),
      );

  // FINANCE_FLAT_REPORT_METRICS
  FinCopy get flatTotalReceipts => _c(
        ('Total receipts', 'Maintenance and verified payments attributed to flats in the report period.', 'Sum of maintenance_paid per flat in the flat report range.'),
        ('कुल रसीदें', 'रिपोर्ट अवधि में फ्लैटों से प्राप्त रखरखाव व सत्यापित भुगतान।', 'फ्लैट रिपोर्ट अवधि में प्रति फ्लैट maintenance_paid का योग।'),
      );
  FinCopy get flatExpenseShare => _c(
        ('Total expense share', 'Each flat’s share of event/function (and group) expenses in the period.', 'Sum of expense_share from expense_splits in range.'),
        ('कुल व्यय हिस्सा', 'अवधि में कार्यक्रम/समूह व्ययों में प्रत्येक फ्लैट का हिस्सा।', 'अवधि में expense_splits के expense_share का योग।'),
      );
  FinCopy get flatSettled => _c(
        ('Settled', 'Portion of expense shares already marked settled between flats.', 'Sum of settled_amount per flat.'),
        ('निपटाया गया', 'व्यय हिस्से का वह भाग जो निपटाया जा चुका है।', 'प्रति फ्लैट settled_amount का योग।'),
      );
  FinCopy get flatUnsettled => _c(
        ('Unsettled', 'Outstanding share flats still owe each other or the pool.', 'Sum of unsettled_amount per flat.'),
        ('बकाया', 'वह हिस्सा जो फ्लैटों को अब भी चुकाना है।', 'प्रति फ्लैट unsettled_amount का योग।'),
      );
}
