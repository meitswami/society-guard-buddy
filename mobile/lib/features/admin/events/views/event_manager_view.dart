import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_models.dart';
import '../data/events_repository.dart';
import '../data/events_storage.dart';
import '../data/query_helpers.dart';
import '../logic/contribution_rows.dart';
import '../logic/finance_dates.dart';
import '../logic/flat_options.dart';
import '../logic/js_compat.dart';
import '../logic/split_math.dart';
import '../widgets/ev_fields.dart';
import '../widgets/ev_i18n.dart';
import '../widgets/ev_ui.dart';
import '../widgets/flat_multi_select.dart';
import 'contribution_edit_sheet.dart';

/// Port of `src/components/EventManager.tsx` (calendar events + contribution receipts).
class EventManagerView extends StatefulWidget {
  const EventManagerView({
    super.key,
    required this.societyId,
    required this.adminName,
    this.embedded = false,
    this.onRecordsChanged,
    this.hub,
    this.query = '',
  });

  final String societyId;
  final String adminName;
  final bool embedded;
  final VoidCallback? onRecordsChanged;
  final EvReloadHub? hub;

  /// Client-side filter (admin global search → `ctx.initialQuery`).
  final String query;

  @override
  State<EventManagerView> createState() => _EventManagerViewState();
}

class _EventManagerViewState extends State<EventManagerView> {
  static const _repo = EventsRepository();

  EventManagerData _data = EventManagerData.empty;
  bool _loading = true;
  Object? _error;
  MemberIndex _members = MemberIndex(const []);

  bool _includeVacant = false;
  bool _showForm = false;
  int _eventFormVersion = 0;
  final Map<String, String> _ef = {};
  bool _savingEvent = false;

  String? _showContrib;
  int _contribVersion = 0;
  ReceiptBasis _basis = ReceiptBasis.flat;
  FlatCollectMode _mode = FlatCollectMode.samePerFlat;
  List<String> _selectedFlats = const [];
  String _amount = '';
  String _paymentMethod = 'cash';
  String _screenshotUrl = '';
  Map<String, String> _perFlat = {};
  String _headcountTotal = '';
  String _lumpTotal = '';
  String _nonFlatLabel = '';
  String _adultWeight = '1';
  String _childWeight = '0.5';
  PickedAttachment? _receiptFile;
  bool _uploading = false;
  String? _remindingEventId;

  @override
  void initState() {
    super.initState();
    widget.hub?.register(this, _loadAll);
    _loadAll();
  }

