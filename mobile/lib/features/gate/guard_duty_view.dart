import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import 'data/gate_store.dart';
import 'data/guard_duty_service.dart';
import 'data/guard_duty_types.dart';
import 'widgets/big_tap_button.dart';
import 'widgets/photo_capture.dart';

/// Guard daily duty sheet — web `src/pages/GuardDutyPage.tsx`: staff attendance (absent / late
/// ask for a reason), building checks with problem presets, incident reports with severity /
/// flat / photos, and "Send shift report". One sheet per guard shift.
class GuardDutyView extends StatefulWidget {
  const GuardDutyView({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardDutyView> createState() => _GuardDutyViewState();
}

class _GuardDutyViewState extends State<GuardDutyView> {
  final _service = const GuardDutyService();
  late final GateStore _store = GateStore.of(widget.session.societyId);

  GuardDutyBundle? _bundle;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    final s = widget.session;
    try {
      final guardUuid = await _service.resolveGuardUuid(s.guard.guardId, s.societyId);
      if (guardUuid == null) throw StateError('Guard record not found');
      final bundle = await _service.getOrCreateDutyForShift(
        societyId: s.societyId,
        shiftId: s.shiftId,
        guardUuid: guardUuid,
        guardId: s.guard.guardId,
        guardName: s.guard.name,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _bundle == null;
      });
    }
  }

  /// Runs a write, then refetches the sheet (web: mutation + query invalidation).
  Future<bool> _mutate(Future<void> Function() action, {String successKey = 'duty.saved'}) async {
    setState(() => _saving = true);
    try {
      await action();
      await _load();
      if (mounted) AppFeedback.toast(context, context.t(successKey), tone: BadgeTone.success);
      return true;
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('duty.saveFailed'), tone: BadgeTone.alert);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _staffTap(String role, String status) async {
    final b = _bundle;
    if (b == null) return;
    if (attendanceNeedsReason(status)) {
      final reason = await _pickAbsenceReason();
      if (reason == null || !mounted) return;
      await _mutate(() => _service.updateStaffAttendance(b.duty.id, role, status, absenceReason: reason));
      return;
    }
    await _mutate(() => _service.updateStaffAttendance(b.duty.id, role, status));
  }

  Future<String?> _pickAbsenceReason() => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => _SheetBody(
          title: ctx.t('duty.absenceReason'),
          children: [
            TapGrid(
              columns: 2,
              children: [
                for (final r in kAbsenceReasons)
                  BigTapButton(
                    label: ctx.t('duty.absence.$r'),
                    selected: false,
                    tone: DutyTone.muted,
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
          ],
        ),
      );

  Future<void> _openCheck(String key) async {
    final b = _bundle;
    if (b == null) return;
    final existing = checkRowFor(b, key);
    final res = await showModalBottomSheet<({String status, String? preset})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckSheet(checkKey: key, initialStatus: existing?.status ?? 'not_checked', initialPreset: existing?.problemPreset),
    );
    if (res == null || !mounted) return;
    await _mutate(() => _service.updateSystemCheck(b.duty.id, key, res.status, problemPreset: res.preset));
  }

  Future<void> _openIncident(String category) async {
    final b = _bundle;
    if (b == null) return;
    final res = await showModalBottomSheet<_IncidentDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IncidentSheet(category: category, flats: _store.flats.map((f) => f.flatNumber).toList()),
    );
    if (res == null || !mounted) return;
    await _mutate(
      () => _service.addIncident(
        b.duty.id,
        category: category,
        severity: res.severity,
        flatNumber: res.flat,
        problemPreset: res.preset,
        photoUrls: res.photos,
      ),
      successKey: 'duty.incidentSaved',
    );
  }

  Future<void> _submit() async {
    final b = _bundle;
    if (b == null) return;
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('duty.submitTitle'),
      message: context.t('duty.submitDesc'),
      confirmLabel: context.t('duty.submitConfirm'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    await _mutate(() => _service.submitDuty(b.duty.id), successKey: 'duty.submitted');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading && _bundle == null) {
      return const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()));
    }
    final b = _bundle;
    if (_failed || b == null) {
      return PageContainer(
        onRefresh: _load,
        children: [
          const SizedBox(height: 40),
          Text(context.t('duty.loadError'), textAlign: TextAlign.center, style: TextStyle(color: t.destructive)),
          const SizedBox(height: 12),
          Center(
            child: AppButton.secondary(
              label: context.t('mobile.retry'),
              icon: Icons.refresh,
              expand: false,
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
            ),
          ),
        ],
      );
    }

