import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../shared/directory/directory_widgets.dart';
import 'flat360_models.dart';
import 'flat360_service.dart';
import 'flat360_timeline.dart';

/// `₹${amount.toLocaleString('en-IN')}`.
String formatInr360(num amount) => '₹${Fmt.number(amount)}';

/// Port of web `src/components/Flat360ProfilePanel.tsx` (+ `useFlat360Profile`).
/// Embed inline (e.g. resident profile with `compact: true`) or open via `Flat360ProfileSheet`.
class Flat360ProfilePanel extends StatefulWidget {
  const Flat360ProfilePanel({super.key, required this.params, this.compact = false});

  final Flat360FetchParams params;
  final bool compact;

  @override
  State<Flat360ProfilePanel> createState() => _Flat360ProfilePanelState();
}

class _Flat360ProfilePanelState extends State<Flat360ProfilePanel> {
  static const _defaultDisplayLimit = 50;
  final _service = Flat360Service();
  Flat360Profile? _profile;
  bool _loading = false;
  String? _error;
  int _displayLimit = _defaultDisplayLimit;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant Flat360ProfilePanel old) {
    super.didUpdateWidget(old);
    final a = old.params, b = widget.params;
    if (a.societyId != b.societyId ||
        a.flatId != b.flatId ||
        a.flatNumber != b.flatNumber ||
        a.monthsBack != b.monthsBack ||
        a.includeVisitors != b.includeVisitors ||
        a.residentContext?.id != b.residentContext?.id) {
      _displayLimit = _defaultDisplayLimit;
      _reload();
    }
  }

  Future<void> _reload() async {
    if (widget.params.societyId.isEmpty || widget.params.flatId.isEmpty) {
      setState(() => _profile = null);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.fetch(widget.params);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().isEmpty ? 'Failed to load flat profile' : e.toString();
        _profile = null;
        _loading = false;
      });
    }
  }

  IconData _icon(Flat360TimelineKind k) => switch (k) {
        Flat360TimelineKind.payment => Icons.currency_rupee,
        Flat360TimelineKind.notification => Icons.notifications_none,
        Flat360TimelineKind.ticket => Icons.chat_bubble_outline,
        Flat360TimelineKind.meeting => Icons.description_outlined,
        Flat360TimelineKind.eventContribution => Icons.calendar_month_outlined,
        Flat360TimelineKind.visitor => Icons.person_outline,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading && _profile == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.muted, 0.2),
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Text(
          context.tr('Loading 360° profile…', '360° प्रोफ़ाइल लोड हो रही है…'),
          textAlign: TextAlign.center,
          style: AppText.caption(context),
        ),
      );
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.destructive, 0.05),
          border: Border.all(color: AppTokens.tint(t.destructive, 0.3)),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!, style: TextStyle(fontSize: 12, color: t.destructive)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _reload,
              child: Text(context.t('mobile.retry'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.primary)),
            ),
          ],
        ),
      );
    }
    final p = _profile;
    if (p == null) return const SizedBox.shrink();
    final s = p.summary;
    final visible = p.timeline.take(_displayLimit).toList();
    final remaining = p.timeline.length - _displayLimit;
    final hi = context.lang == AppLang.hi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Member 360°', 'सदस्य 360°'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground)),
                  Text(
                    '${context.tr('Flat', 'फ्लैट')} ${p.flatNumber}'
                    '${p.wing != null ? ' · ${context.tr('Wing', 'विंग')} ${p.wing}' : ''}'
                    '${p.floor != null ? ' · ${p.floor}' : ''}',
                    style: AppText.tiny(context),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.tr('Refresh', 'रीफ़्रेश'),
              onPressed: _loading ? null : _reload,
              icon: _loading
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary))
                  : Icon(Icons.refresh, size: 16, color: t.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StatGrid(spacing: 8, children: [
          _SummaryCard(
            label: context.tr('Paid (12 mo)', 'भुगतान (12 माह)'),
            value: formatInr360(s.verifiedPaid12m),
            sub: s.pendingCount > 0
                ? context.tr('${s.pendingCount} pending · ${formatInr360(s.pendingAmount)}', '${s.pendingCount} लंबित · ${formatInr360(s.pendingAmount)}')
                : context.tr('No pending dues', 'कोई बकाया नहीं'),
          ),
          _SummaryCard(
            label: context.tr('Meetings', 'बैठकें'),
            value: '${s.meetingsAttended}/${s.meetingsTotal}',
            sub: s.meetingsTotal > 0
                ? context.tr('${s.attendancePct}% attendance', '${s.attendancePct}% उपस्थिति')
                : context.tr('No meetings in period', 'इस अवधि में कोई बैठक नहीं'),
          ),
          _SummaryCard(
            label: context.tr('Parking', 'पार्किंग'),
            value: '${s.parkingSlots}',
            sub: s.parkingSlots == 1 ? context.tr('slot allocated', 'स्लॉट आवंटित') : context.tr('slots allocated', 'स्लॉट आवंटित'),
          ),
          _SummaryCard(
            label: context.tr('Open feedback', 'खुली प्रतिक्रिया'),
            value: '${s.openTickets}',
            sub: s.openTickets == 0 ? context.tr('No open tickets', 'कोई खुला टिकट नहीं') : context.tr('pending resolution', 'समाधान लंबित'),
          ),
        ]),
        if (!widget.compact && p.parking.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Box(children: [
            TinyLabel(context.tr('Parking', 'पार्किंग'), icon: Icons.local_parking_outlined),
            for (final slot in p.parking)
              Text.rich(TextSpan(children: [
                TextSpan(text: slot.spaceNumber, style: AppText.mono(context, size: 12, weight: FontWeight.w600)),
                TextSpan(text: ' · ${slot.spaceType}', style: TextStyle(fontSize: 12, color: t.mutedForeground)),
                if (slot.vehicleNumber != null) TextSpan(text: ' · ${slot.vehicleNumber}', style: TextStyle(fontSize: 12, color: t.mutedForeground)),
              ])),
          ]),
        ],
        if (!widget.compact && p.members.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Box(children: [
            TinyLabel(context.tr('Household (${p.members.length})', 'परिवार (${p.members.length})'), icon: Icons.groups_outlined),
            for (final m in p.members)
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: m.name, style: TextStyle(fontSize: 12, color: t.foreground)),
                  if (m.isPrimary) TextSpan(text: ' ★', style: TextStyle(fontSize: 12, color: t.primary)),
                  TextSpan(text: ' · ${m.relation}', style: TextStyle(fontSize: 12, color: t.mutedForeground)),
                  if (m.phone != null) TextSpan(text: ' · ${m.phone}', style: AppText.mono(context, size: 12, color: t.mutedForeground)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ]),
        ],
        const SizedBox(height: 12),
        TinyLabel(context.tr('Activity timeline', 'गतिविधि समयरेखा'), icon: Icons.how_to_reg_outlined),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              context.tr('No activity in the last 12 months', 'पिछले 12 महीनों में कोई गतिविधि नहीं'),
              textAlign: TextAlign.center,
              style: AppText.caption(context),
            ),
          )
        else
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.background,
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.1), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                      child: Icon(_icon(item.kind), size: 16, color: t.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.foreground)),
                                    Text(
                                      '${hi ? timelineKindLabelHi(item.kind) : timelineKindLabel(item.kind)}'
                                      '${(item.status ?? '').isNotEmpty ? ' · ${item.status}' : ''}',
                                      style: AppText.tiny(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item.amount != null && item.amount! > 0)
                                    Text(formatInr360(item.amount!),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground)),
                                  Text(Fmt.date(item.at).isNotEmpty ? Fmt.date(item.at) : item.at, style: AppText.tiny(context)),
                                ],
                              ),
                            ],
                          ),
                          if ((item.detail ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(item.detail!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.tiny(context)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (remaining > 0)
          TextButton(
            onPressed: () => setState(() => _displayLimit += 30),
            child: Text(
              context.tr('Load more activity ($remaining remaining)', 'और गतिविधि देखें ($remaining शेष)'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.primary),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.secondary, 0.3),
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TinyLabel(label),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.foreground)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: AppText.tiny(context))),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: context.tokens.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 6), children[i]]],
      ),
    );
  }
}