  @override
  void dispose() {
    widget.hub?.unregister(this);
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final d = await _repo.loadEventManager(widget.societyId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _members = MemberIndex(d.flats.members);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_loading) {
        setState(() {
          _loading = false;
          _error = e;
        });
      } else {
        AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  void _changed() {
    widget.onRecordsChanged?.call();
  }

  List<FlatLite> get _flats => _data.flats.flats;
  List<FlatLite> get _targetFlats => _includeVacant ? _flats : _flats.where((f) => f.isOccupied == true).toList();
  List<String> get _contribTargets => contributionTargetFlats(_selectedFlats, _targetFlats);

  FlatLite? _flatOf(String fn) {
    for (final f in _flats) {
      if (f.flatNumber == fn) return f;
    }
    return null;
  }

  // ------------------------------------------------------------------ events

  Future<void> _addEvent() async {
    final title = _ef['title'] ?? '';
    final date = _ef['event_date'] ?? '';
    if (widget.societyId.isEmpty) return;
    if (title.isEmpty || date.isEmpty) {
      AppFeedback.toast(context, context.ev('evm.titleDateRequired'), tone: BadgeTone.alert);
      return;
    }
    final description = _ef['description'] ?? '';
    final time = _ef['event_time'] ?? '';
    final location = _ef['location'] ?? '';
    final contribution = _ef['contribution_amount'] ?? '';
    setState(() => _savingEvent = true);
    try {
      await _repo.insertEvent(
        societyId: widget.societyId,
        adminName: widget.adminName,
        title: title,
        description: description.isEmpty ? null : description,
        eventDate: date,
        eventTime: time.isEmpty ? null : time,
        location: location.isEmpty ? null : location,
        contributionAmount: jsNumberOr(contribution, 0),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _savingEvent = false);
        AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _savingEvent = false;
      _ef.clear();
      _eventFormVersion++;
      _showForm = false;
    });
    AppFeedback.toast(context, context.ev('evm.eventCreated'), tone: BadgeTone.success);
    _loadAll();

    // Notification text stays identical to the web (stored data, English).
    final nTitle = 'New Event: $title';
    final message = '$title on ${fmtIsoDateToDisplay(date)}${location.isNotEmpty ? ' at $location' : ''}. '
        '${contribution.isNotEmpty ? 'Contribution: ₹$contribution' : ''}';
    try {
      await _repo.announceEvent(societyId: widget.societyId, adminName: widget.adminName, title: nTitle, message: message);
    } catch (_) {
      // Web ignores the notification result.
    }
  }

  // ----------------------------------------------------------- contributions

  void _resetContribForm() {
    _selectedFlats = const [];
    _amount = '';
    _paymentMethod = 'cash';
    _screenshotUrl = '';
    _basis = ReceiptBasis.flat;
    _mode = FlatCollectMode.samePerFlat;
    _perFlat = {};
    _headcountTotal = '';
    _lumpTotal = '';
    _nonFlatLabel = '';
    _receiptFile = null;
    _contribVersion++;
  }

  String _errorText(ContributionError e) => context.ev('evm.err.${e.name}');

  Future<void> _recordContribution(String eventId) async {
    if (_basis == ReceiptBasis.flat && _mode == FlatCollectMode.samePerFlat && _selectedFlats.isEmpty) {
      AppFeedback.toast(context, context.ev('evm.err.selectFlat'), tone: BadgeTone.alert);
      return;
    }
    // Validate first (the web uploads first; same messages, no orphan upload on mobile).
    final verifiedAt = DateTime.now().toUtc().toIso8601String();
    ContributionBuildResult build(String? shot) => buildContributionRows(
          eventId: eventId,
          screenshotUrl: shot,
          verifiedAt: verifiedAt,
          verifiedBy: widget.adminName,
          batchId: const Uuid().v4(),
          basis: _basis,
          mode: _mode,
          selectedFlats: _selectedFlats,
          targetFlatNumbers: _contribTargets,
          paymentMethod: _paymentMethod,
          amountText: _amount,
          perFlatAmounts: _perFlat,
          headcountTotalText: _headcountTotal,
          lumpTotalText: _lumpTotal,
          nonFlatLabel: _nonFlatLabel,
          adultWeightText: _adultWeight,
          childWeightText: _childWeight,
          flats: _flats,
          members: _data.flats.members,
          primaryByFlatId: _data.flats.primaryByFlatId,
        );
    final check = build(null);
    if (check.error != null) {
      AppFeedback.toast(context, _errorText(check.error!), tone: BadgeTone.alert);
      return;
    }

    String? screenshot = _screenshotUrl.trim().isEmpty ? null : _screenshotUrl.trim();
    final file = _receiptFile;
    if (file != null) {
      if (!file.isImage && !file.isPdf) {
        AppFeedback.toast(context, context.ev('evm.receiptType'), tone: BadgeTone.alert);
        return;
      }
      if (file.size > EventsStorage.maxBytes) {
        AppFeedback.toast(context, context.ev('evm.receiptSize'), tone: BadgeTone.alert);
        return;
      }
      setState(() => _uploading = true);
      try {
        screenshot = await EventsStorage.uploadContributionReceipt(file);
      } catch (e) {
        if (mounted) {
          setState(() => _uploading = false);
          AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    final rows = build(screenshot).rows;
    try {
      await _repo.insertContributions(rows);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      return;
    }
    if (!mounted) return;
    setState(() {
      _resetContribForm();
      _showContrib = null;
    });
    AppFeedback.toast(
      context,
      rows.length > 1 ? context.ev('evm.contribsRecorded', {'n': rows.length}) : context.ev('evm.contribRecorded'),
      tone: BadgeTone.success,
    );
    await _loadAll();
    _changed();
  }

  Future<void> _sendReminders(EventRow ev) async {
    final paid = [
      for (final c in _data.contributions)
        if (c.eventId == ev.id && c.receiptBasis != 'non_flat' && c.hasFlat) c.flatNumber!,
    ];
    final unpaid = [for (final f in _targetFlats) if (!paid.contains(f.flatNumber)) f.flatNumber];
    if (unpaid.isEmpty) {
      AppFeedback.toast(context, context.ev('evm.allPaid'), tone: BadgeTone.success);
      return;
    }
    setState(() => _remindingEventId = ev.id);
    try {
      await _repo.sendContributionReminders(
        societyId: widget.societyId,
        adminName: widget.adminName,
        event: ev,
        unpaidFlatNumbers: unpaid,
        contributionText: jsNumStr(ev.contributionAmount),
      );
      if (mounted) AppFeedback.toast(context, context.ev('evm.remindersSent', {'n': unpaid.length}), tone: BadgeTone.success);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _remindingEventId = null);
    }
  }

  Future<void> _editContribution(String id) async {
    final saved = await ContributionEditSheet.show(context, contributionId: id, societyId: widget.societyId, adminName: widget.adminName);
    if (saved == true && mounted) {
      await _loadAll();
      _changed();
    }
  }

  bool _matches(EventRow ev) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return ev.title.toLowerCase().contains(q) ||
        (ev.description ?? '').toLowerCase().contains(q) ||
        (ev.location ?? '').toLowerCase().contains(q) ||
        fmtIsoDateToDisplay(ev.eventDate).contains(q);
  }

  // ---------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(
        message: supabaseErrorMessage(_error!),
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _loadAll();
        },
      );
    }
    final events = _data.events.where(_matches).toList();
    return EvColumn(
      spacing: 12,
      children: [
        if (!widget.embedded)
          PageHeader(icon: Icons.calendar_month, iconColor: t.accent, title: context.ev('evm.standaloneTitle'), bottomSpacing: 4),
        CardSection(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.ev('evm.contribBase'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    EvHint(
                      _includeVacant
                          ? context.ev('evm.usingAll', {'n': _flats.length})
                          : context.ev('evm.usingOccupied', {'n': _targetFlats.length}),
                    ),
                  ],
                ),
              ),
              EvOutlineButton(
                label: _includeVacant ? context.ev('evc.vacantOn') : context.ev('evc.vacantOff'),
                onTap: () => setState(() => _includeVacant = !_includeVacant),
              ),
            ],
          ),
        ),
        AppButton(icon: Icons.add, label: context.ev('evm.createEvent'), onPressed: () => setState(() => _showForm = !_showForm)),
        if (_showForm) _eventForm(context),
        if (_data.events.isEmpty)
          EmptyView(icon: Icons.event_busy, message: context.ev('evm.noEvents'))
        else if (events.isEmpty)
          EmptyView(message: context.ev('evc.noMatch', {'q': widget.query.trim()})),
        for (final ev in events) _eventCard(context, ev),
      ],
    );
  }

  Widget _field(String key, String hint, {TextInputType? keyboard, int maxLines = 1}) {
    return AppTextField(
      key: ValueKey('ef-$key-$_eventFormVersion'),
      hint: hint,
      initialValue: _ef[key] ?? '',
      keyboardType: keyboard,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : null,
      onChanged: (v) => _ef[key] = v,
    );
  }

  Widget _eventForm(BuildContext context) {
    return CardSection(
      child: EvColumn(
        spacing: 12,
        children: [
          _field('title', context.ev('evm.f.title')),
          _field('description', context.ev('evm.f.description'), maxLines: 3),
          EvTwoCol(
            left: EvDateField(
              value: _ef['event_date'] ?? '',
              onChanged: (v) => setState(() => _ef['event_date'] = v),
            ),
            right: EvTimeField(
              value: _ef['event_time'] ?? '',
              onChanged: (v) => setState(() => _ef['event_time'] = v),
            ),
          ),
          _field('location', context.ev('evm.f.location')),
          _field('contribution_amount', context.ev('evm.f.contribution'), keyboard: const TextInputType.numberWithOptions(decimal: true)),
          AppButton(label: context.ev('evm.createEvent'), loading: _savingEvent, onPressed: _addEvent),
        ],
      ),
    );
  }

  Widget _eventCard(BuildContext context, EventRow ev) {
    final t = context.tokens;
    final rsvps = _data.rsvps.where((r) => r.eventId == ev.id).length;
    final contribs = _data.contributions.where((c) => c.eventId == ev.id).toList();
    final collected = contribs.fold<double>(0, (s, c) => s + c.amount);
    final open = _showContrib == ev.id;
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if ((ev.description ?? '').isNotEmpty) Text(ev.description!, style: AppText.caption(context)),
                    const SizedBox(height: 4),
                    Text(
                      '📅 ${fmtIsoDateToDisplay(ev.eventDate)}${(ev.eventTime ?? '').isNotEmpty ? ' · ⏰ ${ev.eventTime}' : ''}',
                      style: AppText.caption(context),
                    ),
                    if ((ev.location ?? '').isNotEmpty) Text('📍 ${ev.location}', style: AppText.caption(context)),
                  ],
                ),
              ),
              EvPill(recordStatusLabel(context, ev.status), color: ev.status == 'upcoming' ? t.accent : null),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 13, color: t.mutedForeground),
                const SizedBox(width: 3),
                Text(context.ev('evm.rsvps', {'n': rsvps}), style: AppText.caption(context)),
              ]),
              Text(context.ev('evm.collected', {'amt': rupeeLoc(collected)}), style: AppText.caption(context)),
              if (ev.contributionAmount > 0)
                Text(context.ev('evm.suggested', {'amt': rupeeRaw(ev.contributionAmount)}), style: AppText.caption(context)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: EvTintButton(
                  expand: true,
                  icon: Icons.upload,
                  label: context.ev('evm.recordReceipt'),
                  onTap: () => setState(() {
                    _resetContribForm();
                    _showContrib = open ? null : ev.id;
                  }),
                ),
              ),
              if (ev.contributionAmount > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: EvTintButton(
                    expand: true,
                    color: t.warning,
                    loading: _remindingEventId == ev.id,
                    label: '🔔 ${context.ev('evm.sendReminders')}',
                    onTap: () => _sendReminders(ev),
                  ),
                ),
              ],
            ],
          ),
          if (open) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 12),
            _contribForm(context, ev),
          ],
          if (contribs.isNotEmpty) ...[
            const SizedBox(height: 12),
            EvTinyLabel(context.ev('evm.recordedReceipts'), bold: true),
            const SizedBox(height: 4),
            for (final c in contribs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: EvMutedBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${contributionLabel(c, contribWords(context))}'
                              '${c.paymentMethod.isNotEmpty ? ' · ${paymentMethodLabel(context, c.paymentMethod)}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(rupeeLoc(c.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          EvMiniChip(icon: Icons.edit_outlined, label: context.ev('evc.edit'), onTap: () => _editContribution(c.id)),
                        ],
                      ),
                      if ((c.screenshotUrl ?? '').isNotEmpty)
                        EvLink(context.ev('evm.viewReceipt'), onTap: () => openEvUrl(context, c.screenshotUrl!))
                      else
                        EvHint(context.ev('evc.noAttachment')),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _cf(String value, String hint, ValueChanged<String> onChanged, String id, {bool number = false, TextInputType? keyboard}) {
    return AppTextField(
      key: ValueKey('cf-$id-$_contribVersion'),
      hint: hint,
      initialValue: value,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : keyboard,
      onChanged: onChanged,
    );
  }

  Widget _contribForm(BuildContext context, EventRow ev) {
    final options = flatOptionsWithPrimaryLabel(_flats, _data.flats.primaryByFlatId);
    final targets = _contribTargets;
    return EvColumn(
      children: [
        EvTinyLabel(context.ev('evm.moneyIn')),
        EvPanel(
          spacing: 2,
          children: [
            Text(context.ev('evm.receiptBasis'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            EvRadioRow(
              label: context.ev('evm.basisFlat'),
              selected: _basis == ReceiptBasis.flat,
              onTap: () => setState(() => _basis = ReceiptBasis.flat),
            ),
            EvRadioRow(
              label: context.ev('evm.basisNonFlat'),
              selected: _basis == ReceiptBasis.nonFlat,
              onTap: () => setState(() => _basis = ReceiptBasis.nonFlat),
            ),
          ],
        ),
        if (_basis == ReceiptBasis.nonFlat) ...[
          _cf(_nonFlatLabel, context.ev('evm.payerHint'), (v) => _nonFlatLabel = v, 'label'),
          _cf(_amount, context.ev('evm.totalReceipt'), (v) => _amount = v, 'amountNf', number: true),
          EvHint(context.ev('evm.nonFlatHint')),
        ] else ...[
          EvPanel(
            children: [
              Text(context.ev('evm.collectMode'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              AppDropdown<FlatCollectMode>(
                items: FlatCollectMode.values,
                value: _mode,
                labelOf: (m) => context.ev('evm.mode.${m.db}'),
                onChanged: (m) => setState(() {
                  if (m != null) _mode = m;
                  _perFlat = {};
                  _contribVersion++;
                }),
              ),
            ],
          ),
          FlatMultiSelect(
            compact: true,
            flats: options,
            selected: _selectedFlats,
            onChanged: (nums) => setState(() {
              _selectedFlats = nums;
              _perFlat = {for (final n in nums) if (_perFlat.containsKey(n)) n: _perFlat[n]!};
            }),
            label: _mode == FlatCollectMode.samePerFlat ? context.ev('evm.selectRequired') : context.ev('evm.selectOptional'),
            emptyHint: context.ev('evm.selectEmptyHint'),
          ),
          if (_mode == FlatCollectMode.samePerFlat)
            _cf(
              _amount,
              ev.contributionAmount > 0
                  ? context.ev('evm.perFlatSuggested', {'amt': jsNumStr(ev.contributionAmount)})
                  : context.ev('evm.perFlat'),
              (v) => _amount = v,
              'amount',
              number: true,
            ),
          if (_mode == FlatCollectMode.individual)
            Container(
              constraints: const BoxConstraints(maxHeight: 208),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: context.tokens.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              child: SingleChildScrollView(
                child: EvColumn(
                  spacing: 6,
                  children: [
                    EvHint(context.ev('evm.individualHint')),
                    for (final fn in targets)
                      () {
                        final hc = _members.headcount(fn, _flatOf(fn)?.id, 1, 0.5);
                        return Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${context.ev('evc.flat')} $fn', style: const TextStyle(fontSize: 12)),
                                  EvHint('${hc.adults}A ${hc.kids}K', size: 9),
                                ],
                              ),
                            ),
                            Expanded(
                              child: AppTextField(
                                key: ValueKey('pf-$fn-$_contribVersion'),
                                hint: '₹',
                                initialValue: _perFlat[fn] ?? '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) => _perFlat[fn] = v,
                              ),
                            ),
                          ],
                        );
                      }(),
                  ],
                ),
              ),
            ),
          if (_mode == FlatCollectMode.headcount) ..._headcountInputs(context, targets),
          if (_mode == FlatCollectMode.lumpEqual) ...[
            AppTextField(
              key: ValueKey('lump-$_contribVersion'),
              hint: context.ev('evm.lumpTotal'),
              initialValue: _lumpTotal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => _lumpTotal = v),
            ),
            EvHint(
              context.ev('evm.lumpPreview', {
                'amt': _lumpTotal.isNotEmpty && targets.isNotEmpty ? (jsNumber(_lumpTotal) / targets.length).toStringAsFixed(2) : '…',
                'n': targets.isNotEmpty ? targets.length : _targetFlats.length,
              }),
              size: 11,
            ),
          ],
        ],
        AppDropdown<String>(
          items: const ['cash', 'upi', 'bank_transfer'],
          value: _paymentMethod,
          labelOf: (m) => m == 'bank_transfer' ? context.ev('pm.bankTransferCap') : paymentMethodLabel(context, m),
          onChanged: (m) => setState(() => _paymentMethod = m ?? 'cash'),
        ),
        EvAttachmentField(
          label: context.ev('evm.uploadProof'),
          file: _receiptFile,
          kinds: const {AttachKind.image, AttachKind.pdf},
          onChanged: (f) => setState(() => _receiptFile = f),
        ),
        if (_paymentMethod != 'cash')
          _cf(_screenshotUrl, context.ev('evc.pasteUrl'), (v) => _screenshotUrl = v, 'url', keyboard: TextInputType.url),
        AppButton(
          label: _uploading ? context.ev('evc.uploading') : context.ev('evm.saveReceipt'),
          loading: _uploading,
          onPressed: () => _recordContribution(ev.id),
        ),
      ],
    );
  }

  List<Widget> _headcountInputs(BuildContext context, List<String> targets) {
    final preview = headcountPreview(
      targetFlatNumbers: targets,
      flats: _flats,
      index: _members,
      adultWeightText: _adultWeight,
      childWeightText: _childWeight,
      totalText: _headcountTotal,
    );
    return [
      EvTwoCol(
        left: AppTextField(
          key: ValueKey('aw-$_contribVersion'),
          label: context.ev('evc.adultWeight'),
          initialValue: _adultWeight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() => _adultWeight = v),
        ),
        right: AppTextField(
          key: ValueKey('cw-$_contribVersion'),
          label: context.ev('evc.childWeight'),
          initialValue: _childWeight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() => _childWeight = v),
        ),
      ),
      AppTextField(
        key: ValueKey('hct-$_contribVersion'),
        hint: context.ev('evm.headcountTotal'),
        initialValue: _headcountTotal,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => setState(() => _headcountTotal = v),
      ),
      Container(
        constraints: const BoxConstraints(maxHeight: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: context.tokens.border), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
        child: SingleChildScrollView(
          child: EvColumn(
            spacing: 4,
            children: [
              for (final a in preview.amounts)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${context.ev('evc.flat')} ${a.flatNumber}: ${peopleText(context, a.adults, a.kids)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(rupeeRaw(a.amount), style: AppText.mono(context, size: 12)),
                  ],
                ),
              if (preview.rows.isEmpty) EvHint(context.ev('evc.selectOrAll'), size: 12),
            ],
          ),
        ),
      ),
    ];
  }
}
