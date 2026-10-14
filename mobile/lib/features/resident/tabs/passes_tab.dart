import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/pass_rules.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';
import '../widgets/resident_i18n.dart';
import '../widgets/resident_widgets.dart';

/// Visitor passes tab — web `tab === 'passes'` (OTP guest passes), plus WhatsApp share and
/// cancel on mobile.
class ResidentPassesTab extends StatefulWidget {
  const ResidentPassesTab({super.key, required this.session});

  final SessionResident session;

  @override
  State<ResidentPassesTab> createState() => _ResidentPassesTabState();
}

class _ResidentPassesTabState extends State<ResidentPassesTab> {
  final _repo = const ResidentRepository();
  final _guestName = TextEditingController();
  final _guestPhone = TextEditingController();
  List<VisitorPassRow> _passes = const [];
  bool _loading = true;
  bool _failed = false;
  bool _showForm = false;
  bool _saving = false;
  String _validDate = Fmt.todayIso();
  String _from = '09:00';
  String _to = '18:00';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _guestName.dispose();
    _guestPhone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.fetchPasses(widget.session.resident.flatId);
      if (!mounted) return;
      setState(() {
        _passes = rows;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _passes.isEmpty;
      });
    }
  }

  void _resetForm() {
    _guestName.clear();
    _guestPhone.clear();
    _validDate = Fmt.todayIso();
    _from = '09:00';
    _to = '18:00';
  }

  Future<void> _create() async {
    final r = widget.session.resident;
    final otp = generatePassOtp();
    setState(() => _saving = true);
    try {
      await _repo.createPass(
        otp: otp,
        flatId: r.flatId,
        flatNumber: r.flatNumber,
        residentId: r.id,
        residentName: r.name,
        guestName: _guestName.text.trim(),
        guestPhone: _guestPhone.text.trim(),
        validDate: _validDate,
        timeStart: _from,
        timeEnd: _to,
      );
      if (!mounted) return;
      final guest = _guestName.text.trim();
      final phone = _guestPhone.text.trim();
      final date = _validDate, from = _from, to = _to;
      setState(() {
        _showForm = false;
        _saving = false;
        _resetForm();
      });
      await AppFeedback.success(context,
          title: context.t('swal.success'), message: '${context.t('resident.passCreated')} — OTP: $otp');
      await _load();
      if (!mounted) return;
      final share = await AppFeedback.confirm(
        context,
        title: context.rt('resident.m.sharePass'),
        message: 'OTP $otp${guest.isEmpty ? '' : ' · $guest'}',
        confirmLabel: context.rt('resident.m.sharePass'),
        cancelLabel: context.t('mobile.close'),
      );
      if (share && mounted) {
        await _share(otp: otp, guestName: guest, guestPhone: phone, validDate: date, from: from, to: to);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _share(
      {required String otp,
      String? guestName,
      String? guestPhone,
      required String validDate,
      String? from,
      String? to}) async {
    final msg = passShareMessage(
      otp: otp,
      flatNumber: widget.session.resident.flatNumber,
      societyName: widget.session.societyName,
      validDate: validDate,
      guestName: guestName,
      start: from,
      end: to,
      hindi: context.lang == AppLang.hi,
    );
    final ok = await ExportKit.openWhatsApp(msg, phone: guestPhone);
    if (!ok && mounted) {
      AppFeedback.toast(context, context.tr('WhatsApp is not available', 'व्हाट्सऐप उपलब्ध नहीं है'),
          tone: BadgeTone.alert);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) await AppFeedback.success(context, title: context.tr('Copied!', 'कॉपी हो गया!'), message: code);
  }

  Future<void> _cancel(VisitorPassRow p) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.rt('resident.m.cancelPassConfirm'),
      message: context.rt('resident.m.cancelPassText', {'otp': p.otpCode}),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.cancelPass(id: p.id, flatId: widget.session.resident.flatId);
      if (mounted) AppFeedback.toast(context, context.rt('resident.m.passCancelled'), tone: BadgeTone.success);
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  BadgeTone _tone(String status) => switch (status) {
        'active' => BadgeTone.success,
        'used' => BadgeTone.neutral,
        _ => BadgeTone.alert,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          title: context.t('resident.passes'),
          subtitle: context.tr('OTP passes for guests you are expecting', 'अपेक्षित मेहमानों के लिए ओटीपी पास'),
          icon: Icons.key_outlined,
        ),
        AppButton(
          label: context.t('resident.createPass'),
          icon: _showForm ? Icons.close : Icons.add,
          onPressed: () => setState(() => _showForm = !_showForm),
        ),
        const SizedBox(height: 12),
        if (_showForm)
          CardSection(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppTextField(controller: _guestName, hint: context.t('resident.guestName')),
              const SizedBox(height: 12),
              AppTextField(
                controller: _guestPhone,
                hint: context.t('resident.guestPhone'),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                mono: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              ResidentDateField(
                label: context.t('resident.validDate'),
                value: _validDate,
                onChanged: (v) => setState(() => _validDate = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: ResidentTimeField(
                        label: context.t('resident.from'), value: _from, onChanged: (v) => setState(() => _from = v))),
                const SizedBox(width: 8),
                Expanded(
                    child: ResidentTimeField(
                        label: context.t('resident.to'), value: _to, onChanged: (v) => setState(() => _to = v))),
              ]),
              const SizedBox(height: 12),
              AppButton(label: context.t('resident.generateOTP'), loading: _saving, onPressed: _create),
            ]),
          ),
        if (_loading) const LoadingView(),
        if (_failed) ErrorView(onRetry: _load),
        if (!_loading && !_failed && _passes.isEmpty && !_showForm) EmptyView(message: context.t('resident.noPasses')),
        for (final p in _passes)
          Opacity(
            opacity: p.isActive ? 1 : 0.6,
            child: CardSection(
              margin: const EdgeInsets.only(bottom: 12),
              borderColor: p.isActive ? AppTokens.tint(t.primary, 0.3) : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text(p.otpCode,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.mono(context, size: 18, weight: FontWeight.w600, color: t.primary)
                                  .copyWith(letterSpacing: 4)),
                        ),
                        if (p.isActive)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: context.tr('Copy', 'कॉपी करें'),
                            icon: Icon(Icons.copy, size: 16, color: t.mutedForeground),
                            onPressed: () => _copy(p.otpCode),
                          ),
                      ]),
                      if ((p.guestName ?? '').isNotEmpty) Text(p.guestName!, style: AppText.body(context)),
                      if ((p.guestPhone ?? '').isNotEmpty)
                        Text(p.guestPhone!, style: AppText.mono(context, size: 12, color: t.mutedForeground)),
                    ]),
                  ),
                  ToneBadge(p.status, tone: _tone(p.status)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.schedule, size: 12, color: t.mutedForeground),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(passSlotLabel(validDate: p.validDate, start: p.timeSlotStart, end: p.timeSlotEnd),
                        style: AppText.caption(context)),
                  ),
                ]),
                if (p.isActive) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: context.rt('resident.m.sharePass'),
                        icon: Icons.share_outlined,
                        dense: true,
                        onPressed: () => _share(
                          otp: p.otpCode,
                          guestName: p.guestName,
                          guestPhone: p.guestPhone,
                          validDate: p.validDate,
                          from: p.timeSlotStart,
                          to: p.timeSlotEnd,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: context.rt('resident.m.cancelPass'),
                        icon: Icons.block,
                        variant: AppButtonVariant.ghost,
                        dense: true,
                        onPressed: () => _cancel(p),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
      ],
    );
  }
}
