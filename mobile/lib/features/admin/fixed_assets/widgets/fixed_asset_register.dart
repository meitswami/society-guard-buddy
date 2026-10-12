import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/ui.dart';
import '../../audit/data/audit_service.dart' show auditErrText;
import '../../audit/logic/js_compat.dart';
import '../../audit/widgets/audit_ui.dart';
import '../data/fixed_asset_service.dart';
import '../logic/fixed_asset_types.dart';
import 'fixed_asset_form_page.dart';

final NumberFormat _inr0 = NumberFormat('#,##,##0', 'en_IN');

String _money(double? n) => n == null ? '—' : '₹${_inr0.format(n)}';

/// Port of `FixedAssetRegister.tsx`: search, status / sub-head filters, cards with warranty / AMC alerts,
/// add / edit (form page) and delete (finance-linked assets are protected).
class FixedAssetRegister extends StatefulWidget {
  const FixedAssetRegister({
    super.key,
    required this.assets,
    required this.expenseGroups,
    required this.loading,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    this.onNavigateFinance,
    this.initialQuery,
  });

  final List<FixedAsset> assets;
  final List<ExpenseGroupOption> expenseGroups;
  final bool loading;
  final Future<void> Function(Map<String, Object?> input) onCreate;
  final Future<void> Function(String id, Map<String, Object?> input) onUpdate;
  final Future<void> Function(String id) onDelete;
  final VoidCallback? onNavigateFinance;
  final String? initialQuery;

  @override
  State<FixedAssetRegister> createState() => _FixedAssetRegisterState();
}

