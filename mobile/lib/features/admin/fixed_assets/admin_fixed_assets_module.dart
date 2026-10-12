import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../audit/data/audit_service.dart' show auditErrText;
import '../audit/widgets/audit_ui.dart';
import '../core/admin_module.dart';
import 'data/fixed_asset_service.dart';
import 'logic/fixed_asset_types.dart';
import 'widgets/fixed_asset_register.dart';
import 'widgets/fixed_asset_reports.dart';

enum _SubTab { register, reports }

/// Admin "Fixed Assets" tab — port of `src/components/fixedAssets/FixedAssetsModule.tsx`
/// (asset register + reports; standard templates auto-seeded on first open).
class AdminFixedAssetsModule extends StatefulWidget {
  const AdminFixedAssetsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminFixedAssetsModule> createState() => _AdminFixedAssetsModuleState();
}

class _AdminFixedAssetsModuleState extends State<AdminFixedAssetsModule> {
  final _service = const FixedAssetService();
  late String _societyName = widget.ctx.societyName.isEmpty ? 'Society' : widget.ctx.societyName;
  _SubTab _tab = _SubTab.register;
  List<FixedAsset> _assets = const [];
  List<ExpenseGroupOption> _groups = const [];
  bool _loading = true;
  bool _seeded = false;
  bool _seeding = false;

  String get _sid => widget.ctx.societyId;

  @override
  void initState() {
    super.initState();
    if (widget.ctx.subTab == 'reports') _tab = _SubTab.reports;
    _init();
  }

  Future<void> _init() async {
    if (_sid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _service.societyName(_sid).then((n) {
      if (n != null && mounted) setState(() => _societyName = n);
    }).catchError((_) {});
    _service.fetchExpenseGroupsForFixedAssets(_sid).then((g) {
      if (mounted) setState(() => _groups = g);
    }).catchError((_) {});
    await _load();
    await _autoSeed();
  }

  Future<void> _load() async {
    try {
      final rows = await _service.fetchFixedAssets(_sid);
      if (mounted) setState(() => _assets = rows);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, auditErrText(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Web: when the register is empty on first load, seed the standard templates.
  Future<void> _autoSeed() async {
    if (_seeded || !mounted) return;
    if (_assets.isNotEmpty) {
      _seeded = true;
      return;
    }
    try {
      final count = await _service.seedStandardAssetTemplates(_sid, widget.ctx.adminName);
      _seeded = true;
      if (count > 0 && mounted) {
        AppFeedback.toast(
          context,
          context.isHi
              ? '$count मानक सोसाइटी संपत्तियाँ लोड हुईं — बिल्डर हस्तांतरण विवरण भरें'
              : 'Loaded $count standard society assets — fill in builder handover details',
        );
        await _load();
      }
    } catch (_) {
      _seeded = true;
    }
  }

  Future<void> _reloadTemplates() async {
    setState(() => _seeding = true);
    try {
      final count = await _service.seedStandardAssetTemplates(_sid, widget.ctx.adminName);
      if (!mounted) return;
      if (count > 0) {
        AppFeedback.toast(context, context.isHi ? '$count मानक संपत्ति टेम्पलेट जोड़े गए' : 'Added $count standard asset templates', tone: BadgeTone.success);
        await _load();
      } else {
        AppFeedback.toast(context, context.tr('Standard templates already exist', 'मानक टेम्पलेट पहले से मौजूद हैं'));
      }
    } catch (e) {
      if (mounted) AppFeedback.toast(context, auditErrText(e), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _create(Map<String, Object?> input) async {
    await _service.createFixedAsset(_sid, input, widget.ctx.adminName);
    await _load();
  }

  Future<void> _update(String id, Map<String, Object?> input) async {
    await _service.updateFixedAsset(_sid, id, input);
    await _load();
  }

  Future<void> _delete(String id) async {
    await _service.deleteFixedAsset(_sid, id);
    await _load();
  }

  void _openFinance() => widget.ctx.goTo(AdminTab.finance, subTab: 'record_payment');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          icon: Icons.apartment_outlined,
          iconColor: t.accent,
          title: context.tk('fixedAssets.title', 'Fixed Assets', 'स्थिर संपत्ति'),
          subtitle: context.tk(
            'fixedAssets.subtitle',
            'Society asset register — builder handover, manual entry, and auto-sync from Finance payments.',
            'सोसाइटी संपत्ति रजिस्टर — बिल्डर हस्तांतरण, मैन्युअल प्रविष्टि, और वित्त भुगतानों से स्वतः सिंक।',
          ),
          bottomSpacing: 12,
        ),
        ToneCard(
          tone: Tone.primary,
          child: Text.rich(
            TextSpan(style: TextStyle(fontSize: 12, height: 1.5, color: t.foreground), children: [
              WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.auto_awesome_outlined, size: 14, color: t.primary),
              )),
              TextSpan(
                text: context.tr(
                  'Standard assets (garden, gym, DG, lift, fire fighting, boring, water softener, etc.) are pre-loaded as templates. Record purchases in ',
                  'मानक संपत्तियाँ (बगीचा, जिम, DG, लिफ्ट, अग्निशमन, बोरिंग, वाटर सॉफ़्टनर आदि) टेम्पलेट के रूप में पहले से लोड हैं। खरीद दर्ज करें ',
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: _openFinance,
                  child: Text(context.tr('Finance → Record Payment', 'वित्त → भुगतान दर्ज करें'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.primary, decoration: TextDecoration.underline)),
                ),
              ),
              TextSpan(text: context.tr(' under ', ' में ')),
              const TextSpan(text: 'FIXED ASSETS', style: TextStyle(fontWeight: FontWeight.w500)),
              TextSpan(text: context.tr(' to auto-add them here.', ' शीर्ष के अंतर्गत, ताकि वे यहाँ स्वतः जुड़ जाएँ।')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _subTabs(),
        const SizedBox(height: 16),
        if (_tab == _SubTab.register) ...[
          Align(
            alignment: Alignment.centerRight,
            child: SmallButton(
              label: context.tr('Reload standard templates', 'मानक टेम्पलेट फिर लोड करें'),
              style: SmallBtnStyle.secondary,
              fontSize: 10,
              busy: _seeding,
              onPressed: _sid.isEmpty ? null : _reloadTemplates,
            ),
          ),
          const SizedBox(height: 8),
          FixedAssetRegister(
            assets: _assets,
            expenseGroups: _groups,
            loading: _loading,
            onCreate: _create,
            onUpdate: _update,
            onDelete: _delete,
            onNavigateFinance: _openFinance,
            initialQuery: widget.ctx.initialQuery,
          ),
        ] else
          FixedAssetReports(societyId: _sid, societyName: _societyName, assets: _assets),
      ],
    );
  }

  Widget _subTabs() {
    final t = context.tokens;
    Widget tab(_SubTab id, IconData icon, String label) {
      final active = _tab == id;
      return Expanded(
        child: Material(
          color: active ? t.background : Colors.transparent,
          elevation: active ? 1 : 0,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: () => setState(() => _tab = id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 14, color: active ? t.foreground : t.mutedForeground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? t.foreground : t.mutedForeground)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTokens.tint(t.muted, 0.4), borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: Row(children: [
        tab(_SubTab.register, Icons.assignment_outlined, context.tr('Asset register', 'संपत्ति रजिस्टर')),
        const SizedBox(width: 4),
        tab(_SubTab.reports, Icons.bar_chart, context.tr('Reports', 'रिपोर्ट')),
      ]),
    );
  }
}
