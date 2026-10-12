import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/gate_actor.dart';
import '../../core/ui/ui.dart';
import 'data/gate_logic.dart';
import 'data/gate_models.dart';
import 'data/gate_store.dart';
import 'gate_i18n.dart';
import 'widgets/approval_request_dialog.dart';
import 'widgets/otp_verify_dialog.dart';
import 'widgets/photo_capture.dart';

/// New visitor entry — web `src/pages/VisitorEntryPage.tsx`: phone first (suggestions from
/// earlier visits, blacklist + repeat-visit alerts, pre-fill from the previous visit), name,
/// flat, purpose, document type / number, visitor + document photos, vehicle, "Ask Permission"
/// (resident approval with realtime wait) and "Verify OTP" for resident pre-approved passes.
class VisitorEntryView extends StatefulWidget {
  const VisitorEntryView({super.key, required this.actor, this.onDone});

  final GateActor actor;

  /// Called 1.6 s after a successful entry (web returns to the dashboard).
  final VoidCallback? onDone;

  @override
  State<VisitorEntryView> createState() => _VisitorEntryViewState();
}

class _VisitorEntryViewState extends State<VisitorEntryView> {
  late final GateStore _store = GateStore.of(widget.actor.societyId);
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _flat = TextEditingController();
  final _docNumber = TextEditingController();
  final _vehicle = TextEditingController();

