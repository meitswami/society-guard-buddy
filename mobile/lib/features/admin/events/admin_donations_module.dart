import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/admin_module.dart';
import 'data/donations_repository.dart';
import 'data/events_models.dart';
import 'data/query_helpers.dart';
import 'logic/flat_options.dart';
import 'logic/js_compat.dart';
import 'widgets/ev_fields.dart';
import 'widgets/ev_i18n.dart';
import 'widgets/ev_ui.dart';
import 'widgets/flat_multi_select.dart';

/// Preset campaign titles (web `DONATION_CAMPAIGN_TITLE_OPTIONS`; stored in English).
const List<String> kDonationCampaignTitles = [
  'Marriage anniversary',
  'On birthdays',
  'New born child entry',
  'Marriage functions',
  'Festivals',
  'Voluntary contribution',
  'Visitors parking',
  'Any other occasion',
  'Miscellaneous receipts',
];

const String _customTitle = '__custom__';

/// Admin tab `donations` — port of `src/components/DonationManager.tsx`.
class AdminDonationsModule extends StatefulWidget {
  const AdminDonationsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminDonationsModule> createState() => _AdminDonationsModuleState();
}

class _AdminDonationsModuleState extends State<AdminDonationsModule> {
  static const _repo = DonationsRepository();

  DonationsData _data = DonationsData.empty;
  bool _loading = true;
  Object? _error;
  late String _query = widget.ctx.initialQuery?.trim() ?? '';

  bool _showForm = false;
  String _titleChoice = '';
  int _cfV = 0;
  String _cfTitle = '';
  String _cfDescription = '';
  String _cfTarget = '';
  String _cfEndDate = '';
  bool _savingCampaign = false;

  String? _showDonate;
  int _dfV = 0;
  List<String> _dfFlats = const [];
  String _dfAmount = '';
  String _dfMethod = 'cash';
  String _dfTxn = '';
  String _dfShot = '';
  bool _savingDonation = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final d = await _repo.load(widget.ctx.societyId);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  void _resetCampaignForm() {
    _titleChoice = '';
    _cfTitle = '';
    _cfDescription = '';
    _cfTarget = '';
    _cfEndDate = '';
    _cfV++;
  }

