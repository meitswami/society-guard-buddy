import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_repository.dart';
import '../data/query_helpers.dart';
import '../logic/cash_bank_channel.dart';
import '../logic/contribution_rows.dart';
import '../logic/finance_dates.dart';
import '../logic/js_compat.dart';
import '../widgets/cash_bank_breakdown.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';

/// Read-only "Events & food — reference only" block of Finance → Receipts
/// (`FinanceManager` + `useFinanceEventReference`). Exposed for the FINANCE module.
class FinanceEventReferencePanel extends StatefulWidget {
  const FinanceEventReferencePanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<FinanceEventReferencePanel> createState() => _FinanceEventReferencePanelState();
}

class _FinanceEventReferencePanelState extends State<FinanceEventReferencePanel> {
  static const _repo = EventsRepository();
  late Future<({List<EventContributionRef> contributions, List<FinanceFoodRefRow> foodExpenses})> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchFinanceEventReference(widget.societyId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return EvColumn(
      spacing: 12,
      children: [
        EvSectionHeading(icon: Icons.calendar_month, color: t.accent, title: context.ev('fer.title')),
        EvHint(context.ev('fer.hint')),
        FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Padding(padding: const EdgeInsets.all(16), child: Center(child: EvHint(context.ev('efr.loading'), size: 12)));
            }
            if (snap.hasError) {
              return ErrorView(
                message: supabaseErrorMessage(snap.error!),
                onRetry: () => setState(() => _future = _repo.fetchFinanceEventReference(widget.societyId)),
              );
            }
            final contribs = snap.data!.contributions;
            final food = snap.data!.foodExpenses;
            final words = contribWords(context);
            Widget emptyBox(String text) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                  child: EvHint(text, size: 12, align: TextAlign.center),
                );
            return EvColumn(
              spacing: 12,
              children: [
                if (contribs.isNotEmpty || food.isNotEmpty)
                  CashBankBreakdown(
                    receipts: sumByChannel<EventContributionRef>(contribs, (c) => c.contribution.amount, (c) => c.contribution.paymentMethod),
                    payments: sumByChannel<FinanceFoodRefRow>(food, (e) => e.totalAmount, (e) => e.paymentMethod),
                    receiptLabel: context.ev('fer.eventContribs'),
                    paymentLabel: context.ev('efr.foodBills'),
                  ),
                EvTinyLabel(context.ev('efr.contribReceipts')),
                if (contribs.isEmpty)
                  emptyBox(context.ev('fer.noContribs'))
                else
                  for (final r in contribs)
                    CardSection(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EvHint(r.eventTitle),
                                Text(eventContribRefLabel(r.contribution, words),
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    EvHint(
                                      '${r.contribution.receiptBasis == 'non_flat' ? context.ev('fer.withoutFlat') : context.ev('fer.flatWise')}'
                                      '${(r.contribution.splitMode ?? '').isNotEmpty ? ' · ${r.contribution.splitMode!.replaceAll('_', ' ')}' : ''}',
                                    ),
                                    ChannelBadge(method: r.contribution.paymentMethod),
                                    if ((r.contribution.verifiedAt ?? '').isNotEmpty) EvHint('· ${fmtTimestampDate(r.contribution.verifiedAt)}'),
                                  ],
                                ),
                                if ((r.contribution.screenshotUrl ?? '').isNotEmpty)
                                  EvLink(context.ev('fer.viewProof'), onTap: () => openEvUrl(context, r.contribution.screenshotUrl!)),
                              ],
                            ),
                          ),
                          Text(rupeeLoc(r.contribution.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                EvTinyLabel(context.ev('fer.foodBills'), icon: Icons.restaurant),
                if (food.isEmpty)
                  emptyBox(context.ev('fer.noFood'))
                else
                  for (final ex in food)
                    CardSection(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EvHint(ex.eventTitle ?? ex.groupName),
                                Text(ex.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [EvHint(fmtIsoDateToDisplay(ex.expenseDate)), ChannelBadge(method: ex.paymentMethod)],
                                ),
                                if (ex.billScreenshotUrl != null)
                                  EvLink(context.ev('fer.viewBill'), onTap: () => openEvUrl(context, ex.billScreenshotUrl!)),
                              ],
                            ),
                          ),
                          Text(rupeeLoc(ex.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}
