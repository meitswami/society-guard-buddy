import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../data/superadmin_models.dart';
import '../data/superadmin_repository.dart';
import '../logic/society_form.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/sa_widgets.dart';
import 'society_form_page.dart';
import 'tab_page.dart';

/// Web Societies tab: list (+ search, active toggle, details with referral code / wallet),
/// add / edit (form page), delete.
class SocietiesTab extends StatefulWidget {
  const SocietiesTab({super.key, required this.ctx});

  final SuperadminTabContext ctx;

  @override
  State<SocietiesTab> createState() => _SocietiesTabState();
}

enum _ActiveFilter { all, active, inactive }

class _SocietiesTabState extends State<SocietiesTab> {
  String _query = '';
  _ActiveFilter _filter = _ActiveFilter.all;

  Future<void> _delete(SuperadminConsole console, SocietyRow s) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmDelete'),
      message: '${s.name}\n${context.t('swal.confirmDeleteText')}',
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await console.repo.deleteSociety(s.id);
      if (!mounted) return;
      await AppFeedback.success(context,
          title: context.t('swal.success'),
          message: context.st('sa.societies.deleted'));
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, context.st('sa.societies.deleteFailed'),
            tone: BadgeTone.alert);
      }
    }
    await console.loadAll();
  }

  Future<void> _toggleActive(SuperadminConsole console, SocietyRow s) async {
    final next = !s.isActive;
    final ok = await AppFeedback.confirm(
      context,
      title: next
          ? context.st('sa.societies.activateTitle')
          : context.st('sa.societies.deactivateTitle'),
      message: next
          ? context.st('sa.societies.activateText')
          : context.st('sa.societies.deactivateText'),
      destructive: !next,
    );
    if (!ok || !mounted) return;
    try {
      await console.repo.setSocietyActive(s.id, next);
      if (mounted) {
        AppFeedback.toast(
          context,
          next
              ? context.st('sa.societies.activated')
              : context.st('sa.societies.deactivated'),
          tone: BadgeTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.t('superadmin.societySaveFailed'),
            tone: BadgeTone.alert);
      }
    }
    await console.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final console = SuperadminScope.of(context);
    final list = console.societies.where((s) {
      if (_filter == _ActiveFilter.active && !s.isActive) return false;
      if (_filter == _ActiveFilter.inactive && s.isActive) return false;
      return s.matches(_query);
    }).toList();
    final activeCount = console.societies.where((s) => s.isActive).length;

    return SuperadminTabPage(
      ctx: widget.ctx,
      onRefresh: console.loadAll,
      children: [
        SaTabTitle(
          context.t('superadmin.societies'),
          actions: [
            SaTintButton(
              icon: Icons.add,
              tooltip: context.t('superadmin.newSociety'),
              onPressed: () => SocietyFormPage.open(context, console),
            ),
          ],
        ),
        if (console.societies.isNotEmpty) ...[
          AppTextField(
            hint: context.st('sa.societies.search'),
            prefixIcon: Icons.search,
            caps: false,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChoice(
                label:
                    '${context.st('sa.filter.all')} (${console.societies.length})',
                selected: _filter == _ActiveFilter.all,
                onTap: () => setState(() => _filter = _ActiveFilter.all),
              ),
              PillChoice(
                label: '${context.t('common.active')} ($activeCount)',
                selected: _filter == _ActiveFilter.active,
                onTap: () => setState(() => _filter = _ActiveFilter.active),
              ),
              PillChoice(
                label:
                    '${context.st('sa.societies.inactive')} (${console.societies.length - activeCount})',
                selected: _filter == _ActiveFilter.inactive,
                onTap: () => setState(() => _filter = _ActiveFilter.inactive),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (!console.loaded && console.loading)
          const LoadingView()
        else if (console.loadFailed && console.societies.isEmpty)
          ErrorView(onRetry: console.loadAll)
        else if (console.societies.isEmpty)
          EmptyView(
              message: context.t('superadmin.noSocieties'),
              icon: Icons.apartment_outlined)
        else if (list.isEmpty)
          EmptyView(message: context.st('sa.noMatches'))
        else
          for (final s in list)
            _SocietyCard(
              society: s,
              onEdit: () => SocietyFormPage.open(context, console, society: s),
              onDelete: () => _delete(console, s),
              onToggleActive: () => _toggleActive(console, s),
              onDetails: () => _SocietyDetailsSheet.show(context, console, s),
            ),
      ],
    );
  }
}

class _SocietyCard extends StatelessWidget {
  const _SocietyCard({
    required this.society,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onDetails,
  });

  final SocietyRow society;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = society;
    final photos = s.photoUrls;
    final thumb = s.thumbUrl;
    final stats = <String>[
      if (s.totalFlats != null)
        '${context.t('superadmin.totalFlats')}: ${s.totalFlats}',
      if (s.totalFloors != null)
        '${context.t('superadmin.totalFloors')}: ${s.totalFloors}',
      if ((s.blockNames?.length ?? 0) > 0) s.blockNames!.join(', '),
    ];
    final series = s.flatsPerFloor != null &&
            (s.flatSeriesStart?.isNotEmpty ?? false) &&
            (s.flatSeriesEnd?.isNotEmpty ?? false)
        ? '${s.flatsPerFloor} ${context.t('superadmin.flatsPerFloorShort')} · ${s.flatSeriesStart}–${s.flatSeriesEnd}'
        : null;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onDetails,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumb != null) ...[SaNetImage(thumb), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                        child:
                            Text(s.name, style: AppText.bodyMedium(context))),
                    const SizedBox(width: 6),
                    if (!s.isActive)
                      StatusBadge(context.st('sa.societies.inactive'),
                          tone: BadgeTone.alert),
                  ],
                ),
                if (s.addressLine.isNotEmpty)
                  Text(s.addressLine, style: AppText.caption(context)),
                if (s.contactPerson != null && s.contactPerson!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '👤 ${s.contactPerson}${(s.contactPhone?.isNotEmpty ?? false) ? ' • ${s.contactPhone}' : ''}',
                      style: AppText.caption(context),
                    ),
                  ),
                if (stats.isNotEmpty || series != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        for (final x in stats)
                          Text(x, style: AppText.tiny(context)),
                        if (series != null)
                          SizedBox(
                              width: double.infinity,
                              child:
                                  Text(series, style: AppText.tiny(context))),
                      ],
                    ),
                  ),
                if (s.referralCode != null && s.referralCode!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SaTag(
                        '${context.st('sa.societies.referral')}: ${s.referralCode}',
                        primary: true),
                  ),
                if (photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final u in photos.take(6))
                            Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: SaNetImage(u,
                                    width: 32, height: 32, radius: 4)),
                          if (photos.length > 6)
                            Text('+${photos.length - 6}',
                                style: AppText.tiny(context)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.t('superadmin.editSociety'),
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 18, color: t.primary),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.t('common.delete'),
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: t.destructive),
                  ),
                ],
              ),
              Tooltip(
                message: s.isActive
                    ? context.st('sa.societies.deactivateTitle')
                    : context.st('sa.societies.activateTitle'),
                child: Switch(
                    value: s.isActive, onChanged: (_) => onToggleActive()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full society details (layout, contact, letterhead, counts, referral & wallet).
class _SocietyDetailsSheet extends StatefulWidget {
  const _SocietyDetailsSheet({required this.console, required this.society});

  final SuperadminConsole console;
  final SocietyRow society;

  static Future<void> show(
          BuildContext context, SuperadminConsole console, SocietyRow s) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _SocietyDetailsSheet(console: console, society: s),
      );

  @override
  State<_SocietyDetailsSheet> createState() => _SocietyDetailsSheetState();
}

class _SocietyDetailsSheetState extends State<_SocietyDetailsSheet> {
  late SocietyRow _s = widget.society;
  late final Future<SocietyDetails> _details =
      widget.console.repo.societyDetails(_s.id);
  bool _generating = false;

  String _tri(bool? v) => v == null
      ? context.t('superadmin.notSpecified')
      : (v ? context.t('swal.yes') : context.t('swal.no'));

  Future<void> _generateReferral() async {
    final code = makeReferralCode(_s.name, _s.id);
    setState(() => _generating = true);
    final res = await widget.console.repo.setReferralCode(_s.id, code);
    if (!mounted) return;
    setState(() => _generating = false);
    if (!res.ok) {
      AppFeedback.toast(
        context,
        res.duplicate
            ? context.st('sa.societies.referralDuplicate')
            : (res.message ?? context.t('superadmin.societySaveFailed')),
        tone: BadgeTone.alert,
      );
      return;
    }
    await widget.console.loadAll();
    if (!mounted) return;
    setState(() => _s = widget.console.societyById(_s.id) ?? _s);
    AppFeedback.toast(context, context.st('sa.societies.referralSaved'),
        tone: BadgeTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _s;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              if (s.thumbUrl != null) ...[
                SaNetImage(s.thumbUrl!, width: 48, height: 48),
                const SizedBox(width: 12)
              ],
              Expanded(child: Text(s.name, style: AppText.pageTitle(context))),
              StatusBadge(
                s.isActive
                    ? context.t('common.active')
                    : context.st('sa.societies.inactive'),
                tone: s.isActive ? BadgeTone.success : BadgeTone.alert,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<SocietyDetails>(
            future: _details,
            builder: (context, snap) {
              final d = snap.data;
              String n(int? v) => snap.connectionState != ConnectionState.done
                  ? '…'
                  : (v == null ? '—' : Fmt.number(v));
              return StatGrid(
                columns: 4,
                spacing: 8,
                children: [
                  _MiniStat(
                      label: context.st('sa.details.flats'),
                      value: n(d?.flats)),
                  _MiniStat(
                      label: context.t('superadmin.admins'),
                      value: n(d?.admins)),
                  _MiniStat(
                      label: context.t('superadmin.roles'), value: n(d?.roles)),
                  _MiniStat(
                      label: context.st('sa.details.guards'),
                      value: n(d?.guards)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(context.st('sa.societies.referral'),
                    icon: Icons.sell_outlined),
                if (s.referralCode != null && s.referralCode!.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                          child: SelectableText(s.referralCode!,
                              style: AppText.mono(context,
                                  size: 16, weight: FontWeight.w600))),
                      IconButton(
                          icon: const Icon(Icons.content_copy, size: 18),
                          onPressed: () => saCopy(context, s.referralCode!)),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        onPressed: () => ExportKit.openWhatsApp(context.st(
                            'sa.societies.referralShare',
                            {'code': s.referralCode, 'name': s.name})),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(context.st('sa.societies.noReferral'),
                      style: AppText.caption(context)),
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: context.st('sa.societies.generateReferral'),
                    icon: Icons.sell_outlined,
                    dense: true,
                    loading: _generating,
                    onPressed: _generating ? null : _generateReferral,
                  ),
                ],
                FutureBuilder<SocietyDetails>(
                  future: _details,
                  builder: (context, snap) {
                    final d = snap.data;
                    if (d == null) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        KeyValueRow(context.st('sa.details.walletBalance'),
                            d.wallet.isEmpty ? '—' : Fmt.inr(d.walletBalance)),
                        KeyValueRow(context.st('sa.details.referrals'),
                            '${d.referrals.length}'),
                        for (final r in d.referrals.take(10))
                          Text(
                            '${Fmt.date(r['created_at'])} · ${r['referral_code_used'] ?? ''} · '
                            '${r['referrer_society_id'] == s.id ? '+${Fmt.inr(asDouble(r['referrer_reward_inr']))}' : '+${Fmt.inr(asDouble(r['referred_reward_inr']))}'}',
                            style: AppText.tiny(context),
                          ),
                        for (final w in d.wallet.take(10))
                          Text(
                            '${Fmt.date(w['created_at'])} · ${w['entry_type'] == 'debit' ? '−' : '+'}${Fmt.inr(asDouble(w['amount_inr']))}'
                            '${(w['notes'] ?? '').toString().isNotEmpty ? ' · ${w['notes']}' : ''}',
                            style: AppText.tiny(context),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(context.t('superadmin.societyBuilding'),
                    icon: Icons.apartment_outlined),
                KeyValueRow(context.t('superadmin.address'), s.addressLine),
                KeyValueRow(context.t('superadmin.pincode'), s.pincode ?? ''),
                KeyValueRow(context.t('superadmin.totalFlats'),
                    s.totalFlats?.toString() ?? ''),
                KeyValueRow(context.t('superadmin.totalFloors'),
                    s.totalFloors?.toString() ?? ''),
                KeyValueRow(context.st('sa.details.blocks'),
                    (s.blockNames ?? const []).join(', ')),
                KeyValueRow(context.t('superadmin.flatsPerFloor'),
                    s.flatsPerFloor?.toString() ?? ''),
                KeyValueRow(
                  context.st('sa.details.flatSeries'),
                  (s.flatSeriesStart ?? '').isEmpty
                      ? ''
                      : '${s.flatSeriesStart}–${s.flatSeriesEnd ?? ''}',
                ),
                KeyValueRow(context.t('superadmin.terraceAccessible'),
                    _tri(s.terraceAccessible)),
                KeyValueRow(
                    context.t('superadmin.basement'), _tri(s.hasBasement)),
                if (s.hasBasement == true)
                  KeyValueRow(context.t('superadmin.basementUsable'),
                      _tri(s.basementUsableForResidents)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(context.t('superadmin.branding'),
                    icon: Icons.person_outline),
                KeyValueRow(context.t('superadmin.contactPerson'),
                    s.contactPerson ?? ''),
                KeyValueRow(
                    context.t('superadmin.contactPhone'), s.contactPhone ?? ''),
                KeyValueRow(
                    context.t('superadmin.contactEmail'), s.contactEmail ?? ''),
                KeyValueRow(
                    context.t('superadmin.letterheadMode'),
                    switch (s.letterheadMode) {
                      'image' => context.t('superadmin.letterheadModeImage'),
                      'stationery' =>
                        context.t('superadmin.letterheadModeStationery'),
                      _ => context.t('superadmin.letterheadModeAuto'),
                    }),
                KeyValueRow(context.st('sa.details.created'),
                    Fmt.dateTime(s.createdAt)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (looksLikePhone(s.contactPhone))
                      AppButton.secondary(
                        label: context.t('common.phone'),
                        icon: Icons.phone_outlined,
                        dense: true,
                        expand: false,
                        onPressed: () => ExportKit.call(s.contactPhone!),
                      ),
                    if ((s.contactEmail ?? '').contains('@'))
                      AppButton.secondary(
                        label: context.st('sa.details.email'),
                        icon: Icons.mail_outline,
                        dense: true,
                        expand: false,
                        onPressed: () => ExportKit.email(s.contactEmail!),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (s.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(context.t('superadmin.societyPhotos'),
                style: AppText.fieldLabel(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in s.photoUrls)
                  InkWell(
                      onTap: () => ExportKit.openUrl(u),
                      child: SaNetImage(u, width: 72, height: 72)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text('ID: ${s.id}',
              style: AppText.mono(context, size: 10, color: t.mutedForeground)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CardSection(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        children: [
          Text(value,
              style: AppText.mono(context, size: 15, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.tiny(context)),
        ],
      ),
    );
  }
}
