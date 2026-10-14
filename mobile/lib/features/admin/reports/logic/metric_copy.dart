/// Tap-to-explain copy for report cards — port of the entries of
/// `src/lib/descriptiveMetricCopy.ts` used by Reports, with Hindi translations.
class MetricCopy {
  const MetricCopy(this.titleEn, this.titleHi, this.descEn, this.descHi,
      [this.howEn, this.howHi]);

  final String titleEn;
  final String titleHi;
  final String descEn;
  final String descHi;
  final String? howEn;
  final String? howHi;

  String title(bool hi) => hi ? titleHi : titleEn;
  String description(bool hi) => hi ? descHi : descEn;
  String? how(bool hi) => hi ? (howHi ?? howEn) : howEn;
}

abstract final class ReportMetrics {
  // REPORT_PAGE_METRICS
  static const financeGross = MetricCopy(
    'Finance gross',
    'वित्त सकल',
    'Sum of all finance ledger entry amounts in the month (before drilling into mode/destination).',
    'माह में सभी वित्त खाता-बही प्रविष्टियों की राशि का योग (विधि/गंतव्य में जाने से पहले)।',
    'Sum of total_amount on finance_entries where entry_month matches reportMonth.',
    'finance_entries की total_amount का योग जहाँ entry_month चुने गए माह से मेल खाता है।',
  );
  static const guardShifts = MetricCopy(
    'Guard shifts',
    'गार्ड पारी',
    'Guard login and logout records for the report month.',
    'प्रतिवेदन माह के गार्ड लॉगिन और लॉगआउट अभिलेख।',
    'Count of guard shift rows with login_time in reportMonth.',
    'चुने गए माह में login_time वाली गार्ड पारी पंक्तियों की गिनती।',
  );
  static const moduleVisitors = MetricCopy(
    'Visitors (month)',
    'आगंतुक (माह)',
    'Guest visitor log entries in the report month.',
    'प्रतिवेदन माह में अतिथि आगंतुक प्रविष्टियाँ।',
    'Visitor records in month where category is guest-type.',
    'माह के आगंतुक अभिलेख जहाँ श्रेणी अतिथि प्रकार है।',
  );
  static const moduleVehicles = MetricCopy(
    'Vehicle entries',
    'वाहन प्रविष्टियाँ',
    'Visitor log rows that include a vehicle number in the month.',
    'माह की वे आगंतुक प्रविष्टियाँ जिनमें वाहन नंबर है।',
    'Month visitors with vehicle_number set.',
    'माह के आगंतुक जिनका vehicle_number भरा है।',
  );
  static const moduleDeliveries = MetricCopy(
    'Deliveries / service',
    'वितरण / सेवा',
    'Delivery or recurring service entries in the month.',
    'माह में वितरण या नियमित सेवा प्रविष्टियाँ।',
    'Visitors with category delivery or service in reportMonth.',
    'चुने गए माह में delivery या service श्रेणी वाले आगंतुक।',
  );
  static const moduleDonations = MetricCopy(
    'Donations',
    'दान',
    'Donation pledges and payments recorded for the month.',
    'माह के लिए दर्ज दान संकल्प और भुगतान।',
    'Count and sum from donation payment rows grouped by status.',
    'स्थिति अनुसार समूहित दान भुगतान पंक्तियों की गिनती और योग।',
  );

  // FINANCE_PERIOD_METRICS
  static const extraLedgerReceipt = MetricCopy(
    'Ledger-only inflows added',
    'केवल खाता-बही आवक जोड़ी गई',
    'Extra receipt amount from finance_entries in the period that are not backed by linked maintenance_payments — can inflate period totals.',
    'अवधि में finance_entries की अतिरिक्त रसीद राशि जो जुड़े रखरखाव भुगतानों से समर्थित नहीं है — अवधि योग बढ़ा सकती है।',
    'Sum of unlinked finance_entries (maintenance/corpus destinations) whose transaction month falls in the selected period range.',
    'अलग (unlinked) finance_entries (रखरखाव/कोष गंतव्य) का योग जिनका लेनदेन माह चुनी अवधि में है।',
  );
  static const cashInHand = MetricCopy(
    'Cash in hand (net)',
    'हाथ में नकद (नेट)',
    'Net cash movement during the period only.',
    'केवल अवधि के दौरान नकद का शुद्ध आवागमन।',
    'Cash receipts in period minus cash expenses in period.',
    'अवधि की नकद रसीदें घटा अवधि के नकद खर्च।',
  );
  static const cashInBank = MetricCopy(
    'Cash in bank (net)',
    'बैंक में राशि (नेट)',
    'Net bank/UPI movement during the period.',
    'अवधि के दौरान बैंक/यूपीआई का शुद्ध आवागमन।',
    'Bank-channel receipts in period minus bank-channel expenses in period.',
    'अवधि की बैंक-चैनल रसीदें घटा बैंक-चैनल खर्च।',
  );
  static const closingBalance = MetricCopy(
    'Closing cash + bank',
    'समापन नकद + बैंक',
    'Combined cash and bank position at period end (excludes other channels).',
    'अवधि के अंत में नकद और बैंक की संयुक्त स्थिति (अन्य चैनल शामिल नहीं)।',
    'Closing cash + closing bank from the cash flow statement.',
    'नकदी प्रवाह विवरण से समापन नकद + समापन बैंक।',
  );

