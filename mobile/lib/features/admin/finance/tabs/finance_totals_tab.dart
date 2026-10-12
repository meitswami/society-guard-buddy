// Ports of FinanceTotalsTab (report period + export/share, send panel, inflow/outflow groups)
// and MonthlyOperatingFundPanel (operating fund & reserve transfers).

import 'package:flutter/material.dart';

import '../../../../core/export/export_kit.dart';
import '../../../../core/ui/ui.dart';
import '../../reports/widgets/finance_period_report_send_panel.dart';
import '../export/finance_exports.dart';
import '../export/finance_letterhead.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../logic/finance_ledger_display.dart';
import '../logic/finance_models.dart';
import '../logic/finance_period_report.dart';
import '../logic/finance_totals_breakdown.dart';
import '../logic/operating_reserve_fund.dart';
import '../state/finance_controller.dart';
import '../widgets/cash_bank_breakdown.dart';
import '../widgets/fin_kit.dart';
import '../widgets/finance_metric_copy.dart';

class FinanceTotalsTab extends StatefulWidget {
  const FinanceTotalsTab({super.key, required this.c});

  final FinanceController c;

  @override
  State<FinanceTotalsTab> createState() => _FinanceTotalsTabState();
}

class _FinanceTotalsTabState extends State<FinanceTotalsTab> {
  FinanceController get c => widget.c;
  bool _monthly = true;
  String _from = defaultFinancePeriodFrom();
  String _to = defaultFinancePeriodTo();
  List<OpeningBalanceAnchor> _anchors = const [];

  @override
  void initState() {
    super.initState();
    c.repo.fetchOpeningAnchors(c.societyId).then((a) {
      if (mounted) setState(() => _anchors = a);
    });
  }

  ({String from, String to, String label}) _period() {
    if (_monthly) {
      final r = financeReportingMonthRange(c.totalsMonth);
      return (from: r.from, to: r.to, label: isoMonthToDisplay(c.totalsMonth));
    }
    return (from: _from, to: _to, label: '${isoDateToDisplay(_from)} – ${isoDateToDisplay(_to)}');
  }