    final submitted = b.duty.isSubmitted;
    final disabled = submitted || _saving;
    final date = parseDutyDate(b.duty.dutyDate);

    return PageContainer(
      onRefresh: _load,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 24, color: t.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(context.t('duty.title'), style: AppText.pageTitle(context))),
            if (_saving) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${date == null ? b.duty.dutyDate : DateFormat('dd MMM yyyy').format(date)} · ${widget.session.guard.name}',
          style: AppText.body(context).copyWith(color: t.mutedForeground),
        ),
        if (submitted)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: t.success),
                const SizedBox(width: 4),
                Text(context.t('duty.alreadySubmitted'), style: TextStyle(fontSize: 12, color: t.success)),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Staff attendance
        _Section(
          icon: Icons.groups_outlined,
          title: context.t('duty.staffTitle'),
          hint: context.t('duty.staffHint'),
          children: [
            for (final role in kStaffRoles) ...[
              _StaffRow(
                role: role,
                status: staffRowFor(b, role.key)?.status ?? 'not_marked',
                disabled: disabled,
                onTap: (s) => _staffTap(role.key, s),
              ),
              if (role != kStaffRoles.last) const SizedBox(height: 12),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Building checks
        _Section(
          icon: Icons.build_outlined,
          title: context.t('duty.checksTitle'),
          hint: context.t('duty.checksHint'),
          children: [
            TapGrid(
              columns: 3,
              children: [
                for (final item in kSystemChecks)
                  _CheckTile(
                    item: item,
                    status: checkRowFor(b, item.key)?.status ?? 'not_checked',
                    disabled: disabled,
                    onTap: () => _openCheck(item.key),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Incidents
        _Section(
          icon: Icons.warning_amber_rounded,
          iconColor: t.destructive,
          title: context.t('duty.incidentTitle'),
          hint: context.t('duty.incidentHint'),
          children: [
            TapGrid(
              columns: 3,
              children: [
                for (final cat in kIncidentCategories)
                  _CategoryTile(item: cat, disabled: disabled, onTap: () => _openIncident(cat.key)),
              ],
            ),
            if (b.incidents.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: t.border),
              const SizedBox(height: 12),
              Text(
                context.t('duty.todayIncidents'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.mutedForeground),
              ),
              const SizedBox(height: 8),
              for (final inc in b.incidents)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.tint(t.muted, 0.4),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Text(findIcon(kIncidentCategories, inc.category)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            context.t('duty.incident.${inc.category}'),
                            if ((inc.flatNumber ?? '').isNotEmpty) inc.flatNumber!,
                            if ((inc.problemPreset ?? '').isNotEmpty) context.t('duty.preset.${inc.problemPreset}'),
                          ].join(' · '),
                          style: AppText.body(context),
                        ),
                      ),
                      if (inc.photoUrls.isNotEmpty) ...[
                        Icon(Icons.photo_outlined, size: 14, color: t.mutedForeground),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        context.t('duty.severity.${inc.severity}').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.mutedForeground),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
        if (!submitted) ...[
          const SizedBox(height: 20),
          AppButton(
            label: context.t('duty.submitShift'),
            icon: Icons.upload_rounded,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.hint, required this.children, this.iconColor});

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? t.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.foreground))),
            ],
          ),
          const SizedBox(height: 8),
          Text(hint, style: AppText.caption(context)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.role, required this.status, required this.disabled, required this.onTap});

  final DutyItem role;
  final String status;
  final bool disabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tone = dutyStatusTone(status);
    final c = dutyToneColors(context, tone, fillOpacity: 0.1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone == DutyTone.none ? null : c.fill,
        border: Border.all(color: tone == DutyTone.none ? t.border : AppTokens.tint(c.border, 0.5)),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(role.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Text(context.t('duty.staff.${role.key}'), style: AppText.bodyMedium(context))),
              if (status != 'not_marked')
                Text(
                  context.t('duty.attendance.$status').toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TapGrid(
            columns: 4,
            children: [
              for (final opt in kAttendanceOptions)
                BigTapButton(
                  icon: opt.icon,
                  label: context.t('duty.attendance.${opt.status}'),
                  selected: status == opt.status,
                  tone: opt.tone,
                  disabled: disabled,
                  onTap: () => onTap(opt.status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.item, required this.status, required this.disabled, required this.onTap});

  final DutyItem item;
  final String status;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tone = dutyStatusTone(status);
    final c = dutyToneColors(context, tone, fillOpacity: 0.1);
    return _Tile(
      emoji: item.icon,
      label: context.t('duty.check.${item.key}'),
      sub: status == 'not_checked' ? null : context.t('duty.checkStatus.$status').toUpperCase(),
      border: tone == DutyTone.none ? t.border : AppTokens.tint(c.border, 0.5),
      fill: tone == DutyTone.none ? t.card : c.fill,
      disabled: disabled,
      onTap: onTap,
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.item, required this.disabled, required this.onTap});

  final DutyItem item;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Tile(
      emoji: item.icon,
      label: context.t('duty.incident.${item.key}'),
      labelSize: 11,
      border: t.border,
      fill: t.card,
      disabled: disabled,
      onTap: onTap,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.emoji,
    required this.label,
    required this.border,
    required this.fill,
    required this.disabled,
    required this.onTap,
    this.sub,
    this.labelSize = 12,
  });

  final String emoji;
  final String label;
  final String? sub;
  final Color border;
  final Color fill;
  final bool disabled;
  final VoidCallback onTap;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24, height: 1.1)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600, height: 1.15, color: t.foreground),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.mutedForeground)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Padded, scrollable bottom-sheet body with a title (web dialog content).
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.pageTitle(context).copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckSheet extends StatefulWidget {
  const _CheckSheet({required this.checkKey, required this.initialStatus, this.initialPreset});

  final String checkKey;
  final String initialStatus;
  final String? initialPreset;

  @override
  State<_CheckSheet> createState() => _CheckSheetState();
}

class _CheckSheetState extends State<_CheckSheet> {
  late String _status = widget.initialStatus;
  late String? _preset = widget.initialPreset;

  @override
  Widget build(BuildContext context) {
    final presets = kProblemPresets[widget.checkKey] ?? const <String>[];
    return _SheetBody(
      title: context.t('duty.check.${widget.checkKey}'),
      children: [
        TapGrid(
          columns: 3,
          children: [
            for (final opt in kCheckStatusOptions)
              BigTapButton(
                icon: opt.icon,
                label: context.t('duty.checkStatus.${opt.status}'),
                selected: _status == opt.status,
                tone: opt.tone,
                onTap: () => setState(() => _status = opt.status),
              ),
          ],
        ),
        if (checkNeedsPreset(_status) && presets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('duty.pickProblem'), style: AppText.caption(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                PresetChip(label: context.t('duty.preset.$p'), selected: _preset == p, onTap: () => setState(() => _preset = p)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: context.t('duty.saveCheck'),
          onPressed: () => Navigator.pop(context, (status: _status, preset: _preset)),
        ),
      ],
    );
  }
}

class _IncidentDraft {
  const _IncidentDraft({required this.severity, this.preset, this.flat, this.photos = const []});

  final String severity;
  final String? preset;
  final String? flat;
  final List<String> photos;
}

class _IncidentSheet extends StatefulWidget {
  const _IncidentSheet({required this.category, required this.flats});

  final String category;
  final List<String> flats;

  @override
  State<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<_IncidentSheet> {
  String _severity = 'medium';
  String? _preset;
  String? _flat;
  List<String> _photos = const [];

  @override
  Widget build(BuildContext context) {
    final presets = kIncidentPresets[widget.category] ?? const <String>[];
    return _SheetBody(
      title: context.t('duty.incident.${widget.category}'),
      children: [
        Text(context.t('duty.pickSeverity'), style: AppText.caption(context)),
        const SizedBox(height: 8),
        TapGrid(
          columns: 3,
          children: [
            for (final opt in kSeverityOptions)
              BigTapButton(
                icon: opt.icon,
                label: context.t('duty.severity.${opt.severity}'),
                selected: _severity == opt.severity,
                tone: opt.tone,
                onTap: () => setState(() => _severity = opt.severity),
              ),
          ],
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('duty.pickProblem'), style: AppText.caption(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                PresetChip(label: context.t('duty.preset.$p'), selected: _preset == p, onTap: () => setState(() => _preset = p)),
            ],
          ),
        ],
        if (widget.flats.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('duty.pickFlat'), style: AppText.caption(context)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 128),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PresetChip(label: context.t('duty.noFlat'), selected: _flat == null, onTap: () => setState(() => _flat = null)),
                  for (final f in widget.flats.take(40))
                    PresetChip(label: f, mono: true, selected: _flat == f, onTap: () => setState(() => _flat = f)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        PhotoCapture(
          photos: _photos,
          onChanged: (p) => setState(() => _photos = p),
          maxPhotos: 2,
          label: context.t('duty.photoOptional'),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: context.t('duty.saveIncident'),
          onPressed: () => Navigator.pop(
            context,
            _IncidentDraft(severity: _severity, preset: _preset, flat: _flat, photos: _photos),
          ),
        ),
      ],
    );
  }
}