class _FixedAssetRegisterState extends State<FixedAssetRegister> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery ?? '');
  String _status = '';
  String _subHead = '';

  @override
  void didUpdateWidget(covariant FixedAssetRegister old) {
    super.didUpdateWidget(old);
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty && q != old.initialQuery) _search.text = q;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm([FixedAsset? asset]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FixedAssetFormPage(
        asset: asset,
        expenseGroups: widget.expenseGroups,
        onSave: (input) => asset != null
            ? widget.onUpdate(asset.id, input)
            : widget.onCreate(input),
      ),
    ));
    if (saved == true && mounted) {
      await AppFeedback.success(
        context,
        title: asset != null
            ? context.tr('Updated', 'अपडेट हुआ')
            : context.tr('Added', 'जोड़ा गया'),
        message: asset != null
            ? context.tr('Fixed asset saved', 'स्थिर संपत्ति सहेजी गई')
            : context.tr('Fixed asset registered', 'स्थिर संपत्ति पंजीकृत हुई'),
      );
    }
  }

  Future<void> _delete(FixedAsset a) async {
    if (a.sourceType == 'finance_transaction') {
      AppFeedback.toast(
        context,
        context.tr(
            'Finance-linked assets cannot be deleted. Remove the payment in Finance instead.',
            'वित्त से जुड़ी संपत्ति हटाई नहीं जा सकती। इसके बजाय वित्त में भुगतान हटाएँ।'),
        tone: BadgeTone.alert,
      );
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete asset?', 'संपत्ति हटाएँ?'),
      message: context.isHi
          ? '"${a.assetName}" को रजिस्टर से हटाएँ?'
          : 'Remove "${a.assetName}" from the register?',
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.onDelete(a.id);
      if (mounted) {
        await AppFeedback.success(context,
            title: context.tr('Deleted', 'हटाया गया'),
            message: context.tr(
                'Asset removed from register', 'संपत्ति रजिस्टर से हटाई गई'));
      }
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, auditErrText(e), tone: BadgeTone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hi = context.isHi;
    final subHeads = {
      for (final a in widget.assets)
        if ((a.subHead ?? '').trim().isNotEmpty) a.subHead!.trim(),
    }.toList()
      ..sort();
    final filtered = widget.assets
        .where((a) => fixedAssetMatches(a,
            query: _search.text, status: _status, subHead: _subHead))
        .toList();
    final statusOptions = [
      '',
      'active',
      'placeholder',
      'under_repair',
      'disposed',
      'written_off'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _search,
          caps: false,
          prefixIcon: Icons.search,
          hint: context.tr('Search asset, vendor, location…',
              'संपत्ति, विक्रेता, स्थान खोजें…'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: AppDropdown<String>(
              items: statusOptions,
              value: _status,
              labelOf: (s) => s.isEmpty
                  ? context.tr('All statuses', 'सभी स्थितियाँ')
                  : fixedAssetStatusLabel(s, hi: hi),
              onChanged: (v) => setState(() => _status = v ?? ''),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppDropdown<String>(
              items: ['', ...subHeads],
              value: subHeads.contains(_subHead) ? _subHead : '',
              labelOf: (s) =>
                  s.isEmpty ? context.tr('All sub-heads', 'सभी उप-शीर्ष') : s,
              onChanged: (v) => setState(() => _subHead = v ?? ''),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
              label: context.tr('Add asset', 'संपत्ति जोड़ें'),
              icon: Icons.add,
              dense: true,
              expand: false,
              onPressed: () => _openForm()),
        ),
        const SizedBox(height: 12),
        if (widget.loading)
          LoadingView(
              message:
                  context.tr('Loading assets…', 'संपत्तियाँ लोड हो रही हैं…'))
        else if (filtered.isEmpty)
          CardSection(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(
                  context.tr('No fixed assets match your filters.',
                      'आपके फ़िल्टर से कोई स्थिर संपत्ति मेल नहीं खाती।'),
                  textAlign: TextAlign.center,
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground)),
              const SizedBox(height: 12),
              AppButton(
                  label: context.tr('Add first asset', 'पहली संपत्ति जोड़ें'),
                  dense: true,
                  expand: false,
                  onPressed: () => _openForm()),
            ]),
          )
        else
          for (final a in filtered) ...[_card(a), const SizedBox(height: 8)],
        if (widget.onNavigateFinance != null) ...[
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
                style: TextStyle(
                    fontSize: 11, color: t.mutedForeground, height: 1.5),
                children: [
                  TextSpan(
                      text: context.tr(
                          'Payments under Finance → Record Payment with major head ',
                          'वित्त → भुगतान दर्ज करें में मुख्य शीर्ष ')),
                  TextSpan(
                      text: 'FIXED ASSETS',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: t.foreground)),
                  TextSpan(
                      text: context.tr(' are added here automatically. ',
                          ' वाले भुगतान यहाँ स्वतः जुड़ जाते हैं। ')),
                ]),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: widget.onNavigateFinance,
                child: Text(context.tr('Open Finance', 'वित्त खोलें'))),
          ),
        ],
      ],
    );
  }

  Widget _alert(String label, bool red) => TinyChip(label,
      tone: red ? Tone.destructive : Tone.warning,
      icon: Icons.warning_amber_rounded,
      pill: false);

  Widget _card(FixedAsset a) {
    final t = context.tokens;
    final hi = context.isHi;
    final meta = [
      (a.subHead ?? '').isNotEmpty ? a.subHead! : 'FIXED ASSETS',
      if ((a.acquisitionDate ?? '').isNotEmpty)
        fmtIsoDateToDisplay(a.acquisitionDate),
      if (a.billValue != null) _money(a.billValue),
    ].join(' · ');
    final vendorLoc = [a.vendorName, a.location]
        .where((s) => (s ?? '').isNotEmpty)
        .join(' · ');
    return CardSection(
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(a.assetName, style: AppText.sectionTitle(context)),
                  TinyChip(fixedAssetStatusLabel(a.status, hi: hi),
                      pill: false),
                  if (a.sourceType == 'finance_transaction')
                    TinyChip(context.tr('Finance', 'वित्त'),
                        tone: Tone.primary, icon: Icons.link, pill: false),
                  if (isWarrantyExpiringSoon(a))
                    _alert(context.tr('Warranty soon', 'वारंटी जल्द समाप्त'),
                        false),
                  if (isWarrantyExpired(a))
                    _alert(
                        context.tr('Warranty expired', 'वारंटी समाप्त'), true),
                  if (isAmcExpiringSoon(a))
                    _alert(context.tr('AMC soon', 'AMC जल्द समाप्त'), false),
                  if (isAmcExpired(a))
                    _alert(context.tr('AMC expired', 'AMC समाप्त'), true),
                ]),
            const SizedBox(height: 4),
            Text(meta, style: AppText.caption(context)),
            if (vendorLoc.isNotEmpty)
              Text(vendorLoc,
                  style: TextStyle(fontSize: 11, color: t.mutedForeground)),
            if ((a.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(a.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTokens.tint(t.foreground, 0.8))),
              ),
            if ((a.warrantyEndDate ?? '').isNotEmpty ||
                (a.amcEndDate ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 12, runSpacing: 2, children: [
                  if ((a.warrantyEndDate ?? '').isNotEmpty)
                    Text(
                        hi
                            ? 'वारंटी ${fmtIsoDateToDisplay(a.warrantyEndDate)} तक'
                            : 'Warranty till ${fmtIsoDateToDisplay(a.warrantyEndDate)}',
                        style: AppText.tiny(context)),
                  if ((a.amcEndDate ?? '').isNotEmpty)
                    Text(
                      '${hi ? 'AMC ${fmtIsoDateToDisplay(a.amcEndDate)} तक' : 'AMC till ${fmtIsoDateToDisplay(a.amcEndDate)}'}${(a.amcVendor ?? '').isNotEmpty ? ' (${a.amcVendor})' : ''}',
                      style: AppText.tiny(context),
                    ),
                ]),
              ),
          ]),
        ),
        const SizedBox(width: 6),
        SquareIconButton(
            icon: Icons.edit_outlined,
            tooltip: context.tr('Edit', 'संपादित करें'),
            onPressed: () => _openForm(a)),
        const SizedBox(width: 4),
        SquareIconButton(
            icon: Icons.delete_outline,
            tone: Tone.destructive,
            tooltip: context.t('common.delete'),
            onPressed: () => _delete(a)),
      ]),
    );
  }
}