  String _purpose = 'Visit';
  String _docType = 'aadhaar';
  bool _hasVehicle = false;
  List<String> _visitorPhotos = const [];
  List<String> _documentPhoto = const [];
  bool _blacklisted = false;
  int _repeatCount = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    _name.addListener(_refresh);
    _flat.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_phone, _name, _flat, _docNumber, _vehicle]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Web `update('phone', value)`: checks run once 10 digits are typed.
  void _onPhoneChanged(String value) {
    if (value.length >= 10) {
      _checkPhone(value, prefill: true);
    } else {
      setState(() {
        _blacklisted = false;
        _repeatCount = 0;
      });
    }
  }

  void _checkPhone(String phone, {required bool prefill}) {
    final blacklisted = _store.isBlacklisted(phone: phone);
    final repeat = visitsOnDayForPhone(_store.visitors, phone, Fmt.todayIso());
    if (prefill) {
      final prev = previousVisitFor(_store.visitors, phone);
      if (prev != null) {
        final p = prefillFromPrevious(
          name: _name.text,
          documentType: _docType,
          documentNumber: _docNumber.text,
          flatNumber: _flat.text,
          prev: prev,
        );
        _name.text = p.name;
        _docNumber.text = p.documentNumber;
        _flat.text = p.flatNumber;
        _docType = _validDocType(p.documentType);
      }
    }
    setState(() {
      _blacklisted = blacklisted;
      _repeatCount = repeat;
    });
  }

  String _validDocType(String v) =>
      kDocumentTypes.any((d) => d.value == v) ? v : 'other';

  void _pickSuggestion(GateVisitor s) {
    _phone.text = s.phone;
    _name.text = s.name;
    _docNumber.text = s.documentNumber;
    _flat.text = s.flatNumber;
    _docType = _validDocType(s.documentType);
    // The web skips the checks here; running them keeps the blacklist warning reliable.
    _checkPhone(s.phone, prefill: false);
  }

  void _reset() {
    for (final c in [_phone, _name, _flat, _docNumber, _vehicle]) {
      c.clear();
    }
    setState(() {
      _purpose = 'Visit';
      _docType = 'aadhaar';
      _hasVehicle = false;
      _blacklisted = false;
      _repeatCount = 0;
      _visitorPhotos = const [];
      _documentPhoto = const [];
    });
  }

  Future<void> _register(
      {String? overrideName,
      String? overrideFlat,
      String? overridePhone}) async {
    final name =
        (overrideName?.isNotEmpty ?? false) ? overrideName! : _name.text.trim();
    final flat =
        (overrideFlat?.isNotEmpty ?? false) ? overrideFlat! : _flat.text.trim();
    final phone = (overridePhone?.isNotEmpty ?? false)
        ? overridePhone!
        : _phone.text.trim();
    if (name.isEmpty || phone.isEmpty || flat.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.visitor.required'),
          tone: BadgeTone.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await _store.addVisitor(buildVisitorEntry(
        name: name,
        phone: phone,
        flatNumber: flat,
        purpose: _purpose,
        documentType: _docType,
        documentNumber: _docNumber.text.trim(),
        documentPhoto: _documentPhoto.isEmpty ? null : _documentPhoto.first,
        visitorPhotos: _visitorPhotos,
        hasVehicle: _hasVehicle,
        vehicleNumber: _vehicle.text,
        guardId: widget.actor.actorId,
        guardName: widget.actor.actorName,
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.toast(context, context.gt('gate.saveFailed'),
            tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _reset();
    final done = widget.onDone;
    if (done != null) Future.delayed(const Duration(milliseconds: 1600), done);
    await AppFeedback.success(context,
        title: context.t('swal.success'),
        message: context.t('swal.visitorRegistered'));
  }

  Future<void> _askPermission() async {
    final outcome = await ApprovalRequestDialog.show(
      context,
      actor: widget.actor,
      visitorName: _name.text.trim(),
      visitorPhone: _phone.text.trim(),
      flatNumber: _flat.text.trim(),
      purpose: _purpose,
    );
    if (outcome == ApprovalOutcome.approved && mounted) await _register();
  }

  Future<void> _verifyOtp() async {
    final pass =
        await OtpVerifyDialog.show(context, societyId: widget.actor.societyId);
    if (pass == null || !mounted) return;
    AppFeedback.toast(context, context.t('otp.validPass'),
        tone: BadgeTone.success);
    await _register(
      overrideName: pass.guestName,
      overrideFlat: pass.flatNumber,
      overridePhone:
          pass.guestPhone.isEmpty ? kPassPlaceholderPhone : pass.guestPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final phone = _phone.text;
        final suggestions = phoneSuggestions(_store.visitors, phone);
        final canAsk =
            _name.text.trim().isNotEmpty && _flat.text.trim().isNotEmpty;
        return PageContainer(
          children: [
            PageHeader(
              icon: Icons.person_add_alt_1_outlined,
              title: context.t('visitor.title'),
              subtitle: context.t('visitor.subtitle'),
              bottomSpacing: 24,
              actions: [
                AppButton(
                  label: context.t('otp.verifyPass'),
                  icon: Icons.key_rounded,
                  variant: AppButtonVariant.accent,
                  dense: true,
                  expand: false,
                  onPressed: _verifyOtp,
                ),
              ],
            ),
            if (_blacklisted)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: NoticeBanner(
                  message: '⚠ ${context.t('visitor.blacklisted')}',
                  tone: BadgeTone.alert,
                  icon: Icons.gpp_maybe_outlined,
                ),
              )
            else if (_repeatCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: NoticeBanner(
                  message:
                      '⚠ ${context.t('visitor.repeatAlert')} $_repeatCount${context.t('visitor.timesToday')}',
                  tone: BadgeTone.warning,
                ),
              ),
            AppTextField(
              label: context.t('visitor.phoneNumber'),
              required: true,
              controller: _phone,
              hint: context.gt('gate.visitor.phonePlaceholder'),
              keyboardType: TextInputType.phone,
              mono: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ],
              onChanged: _onPhoneChanged,
            ),
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final s in suggestions)
                      Material(
                        color: t.secondary,
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _pickSuggestion(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search,
                                    size: 12, color: t.secondaryForeground),
                                const SizedBox(width: 4),
                                Text('${s.name} · ${s.phone}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: t.secondaryForeground)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            AppTextField(
                label: context.t('visitor.fullName'),
                required: true,
                controller: _name,
                hint: context.t('visitor.fullName')),
            const SizedBox(height: 16),
            AppTextField(
              label: context.t('visitor.flatNumber'),
              required: true,
              controller: _flat,
              hint: context.gt('gate.visitor.flatPlaceholder'),
              mono: true,
            ),
            const SizedBox(height: 16),
            FieldLabel(context.t('visitor.purpose')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in kVisitorPurposes)
                  PillChoice(
                      label: context.t(p.key),
                      selected: _purpose == p.value,
                      onTap: () => setState(() => _purpose = p.value)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppDropdown<String>(
                    label: context.t('visitor.docType'),
                    items: [for (final d in kDocumentTypes) d.value],
                    value: _docType,
                    labelOf: (v) {
                      final d = kDocumentTypes.firstWhere((x) => x.value == v);
                      return context.tr(d.en, d.hi);
                    },
                    onChanged: (v) => setState(() => _docType = v ?? 'aadhaar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: context.t('visitor.docNumber'),
                    controller: _docNumber,
                    hint: context.gt('gate.visitor.docPlaceholder'),
                    mono: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PhotoCapture(
              photos: _visitorPhotos,
              onChanged: (p) => setState(() => _visitorPhotos = p),
              maxPhotos: 3,
              label: context.t('visitor.visitorPhotos'),
            ),
            const SizedBox(height: 16),
            PhotoCapture(
              photos: _documentPhoto,
              onChanged: (p) => setState(() => _documentPhoto = p),
              maxPhotos: 1,
              label: context.t('visitor.documentPhoto'),
            ),
            const SizedBox(height: 8),
            ToggleRow(
              label: context.t('visitor.hasVehicle'),
              value: _hasVehicle,
              onChanged: (v) => setState(() => _hasVehicle = v),
            ),
            if (_hasVehicle) ...[
              const SizedBox(height: 8),
              AppTextField(
                label: context.t('visitor.vehicleNumber'),
                controller: _vehicle,
                hint: context.gt('gate.visitor.vehiclePlaceholder'),
                mono: true,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (canAsk) ...[
                  Expanded(
                    child: AppButton(
                      label: context.t('approval.askPermission'),
                      icon: Icons.send_rounded,
                      variant: AppButtonVariant.accent,
                      onPressed: _saving ? null : _askPermission,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: AppButton(
                    label: context.t('visitor.logEntry'),
                    icon: Icons.photo_camera_outlined,
                    loading: _saving,
                    onPressed: () => _register(),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