  Future<void> _addCampaign() async {
    if (widget.ctx.societyId.isEmpty) return;
    if (_cfTitle.trim().isEmpty) {
      AppFeedback.toast(context, context.ev('don.titleRequired'));
      return;
    }
    setState(() => _savingCampaign = true);
    try {
      await _repo.insertCampaign(
        societyId: widget.ctx.societyId,
        adminName: widget.ctx.adminName,
        title: _cfTitle.trim(),
        description: _cfDescription.isEmpty ? null : _cfDescription,
        targetAmount: jsNumberOr(_cfTarget, 0),
        endDate: _cfEndDate.isEmpty ? null : _cfEndDate,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _savingCampaign = false);
        AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _savingCampaign = false;
      _resetCampaignForm();
      _showForm = false;
    });
    AppFeedback.toast(context, context.ev('don.campaignCreated'), tone: BadgeTone.success);
    _loadAll();
  }

  Future<void> _addDonation(DonationCampaign camp) async {
    if (_dfFlats.isEmpty || _dfAmount.isEmpty) {
      AppFeedback.toast(context, context.ev('don.flatsAmountRequired'), tone: BadgeTone.alert);
      return;
    }
    final amount = jsNumber(_dfAmount);
    final verifiedAt = DateTime.now().toUtc().toIso8601String();
    final flats = _data.flats.flats;
    final rows = [
      for (final fn in _dfFlats)
        () {
          FlatLite? flat;
          for (final f in flats) {
            if (f.flatNumber == fn) {
              flat = f;
              break;
            }
          }
          return <String, dynamic>{
            'campaign_id': camp.id,
            'flat_id': flat?.id,
            'flat_number': fn,
            'resident_name': residentLabelForFlatRow(flat?.id, flat?.ownerName, _data.flats.primaryByFlatId),
            'amount': amount,
            'payment_method': _dfMethod,
            'transaction_id': _dfTxn.isEmpty ? null : _dfTxn,
            'screenshot_url': _dfShot.isEmpty ? null : _dfShot,
            'verified_by': widget.ctx.adminName,
            'verified_at': verifiedAt,
          };
        }(),
    ];
    setState(() => _savingDonation = true);
    try {
      await _repo.insertDonations(rows);
      await _repo.setCollectedAmount(camp.id, (camp.collectedAmount ?? 0) + amount * rows.length);
    } catch (e) {
      if (mounted) {
        setState(() => _savingDonation = false);
        AppFeedback.toast(context, supabaseErrorMessage(e), tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _savingDonation = false;
      _dfFlats = const [];
      _dfAmount = '';
      _dfMethod = 'cash';
      _dfTxn = '';
      _dfShot = '';
      _dfV++;
      _showDonate = null;
    });
    AppFeedback.toast(
      context,
      rows.length > 1 ? context.ev('don.recordedMany', {'n': rows.length}) : context.ev('don.recorded'),
      tone: BadgeTone.success,
    );
    _loadAll();
  }

  bool _matches(DonationCampaign c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.title.toLowerCase().contains(q) ||
        (c.description ?? '').toLowerCase().contains(q) ||
        _data.donations.any((d) => d.campaignId == c.id && (d.flatNumber.toLowerCase().contains(q) || (d.residentName ?? '').toLowerCase().contains(q)));
  }

  String _presetLabel(BuildContext context, String title) {
    final idx = kDonationCampaignTitles.indexOf(title);
    return idx < 0 ? title : context.ev('don.preset.$idx');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final campaigns = _data.campaigns.where(_matches).toList();
    return PageContainer(
      onRefresh: _loadAll,
      children: [
        PageHeader(icon: Icons.favorite_border, iconColor: t.destructive, title: context.ev('don.title'), bottomSpacing: 12),
        AppTextField(
          hint: context.ev('don.searchHint'),
          initialValue: _query,
          caps: false,
          prefixIcon: Icons.search,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        AppButton(
          icon: Icons.add,
          label: context.ev('don.newCampaign'),
          onPressed: () => setState(() {
            if (_showForm) _resetCampaignForm();
            _showForm = !_showForm;
          }),
        ),
        const SizedBox(height: 12),
        if (_showForm) ...[_campaignForm(context), const SizedBox(height: 12)],
        if (_loading)
          const LoadingView()
        else if (_error != null)
          ErrorView(
            message: supabaseErrorMessage(_error!),
            onRetry: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadAll();
            },
          )
        else if (_data.campaigns.isEmpty)
          EmptyView(icon: Icons.volunteer_activism_outlined, message: context.ev('don.empty'))
        else if (campaigns.isEmpty)
          EmptyView(message: context.ev('evc.noMatch', {'q': _query.trim()}))
        else
          for (final c in campaigns) Padding(padding: const EdgeInsets.only(bottom: 12), child: _campaignCard(context, c)),
      ],
    );
  }

  Widget _campaignForm(BuildContext context) {
    return CardSection(
      child: EvColumn(
        spacing: 12,
        children: [
          AppDropdown<String>(
            label: context.ev('don.campaignTitle'),
            items: ['', ...kDonationCampaignTitles, _customTitle],
            value: _titleChoice,
            labelOf: (v) => v.isEmpty
                ? context.ev('don.selectOccasion')
                : v == _customTitle
                    ? context.ev('don.otherCustom')
                    : _presetLabel(context, v),
            onChanged: (v) => setState(() {
              _titleChoice = v ?? '';
              _cfTitle = (_titleChoice.isEmpty || _titleChoice == _customTitle) ? '' : _titleChoice;
              _cfV++;
            }),
          ),
          if (_titleChoice == _customTitle)
            AppTextField(key: ValueKey('cf-title-$_cfV'), hint: context.ev('don.customTitle'), initialValue: _cfTitle, onChanged: (v) => _cfTitle = v),
          AppTextField(
            key: ValueKey('cf-desc-$_cfV'),
            hint: context.ev('don.description'),
            initialValue: _cfDescription,
            maxLines: 3,
            minLines: 2,
            onChanged: (v) => _cfDescription = v,
          ),
          AppTextField(
            key: ValueKey('cf-target-$_cfV'),
            hint: context.ev('don.target'),
            initialValue: _cfTarget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => _cfTarget = v,
          ),
          EvDateField(value: _cfEndDate, hint: context.ev('don.endDate'), onChanged: (v) => setState(() => _cfEndDate = v)),
          AppButton(label: context.ev('don.createCampaign'), loading: _savingCampaign, onPressed: _addCampaign),
        ],
      ),
    );
  }

  Widget _campaignCard(BuildContext context, DonationCampaign c) {
    final t = context.tokens;
    final donations = _data.donations.where((d) => d.campaignId == c.id).toList();
    final collected = c.collectedAmount ?? 0;
    final progress = c.targetAmount > 0 ? (collected / c.targetAmount).clamp(0.0, 1.0) : 0.0;
    final open = _showDonate == c.id;
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
                    Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if ((c.description ?? '').isNotEmpty) Text(c.description!, style: AppText.caption(context)),
                    if ((c.endDate ?? '').isNotEmpty)
                      EvHint(context.ev('don.ends', {'date': Fmt.isoToDisplay(c.endDate)})),
                  ],
                ),
              ),
              EvPill(recordStatusLabel(context, c.status), color: c.status == 'active' ? t.success : null),
            ],
          ),
          const SizedBox(height: 8),
          if (c.targetAmount > 0) ...[
            Row(
              children: [
                Expanded(child: Text(rupeeRaw(collected), style: const TextStyle(fontSize: 12))),
                Text(rupeeRaw(c.targetAmount), style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: t.muted, color: t.success),
            ),
            const SizedBox(height: 8),
          ],
          Text(context.ev('don.count', {'n': donations.length}), style: AppText.caption(context)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: EvLink(
              context.ev('don.record'),
              size: 12,
              icon: Icons.upload,
              onTap: () => setState(() => _showDonate = open ? null : c.id),
            ),
          ),
          if (open) ...[
            Divider(height: 20, color: t.border),
            EvColumn(
              children: [
                FlatMultiSelect(
                  compact: true,
                  flats: flatOptionsWithPrimaryLabel(_data.flats.flats, _data.flats.primaryByFlatId),
                  selected: _dfFlats,
                  onChanged: (v) => setState(() => _dfFlats = v),
                  label: context.ev('fms.flats'),
                ),
                AppTextField(
                  key: ValueKey('df-amount-$_dfV'),
                  hint: context.ev('evc.amountRs'),
                  initialValue: _dfAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => _dfAmount = v,
                ),
                AppDropdown<String>(
                  items: const ['cash', 'upi', 'bank_transfer'],
                  value: _dfMethod,
                  labelOf: (m) => m == 'bank_transfer' ? context.ev('pm.bankTransferCap') : paymentMethodLabel(context, m),
                  onChanged: (v) => setState(() => _dfMethod = v ?? 'cash'),
                ),
                if (_dfMethod != 'cash') ...[
                  AppTextField(key: ValueKey('df-txn-$_dfV'), hint: context.ev('don.txn'), initialValue: _dfTxn, caps: false, onChanged: (v) => _dfTxn = v),
                  AppTextField(
                    key: ValueKey('df-shot-$_dfV'),
                    hint: context.ev('don.screenshotUrl'),
                    initialValue: _dfShot,
                    keyboardType: TextInputType.url,
                    onChanged: (v) => _dfShot = v,
                  ),
                ],
                AppButton(label: context.ev('don.recordBtn'), loading: _savingDonation, onPressed: () => _addDonation(c)),
              ],
            ),
          ],
          if (donations.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in donations.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: EvMutedBox(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.flatNumber}${(d.residentName ?? '').isNotEmpty ? ' · ${d.residentName}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(rupeeRaw(d.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