  // SUM_INSIGHT_METRICS
  static const channelCash = MetricCopy(
    'Cash total',
    'नकद योग',
    'Sum of amounts on the cash payment channel in this grouped view.',
    'इस समूहित दृश्य में नकद भुगतान चैनल की राशियों का योग।',
    'Adds rows where payment_method normalizes to cash.',
    'वे पंक्तियाँ जोड़ता है जिनकी payment_method नकद मानी जाती है।',
  );
  static const channelBank = MetricCopy(
    'Bank / UPI total',
    'बैंक / यूपीआई योग',
    'Sum of amounts on bank, UPI, online, or card channels in this view.',
    'इस दृश्य में बैंक, यूपीआई, ऑनलाइन या कार्ड चैनल की राशियों का योग।',
    'Adds rows where payment_method normalizes to bank.',
    'वे पंक्तियाँ जोड़ता है जिनकी payment_method बैंक मानी जाती है।',
  );
  static const channelOther = MetricCopy(
    'Other channels total',
    'अन्य चैनल योग',
    'Sum on payment methods not classified as cash or bank.',
    'नकद या बैंक के अलावा भुगतान विधियों का योग।',
    'Adds rows where payment_method normalizes to other.',
    'वे पंक्तियाँ जोड़ता है जिनकी payment_method अन्य मानी जाती है।',
  );
  static const periodVerifiedReceipts = MetricCopy(
    'Verified collections (total)',
    'सत्यापित संग्रह (कुल)',
    'All verified maintenance receipts in the selected period, split by channel.',
    'चुनी अवधि की सभी सत्यापित रखरखाव रसीदें, चैनल अनुसार।',
    'Sum of verified maintenance_payments in the period range, plus ledger-only inflows when applicable.',
    'अवधि में सत्यापित maintenance_payments का योग, साथ में लागू होने पर केवल खाता-बही आवक।',
  );
  static const periodAllExpenses = MetricCopy(
    'All expenses (total)',
    'सभी खर्च (कुल)',
    'Total society payments (separate entry) in the selected period.',
    'चुनी अवधि में कुल सोसाइटी भुगतान (अलग प्रविष्टि)।',
    'Sum of separate_entry finance_entries in the period, by payment channel.',
    'अवधि में separate_entry finance_entries का योग, भुगतान चैनल अनुसार।',
  );
  static const periodReceiptHead = MetricCopy(
    'Receipt head total',
    'रसीद मद योग',
    'Inflow under this receipt head in the selected period.',
    'चुनी अवधि में इस रसीद मद के अंतर्गत आवक।',
    'Sum of verified maintenance payments and ledger-only inflows for this head, split by cash / bank / other.',
    'इस मद के सत्यापित रखरखाव भुगतान और केवल खाता-बही आवक का योग, नकद / बैंक / अन्य अनुसार।',
  );
  static const periodExpenseHead = MetricCopy(
    'Expense head total',
    'खर्च मद योग',
    'Outflow under this expense head in the selected period.',
    'चुनी अवधि में इस खर्च मद के अंतर्गत जावक।',
    'Sum of separate_entry entries for this head, split by cash / bank / other.',
    'इस मद की separate_entry प्रविष्टियों का योग, नकद / बैंक / अन्य अनुसार।',
  );

  // FINANCE_FLAT_REPORT_METRICS
  static const flatTotalReceipts = MetricCopy(
    'Total receipts',
    'कुल रसीदें',
    'Maintenance and verified payments attributed to flats in the report period.',
    'प्रतिवेदन अवधि में फ्लैटों से जुड़े रखरखाव और सत्यापित भुगतान।',
    'Sum of maintenance_paid per flat in the flat report range.',
    'फ्लैट प्रतिवेदन अवधि में प्रति फ्लैट maintenance_paid का योग।',
  );
  static const flatExpenseShare = MetricCopy(
    'Total expense share',
    'कुल खर्च हिस्सा',
    'Each flat’s share of event/function (and group) expenses in the period.',
    'अवधि में आयोजन/समारोह (और समूह) खर्चों में प्रत्येक फ्लैट का हिस्सा।',
    'Sum of expense_share from expense_splits in range.',
    'अवधि में expense_splits से expense_share का योग।',
  );
  static const flatSettled = MetricCopy(
    'Settled',
    'निपटाया गया',
    'Portion of expense shares already marked settled between flats.',
    'खर्च हिस्सों का वह भाग जो फ्लैटों के बीच निपटाया जा चुका है।',
    'Sum of settled_amount per flat.',
    'प्रति फ्लैट settled_amount का योग।',
  );
  static const flatUnsettled = MetricCopy(
    'Unsettled',
    'बकाया',
    'Outstanding share flats still owe each other or the pool.',
    'वह बकाया हिस्सा जो फ्लैट एक-दूसरे या पूल को देय हैं।',
    'Sum of unsettled_amount per flat.',
    'प्रति फ्लैट unsettled_amount का योग।',
  );
}