  Future<void> _download(FinExportFormat fmt, FinancePeriodReportResult report, ({String from, String to, String label}) p) async {
    final ctx = await resolveLetterheadContext(c.societyId);
    if (!mounted) return;
    if (ctx.warning != null && fmt == FinExportFormat.pdf) {
      AppFeedback.toast(context, context.tr(ctx.warning!, 'सोसाइटी का आधिकारिक लेटरहेड सेट नहीं है।'), tone: BadgeTone.warning);
    }
    final file = await buildFinancePeriodReport(
      fmt,
      report: report,
      societyName: c.data.societyName.isEmpty ? 'Society' : c.data.societyName,
      periodFrom: p.from,
      periodTo: p.to,
      filenameBase: 'finance-totals-${p.label.replaceAll(RegExp(r'\s+'), '-')}',
      context: ctx,
    );
    await shareFinanceFile(file);
    if (mounted) AppFeedback.toast(context, '${fmt.name.toUpperCase()} ${context.tr('ready', 'तैयार')}', tone: BadgeTone.success);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final t = context.tokens;
        final m = FinMetrics.of(context);
        final d = c.data;
        final derived = c.derived;
        final p = _period();
        final invalid = p.from.compareTo(p.to) > 0;
        final report = invalid
            ? null
            : computeFinancePeriodReport(
                periodFrom: p.from,
                periodTo: p.to,
                payments: d.payments,
                ledgerEntries: derived.societyLedgerEntries,
                expenseCategoryById: d.expenseCategoryById,
                openingBalanceAnchors: _anchors,
              );
        final totals = FinanceTotalsBreakdown.compute(
          ledgerEntries: d.ledgerEntries,
          societyLedgerEntries: derived.societyLedgerEntries,
          totalsMonth: c.totalsMonth,
          expenseCategoryById: d.expenseCategoryById,
        );
        final societyName = d.societyName.isEmpty ? 'Society' : d.societyName;
        final net = totals.totalsMonthNet - totals.totalsMonthOutflow;
        String ch(ChannelTotals c) =>
            '${context.fin('fin.cash')} ${inrLocale(c.cash)} · ${context.tr('Bank', 'बैंक')} ${inrLocale(c.bank)}'
            '${c.other > 0 ? ' · ${context.fin('fin.other')} ${inrLocale(c.other)}' : ''}';
        String entries(int n) => n == 1 ? context.tr('1 entry', '1 प्रविष्टि') : context.tr('$n entries', '$n प्रविष्टियाँ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinTintBox(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('Report period', 'रिपोर्ट अवधि'), style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
                  Text(context.tr('Download or share monthly figures as a finance period report', 'मासिक आँकड़े वित्त अवधि रिपोर्ट के रूप में डाउनलोड या साझा करें'),
                      style: AppText.tiny(context)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PillChoice(
                        label: context.tr('Monthly', 'मासिक'),
                        icon: Icons.calendar_today_outlined,
                        selected: _monthly,
                        onTap: () => setState(() => _monthly = true),
                      ),
                      PillChoice(
                        label: context.tr('Date range', 'तिथि सीमा'),
                        icon: Icons.date_range_outlined,
                        selected: !_monthly,
                        onTap: () => setState(() => _monthly = false),
                      ),
                      FinExportMenuButton(
                        label: context.tr('Download report', 'रिपोर्ट डाउनलोड करें'),
                        enabled: report != null,
                        onExport: (fmt) {
                          if (report == null) {
                            AppFeedback.toast(context, context.tr('End date must be on or after start date', 'अंतिम तिथि आरंभ तिथि के बाद हो'),
                                tone: BadgeTone.alert);
                            return;
                          }
                          _download(fmt, report, p);
                        },
                      ),
                      if (report != null)
                        FinShareButton(
                          label: context.tr('Share report', 'रिपोर्ट साझा करें'),
                          onShare: () async {
                            final ctx = await resolveLetterheadContext(c.societyId);
                            final bytes = await buildFinancePeriodReportPdf(
                              report: report,
                              societyName: societyName,
                              periodFrom: p.from,
                              periodTo: p.to,
                              context: ctx,
                            );
                            await ExportKit.sharePdf(bytes, 'finance-totals-${p.label.replaceAll(RegExp(r'\s+'), '-')}.pdf',
                                text: '$societyName — ${p.label} finance totals report');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_monthly) ...[
                    FinMonthField(
                      label: context.tr('Reporting month', 'रिपोर्टिंग माह'),
                      value: c.totalsMonth,
                      onChanged: c.setTotalsMonth,
                    ),
                    FinHint('${context.tr('Scope', 'दायरा')}: ${isoDateToDisplay(p.from)} – ${isoDateToDisplay(p.to)}'),
                  ] else
                    Row(
                      children: [
                        Expanded(child: FinDateField(label: context.tr('From', 'से'), value: _from, onChanged: (v) => setState(() => _from = v))),
                        const SizedBox(width: 8),
                        Expanded(child: FinDateField(label: context.tr('To', 'तक'), value: _to, onChanged: (v) => setState(() => _to = v))),
                      ],
                    ),
                  if (invalid)
                    FinHint(context.tr('End date must be on or after start date.', 'अंतिम तिथि आरंभ तिथि के बाद हो।'), color: t.destructive),
                  if (report != null)
                    FinHint(context.tr(
                      '${p.label} — receipts ${inrLocale(report.totalReceipts)} · expenses ${inrLocale(report.totalExpenses)} · net ${inrLocale(report.totalBalance)}',
                      '${p.label} — रसीदें ${inrLocale(report.totalReceipts)} · व्यय ${inrLocale(report.totalExpenses)} · शुद्ध ${inrLocale(report.totalBalance)}',
                    )),
                ],
              ),
            ),
            if (report != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FinancePeriodReportSendPanel(societyId: c.societyId, societyName: societyName, adminName: c.adminName),
              ),
            MonthlyOperatingFundPanel(c: c),
            CashBankBreakdown(
              receipts: totals.totalsMonthReceiptChannels,
              payments: totals.totalsMonthPaymentChannels,
              receiptLabel: context.tr('Ledger inflows (${c.totalsMonth})', 'खाता आवक (${c.totalsMonth})'),
              paymentLabel: context.tr('Ledger outflows (${c.totalsMonth})', 'खाता जावक (${c.totalsMonth})'),
            ),
            const SizedBox(height: 16),
            _stat(context, m.inflow, inrLocale(totals.totalsMonthNet), t.success),
            _stat(context, m.groups, '${totals.totalsBreakdown.length}', null),
            _stat(context, m.flatUnits, '${totals.totalsBreakdown.fold<int>(0, (s, r) => s + r.flatUnits)}', null),
            const SizedBox(height: 8),
            if (totals.totalsBreakdown.isEmpty)
              EmptyView(
                message: context.tr(
                  'No ledger groups for ${c.totalsMonth}. Record receipts or outsider entries to populate totals.',
                  '${c.totalsMonth} के लिए कोई खाता समूह नहीं। कुल योग के लिए रसीदें या बाहरी प्रविष्टियाँ दर्ज करें।',
                ),
              )
            else
              for (final row in totals.totalsBreakdown)
                _groupCard(
                  context,
                  title: _cap(formatLedgerFieldLabel(row.mode)),
                  sub: '${_cap(formatLedgerFieldLabel(row.destination))} · ${entries(row.entries)}',
                  channels: ch(row.byChannel),
                  value: inrLocale(row.total),
                  units: row.flatUnits,
                  copy: (
                    '${formatLedgerFieldLabel(row.mode)} · ${formatLedgerFieldLabel(row.destination)}',
                    '${m.inflowGroup.$2} Mode: ${formatLedgerFieldLabel(row.mode)}; destination: ${formatLedgerFieldLabel(row.destination)}.',
                    '${m.inflowGroup.$3} This group: ${entries(row.entries)}, ${row.flatUnits} flat units.',
                  ),
                  color: null,
                ),
            const SizedBox(height: 24),
            _stat(context, m.outflow, inrLocale(totals.totalsMonthOutflow), t.destructive),
            _stat(context, m.expenseHeads, '${totals.totalsOutflowBreakdown.length}', null),
            _stat(context, m.netInflowOutflow, inrLocale(net), net >= 0 ? t.success : t.destructive),
            const SizedBox(height: 8),
            if (totals.totalsOutflowBreakdown.isEmpty)
              EmptyView(
                message: context.tr(
                  'No outflow entries for ${c.totalsMonth}. Record separate entries (expenses / payments made) to populate this section.',
                  '${c.totalsMonth} के लिए कोई जावक प्रविष्टि नहीं। यह भाग भरने हेतु अलग प्रविष्टियाँ (व्यय / किए गए भुगतान) दर्ज करें।',
                ),
              )
            else
              for (final row in totals.totalsOutflowBreakdown)
                _groupCard(
                  context,
                  title: row.head,
                  sub: entries(row.entries),
                  channels: ch(row.byChannel),
                  value: inrLocale(row.total),
                  units: row.flatUnits,
                  copy: (row.head, '${m.outflowHead.$2} Head: ${row.head}.', '${m.outflowHead.$3} This head: ${entries(row.entries)}.'),
                  color: t.destructive,
                ),
          ],
        );
      },
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Widget _stat(BuildContext context, FinCopy copy, String value, Color? color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DescriptiveStatCard(
          compact: true,
          title: copy.$1,
          description: copy.$2,
          howCalculated: copy.$3,
          value: value,
          valueColor: color,
        ),
      );

  Widget _groupCard(
    BuildContext context, {
    required String title,
    required String sub,
    required String channels,
    required String value,
    required int units,
    required FinCopy copy,
    required Color? color,
  }) =>
      CardSection(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.sectionTitle(context)),
                  Text(sub, style: AppText.tiny(context)),
                  const SizedBox(height: 2),
                  Text(channels, style: AppText.tiny(context)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FinInfoValue(
                  title: copy.$1,
                  value: value,
                  description: copy.$2,
                  howCalculated: copy.$3,
                  color: color,
                  style: AppText.mono(context, size: 13, weight: FontWeight.w700),
                ),
                Text(context.tr('$units flat units', '$units फ्लैट इकाइयाँ'), style: AppText.tiny(context)),
              ],
            ),
          ],
        ),
      );
}

