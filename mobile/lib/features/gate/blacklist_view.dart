import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/gate_actor.dart';
import '../../core/ui/ui.dart';
import '../../models/blacklist_entry.dart';
import 'data/gate_logic.dart';
import 'data/gate_store.dart';
import 'gate_i18n.dart';

/// Society blacklist (visitors by phone, vehicles by number) — web `src/pages/BlacklistPage.tsx`.
class BlacklistView extends StatefulWidget {
  const BlacklistView(
      {super.key, required this.actor, this.initialSearchQuery});

  final GateActor actor;
  final String? initialSearchQuery;

  @override
  State<BlacklistView> createState() => _BlacklistViewState();
}

class _BlacklistViewState extends State<BlacklistView> {
  late final GateStore _store = GateStore.of(widget.actor.societyId);
  late final _search =
      TextEditingController(text: widget.initialSearchQuery ?? '');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController();
  final _reason = TextEditingController();
  bool _showForm = false;
  String _type = 'visitor';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_search, _name, _phone, _vehicle, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    for (final c in [_name, _phone, _vehicle, _reason]) {
      c.clear();
    }
    _type = 'visitor';
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    final phone = _phone.text.trim();
    final vehicle = _vehicle.text.trim();
    if (reason.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.blacklist.reasonRequired'),
          tone: BadgeTone.warning);
      return;
    }
    if (_type == 'visitor' && phone.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.blacklist.phoneRequired'),
          tone: BadgeTone.warning);
      return;
    }
    if (_type == 'vehicle' && vehicle.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.blacklist.vehicleRequired'),
          tone: BadgeTone.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await _store.addToBlacklist(
        type: _type,
        reason: reason,
        addedBy:
            widget.actor.actorName.isEmpty ? 'Unknown' : widget.actor.actorName,
        name: _type == 'visitor' ? _name.text.trim() : null,
        phone: _type == 'visitor' ? phone : null,
        vehicleNumber: _type == 'vehicle' ? vehicle : null,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.toast(context, context.gt('gate.saveFailed'),
            tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _resetForm();
      _showForm = false;
    });
    await AppFeedback.success(context,
        title: context.t('swal.success'),
        message: context.t('blacklist.addedSuccess'));
  }

  Future<void> _remove(BlacklistEntry e) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmDelete'),
      message: context.t('swal.confirmDeleteText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _store.removeFromBlacklist(e.id);
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.gt('gate.deleteFailed'),
            tone: BadgeTone.alert);
      }
    }
  }

  Widget _typeButton(String type, IconData icon, String label) {
    final t = context.tokens;
    final on = _type == type;
    return Expanded(
      child: Material(
        color: on ? t.destructive : t.secondary,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: () => setState(() => _type = type),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 14,
                    color:
                        on ? t.destructiveForeground : t.secondaryForeground),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: on
                            ? t.destructiveForeground
                            : t.secondaryForeground)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final t = context.tokens;
        final q = _search.text;
        final list = _store.blacklist
            .where((e) => blacklistMatchesSearch(e, q))
            .toList();
        return PageContainer(
          onRefresh: _store.loadBlacklist,
          children: [
            PageHeader(
              icon: Icons.gpp_maybe_outlined,
              iconColor: t.destructive,
              title: context.t('blacklist.title'),
              subtitle:
                  '${_store.blacklist.length} ${context.t('blacklist.flagged')}',
              bottomSpacing: 24,
              actions: [
                AppButton(
                  label: context.t('common.add'),
                  icon: Icons.add,
                  dense: true,
                  expand: false,
                  onPressed: () => setState(() => _showForm = !_showForm),
                ),
              ],
            ),
            if (_showForm)
              CardSection(
                margin: const EdgeInsets.only(bottom: 16),
                borderColor: AppTokens.tint(t.destructive, 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _typeButton('visitor', Icons.person_outline,
                            context.t('blacklist.visitor')),
                        const SizedBox(width: 8),
                        _typeButton('vehicle', Icons.directions_car_outlined,
                            context.t('blacklist.vehicle')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_type == 'visitor') ...[
                      AppTextField(
                          controller: _name, hint: context.t('common.name')),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _phone,
                        hint: '${context.t('common.phone')} *',
                        keyboardType: TextInputType.phone,
                        mono: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10)
                        ],
                      ),
                    ] else
                      AppTextField(
                          controller: _vehicle,
                          hint: '${context.t('visitor.vehicleNumber')} *',
                          mono: true),
                    const SizedBox(height: 12),
                    AppTextField(
                        controller: _reason,
                        hint: '${context.t('blacklist.reason')} *'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                              label: context.t('blacklist.addToBlacklist'),
                              dense: true,
                              loading: _saving,
                              onPressed: _submit),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton.secondary(
                            label: context.t('common.cancel'),
                            dense: true,
                            onPressed: () => setState(() => _showForm = false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            AppTextField(
                controller: _search,
                hint: context.t('blacklist.searchPlaceholder'),
                prefixIcon: Icons.search,
                caps: false),
            const SizedBox(height: 16),
            if (!_store.blacklistLoaded)
              const LoadingView()
            else if (_store.blacklistError != null && _store.blacklist.isEmpty)
              ErrorView(onRetry: _store.loadBlacklist)
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  q.isNotEmpty
                      ? context.t('blacklist.noMatch')
                      : context.t('blacklist.empty'),
                  textAlign: TextAlign.center,
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground),
                ),
              )
            else
              for (final e in list)
                CardSection(
                  margin: const EdgeInsets.only(bottom: 8),
                  borderColor: AppTokens.tint(t.destructive, 0.2),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: AppTokens.tint(t.destructive, 0.2),
                            shape: BoxShape.circle),
                        child: Icon(
                            e.type == 'visitor'
                                ? Icons.person_outline
                                : Icons.directions_car_outlined,
                            size: 16,
                            color: t.destructive),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.type == 'visitor'
                                  ? ((e.name ?? '').isNotEmpty
                                      ? e.name!
                                      : (e.phone ?? ''))
                                  : (e.vehicleNumber ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sectionTitle(context),
                            ),
                            if (e.type == 'visitor' &&
                                (e.phone ?? '').isNotEmpty)
                              Text(e.phone!,
                                  style: AppText.mono(context,
                                      size: 12, color: t.mutedForeground)),
                            const SizedBox(height: 2),
                            Text(e.reason,
                                style: TextStyle(
                                    fontSize: 12, color: t.destructive)),
                            Text(
                                context.gt(
                                    'gate.blacklist.by', {'name': e.addedBy}),
                                style: AppText.tiny(context)),
                          ],
                        ),
                      ),
                      IconPillButton(
                          icon: Icons.delete_outline,
                          tooltip: context.t('common.delete'),
                          onPressed: () => _remove(e)),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