/// Web `MonthlyOperatingFundPanel`.
class MonthlyOperatingFundPanel extends StatefulWidget {
  const MonthlyOperatingFundPanel({super.key, required this.c});

  final FinanceController c;

  @override
  State<MonthlyOperatingFundPanel> createState() => _MonthlyOperatingFundPanelState();
}

class _MonthlyOperatingFundPanelState extends State<MonthlyOperatingFundPanel> {
  FinanceController get c => widget.c;
  List<ReserveTransfer> _transfers = const [];
  bool _loading = false;
  String? _show; // 'surplus' | 'draw'
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String _direction = kOperatingToReserve;
  bool _saving = false;
  String _loadedFor = '';

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await c.repo.fetchReserveTransfers(c.societyId);
    if (!mounted) return;
    setState(() {
      _transfers = rows;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadedFor = c.totalsMonth;
    _load();
  }

  Future<void> _save(double rawSurplus, double reserveBalance) async {
    final amount = jsNumberSafe(_amount.text);
    if (amount <= 0) {
      AppFeedback.toast(context, context.tr('Enter a valid amount', 'मान्य राशि दर्ज करें'), tone: BadgeTone.alert);
      return;
    }
    if (_direction != kOperatingToReserve && amount > reserveBalance) {
      AppFeedback.toast(context, context.tr('Amount exceeds reserve fund balance', 'राशि आरक्षित निधि शेष से अधिक है'), tone: BadgeTone.alert);
      return;
    }
    if (_direction == kOperatingToReserve && amount > (rawSurplus > 0 ? rawSurplus : 0)) {
      AppFeedback.toast(context, context.tr('Amount exceeds this month’s unallocated surplus', 'राशि इस माह के अनावंटित अधिशेष से अधिक है'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _saving = true);
    try {
      await c.repo.insertReserveTransfer(
        societyId: c.societyId,
        entryMonth: c.totalsMonth,
        amount: amount,
        direction: _direction,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        adminName: c.adminName,
      );
      if (!mounted) return;
      AppFeedback.toast(
        context,
        context.lang == AppLang.hi ? kReserveTransferLabelsHi[_direction]! : kReserveTransferLabels[_direction]!,
        tone: BadgeTone.success,
      );
      setState(() {
        _show = null;
        _amount.clear();
        _notes.clear();
        _direction = kOperatingToReserve;
      });
      await _load();
      await c.invalidateAll();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, e.toString(), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(String dir) => context.lang == AppLang.hi ? (kReserveTransferLabelsHi[dir] ?? dir) : (kReserveTransferLabels[dir] ?? dir);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loadedFor != c.totalsMonth) {
      _loadedFor = c.totalsMonth;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final d = c.data;
    final month = c.totalsMonth;
    final titles = c.derived.chargeTitleById;
    final operatingIn = monthlyOperatingInflow(month, d.payments, d.charges, titles);
    bool isOutflow(FinanceLedgerRow e) {
      if (e.destination != 'separate_entry') return false;
      final cat = e.expenseId != null ? d.expenseCategoryById[e.expenseId] : null;
      return cat != 'food';
    }

    final operatingOut = monthlyOperatingOutflow(month, c.derived.societyLedgerEntries, isOutflow);
    final monthTransfers = transfersForMonth(_transfers, month);
    final transferNet = netTransferEffectForMonth(_transfers, month);
    final rawSurplus = operatingIn - operatingOut;
    final closing = rawSurplus + transferNet;
    final reserve = reserveFundBalance(d.ledgerEntries, _transfers);

    Widget tile(String label, String value, Color color, {IconData? icon}) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTokens.tint(t.background, 0.8), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 11, color: t.mutedForeground), const SizedBox(width: 2)],
                    Flexible(child: Text(label.toUpperCase(), textAlign: TextAlign.center, style: AppText.tiny(context))),
                  ],
                ),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        );

    return FinTintBox(
      color: t.primary,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => AppFeedback.info(
              context,
              title: context.tr('Monthly operating fund & reserve', 'मासिक संचालन निधि व आरक्षित'),
              description: context.tr(
                "Monthly maintenance from members is a temporary fund for that month's operational expenses (unless a receipt type is linked to a specific head). Surplus can move to the reserve fund for emergencies, fixed investments, or to cover a future month's shortfall.",
                'सदस्यों का मासिक रखरखाव उस माह के संचालन खर्च के लिए अस्थायी निधि है (जब तक रसीद प्रकार किसी विशेष शीर्ष से न जुड़ा हो)। अधिशेष आपात, स्थायी निवेश या भविष्य की कमी के लिए आरक्षित निधि में जा सकता है।',
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.1), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                  child: Icon(Icons.account_balance_wallet_outlined, size: 16, color: t.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(context.tr('Monthly operating fund & reserve', 'मासिक संचालन निधि व आरक्षित'), style: AppText.sectionTitle(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: FinMonthField(label: context.tr('Reporting month', 'रिपोर्टिंग माह'), value: month, onChanged: c.setTotalsMonth)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FinMiniButton(label: 'Feb 2026', onTap: () => c.setTotalsMonth(kFinanceReportingEarliestMonth)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FinSummaryLine(
            label: '${context.tr('Operating month', 'संचालन माह')}: ${isoMonthToDisplay(month)}',
            description: context.tr(
              'Collections ${inrLocale(operatingIn)} · Operational expenses ${inrLocale(operatingOut)} · Reserve balance ${inrLocale(reserve)}',
              'संग्रह ${inrLocale(operatingIn)} · संचालन व्यय ${inrLocale(operatingOut)} · आरक्षित शेष ${inrLocale(reserve)}',
            ),
            howCalculated: context.tr(
              'Operating inflow = verified monthly maintenance receipts (excludes one-time / head-linked charges). Outflow = society payment expenses for the month. Reserve = corpus receipts + surplus transfers − reserve draws.',
              'संचालन आवक = सत्यापित मासिक रखरखाव रसीदें (एक बार / शीर्ष-जुड़े शुल्क छोड़कर)। जावक = माह के सोसाइटी भुगतान व्यय। आरक्षित = कॉर्पस रसीदें + अधिशेष स्थानांतरण − आरक्षित निकासी।',
            ),
          ),
          Row(children: [
            tile(context.tr('Collected', 'संग्रहीत'), inrLocale(operatingIn), t.success),
            tile(context.tr('Operational spent', 'संचालन खर्च'), inrLocale(operatingOut), t.warning),
          ]),
          Row(children: [
            tile(context.tr('Month balance', 'माह शेष'), inrLocale(closing), closing >= 0 ? t.foreground : t.destructive),
            tile(context.tr('Reserve', 'आरक्षित'), inrLocale(reserve), t.accent, icon: Icons.savings_outlined),
          ]),
          if (rawSurplus > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FinMiniButton(
                  icon: Icons.swap_horiz,
                  color: t.primary,
                  label: context.tr('Transfer surplus to reserve', 'अधिशेष आरक्षित में भेजें'),
                  onTap: () => setState(() {
                    _show = 'surplus';
                    _direction = kOperatingToReserve;
                    _amount.text = numToInput((rawSurplus + transferNet) > 0 ? rawSurplus + transferNet : 0);
                    _notes.clear();
                  }),
                ),
              ),
            ),
          if (rawSurplus + transferNet < 0)
            FinTintBox(
              color: t.destructive,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: t.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            'Shortfall ${inrLocale((rawSurplus + transferNet).abs())} — collections did not cover operational expenses',
                            'कमी ${inrLocale((rawSurplus + transferNet).abs())} — संग्रह से संचालन खर्च पूरा नहीं हुआ',
                          ),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.destructive),
                        ),
                        FinHint(context.tr(
                          'Draw from reserve, member advance (head reconciliation), or use next month’s collections.',
                          'आरक्षित से निकालें, सदस्य अग्रिम (शीर्ष मिलान) लें, या अगले माह का संग्रह उपयोग करें।',
                        )),
                      ],
                    ),
                  ),
                  if (reserve > 0)
                    FinMiniButton(
                      color: t.primary,
                      label: context.tr('Draw reserve', 'आरक्षित से निकालें'),
                      onTap: () => setState(() {
                        _show = 'draw';
                        _direction = kReserveToOperating;
                        final need = (rawSurplus + transferNet).abs();
                        _amount.text = numToInput(reserve < need ? reserve : need);
                        _notes.clear();
                      }),
                    ),
                ],
              ),
            ),
          if (_show != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.background,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _show == 'surplus'
                        ? context.tr('Transfer surplus to reserve fund', 'अधिशेष आरक्षित निधि में भेजें')
                        : context.tr('Draw from reserve fund', 'आरक्षित निधि से निकालें'),
                    style: AppText.bodyMedium(context).copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _amount,
                    hint: context.tr('Amount (₹)', 'राशि (₹)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: kAmountFormatters,
                  ),
                  if (_show == 'draw') ...[
                    const SizedBox(height: 8),
                    AppDropdown<String>(
                      items: const [kReserveToOperating, kReserveToFixed, kReserveToEmergency],
                      value: _direction,
                      labelOf: _label,
                      onChanged: (v) => setState(() => _direction = v ?? kReserveToOperating),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AppTextField(controller: _notes, caps: false, hint: context.tr('Notes (optional)', 'टिप्पणी (वैकल्पिक)')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: _saving ? context.tr('Saving…', 'सहेजा जा रहा है…') : context.tr('Confirm', 'पुष्टि करें'),
                          loading: _saving,
                          onPressed: () => _save(rawSurplus, reserve),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: AppButton.secondary(label: context.fin('fin.cancel'), onPressed: () => setState(() => _show = null))),
                    ],
                  ),
                ],
              ),
            ),
          if (monthTransfers.isNotEmpty) ...[
            const SizedBox(height: 12),
            FinMicroLabel(context.tr('Movements this month', 'इस माह की गतिविधि')),
            for (final tr in monthTransfers)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTokens.tint(t.background, 0.6), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    Expanded(child: Text(_label(tr.direction), style: AppText.body(context).copyWith(fontSize: 12))),
                    Text(inrLocale(tr.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
          if (_loading) FinHint(context.tr('Updating…', 'अपडेट हो रहा है…'), padding: const EdgeInsets.only(top: 8)),
        ],
      ),
    );
  }
}

/// JS `Number(x)` with NaN → 0.
double jsNumberSafe(String raw) {
  final v = double.tryParse(raw.trim());
  return v == null || v.isNaN ? 0 : v;
}
