import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import '../../../providers/branding_provider.dart';
import '../data/image_upload.dart';
import '../data/superadmin_biometric.dart';
import '../data/superadmin_models.dart';
import '../logic/js_compat.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/color_picker.dart';
import '../widgets/sa_widgets.dart';
import 'tab_page.dart';

/// Web defaults of the Settings tab branding form.
const _kDefaultBranding = {
  'app_name': 'Kutumbika',
  'tagline': '— parivaar jaisi society —',
  'logo_url': '',
  'primary_color': '#14B8A6',
  'primary_dark_color': '#0F766E',
  'background_color': '#F0FAFA',
};

/// Web Settings tab: authenticator (TOTP) on/off, recovery e-mail, biometric devices,
/// mobile app branding (`platform_branding`), plus language / theme on the phone.
/// Data is re-read every time the tab is opened (web `useEffect([tab])`).
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key, required this.ctx, required this.active});

  final SuperadminTabContext ctx;
  final bool active;

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final _recoveryEmail = TextEditingController();
  final _appName = TextEditingController(text: _kDefaultBranding['app_name']);
  final _tagline = TextEditingController(text: _kDefaultBranding['tagline']);
  final _bio = SuperadminBiometric();

  bool _totpEnabled = false;
  bool _totpConfigured = false;
  bool _totpSaving = false;
  bool _recoverySaving = false;
  String _logoUrl = '';
  String _primary = _kDefaultBranding['primary_color']!;
  String _primaryDark = _kDefaultBranding['primary_dark_color']!;
  String _background = _kDefaultBranding['background_color']!;
  PickedImage? _pendingLogo;
  bool _brandingSaving = false;

  bool _bioAvailable = false;
  bool _bioLoading = false;
  List<BiometricDevice> _devices = const [];
  String? _removingId;

  String get _id => widget.ctx.session.id;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(SettingsTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  @override
  void dispose() {
    _recoveryEmail.dispose();
    _appName.dispose();
    _tagline.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = SuperadminScope.read(context).repo;
    try {
      final sec = await repo.fetchSecurity(_id);
      if (mounted) {
        setState(() {
          _recoveryEmail.text =
              (sec?['recovery_email'] as String?)?.trim() ?? '';
          _totpEnabled = sec?['totp_enabled'] == true;
          _totpConfigured =
              (sec?['totp_secret'] as String?)?.isNotEmpty ?? false;
        });
      }
    } catch (_) {}
    try {
      final b = await repo.fetchBranding();
      if (b != null && mounted) {
        setState(() {
          _appName.text =
              (b['app_name'] as String?) ?? _kDefaultBranding['app_name']!;
          _tagline.text =
              (b['tagline'] as String?) ?? _kDefaultBranding['tagline']!;
          _logoUrl = (b['logo_url'] as String?) ?? '';
          _primary = (b['primary_color'] as String?) ??
              _kDefaultBranding['primary_color']!;
          _primaryDark = (b['primary_dark_color'] as String?) ??
              _kDefaultBranding['primary_dark_color']!;
          _background = (b['background_color'] as String?) ??
              _kDefaultBranding['background_color']!;
          _pendingLogo = null;
        });
      }
    } catch (_) {}
    await _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final available = await _bio.isAvailable();
    var devices = const <BiometricDevice>[];
    if (available) {
      try {
        devices = await _bio.listCredentials(_id);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _devices = devices;
      });
    }
  }

  Future<void> _toggleTotp(bool on) async {
    if (_totpSaving) return;
    if (!on) {
      final ok = await AppFeedback.confirm(
        context,
        title: context.st('sa.set.disableTotpTitle'),
        message: context.st('sa.set.disableTotpText'),
        confirmLabel: context.st('sa.set.disable'),
        cancelLabel: context.t('swal.no'),
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _totpSaving = true);
    String? err;
    try {
      await SuperadminScope.read(context).repo.updateSuperAdmin(
            _id,
            on
                ? {'totp_enabled': true}
                : {'totp_enabled': false, 'totp_secret': null},
          );
    } catch (e) {
      err = '$e';
    }
    if (!mounted) return;
    setState(() => _totpSaving = false);
    if (err != null) {
      AppFeedback.toast(context, context.st('sa.set.totpUpdateFailed'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() {
      _totpEnabled = on;
      if (!on) _totpConfigured = false;
    });
    AppFeedback.toast(
        context,
        on
            ? context.st('sa.set.totpEnabled')
            : context.st('sa.set.totpDisabled'),
        tone: BadgeTone.success);
  }

  Future<void> _saveRecovery() async {
    final em = _recoveryEmail.text.trim().toLowerCase();
    if (em.isEmpty || !isValidEmail(em)) {
      AppFeedback.toast(context, context.t('superadmin.invalidRecoveryEmail'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _recoverySaving = true);
    var ok = true;
    try {
      await SuperadminScope.read(context)
          .repo
          .updateSuperAdmin(_id, {'recovery_email': em});
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _recoverySaving = false);
    AppFeedback.toast(
      context,
      ok
          ? context.t('superadmin.recoveryEmailSaved')
          : context.t('superadmin.couldNotSaveRecovery'),
      tone: ok ? BadgeTone.success : BadgeTone.alert,
    );
  }

  Future<void> _registerBio() async {
    setState(() => _bioLoading = true);
    final ok = await _bio.register(_id, widget.ctx.session.name);
    if (!mounted) return;
    setState(() => _bioLoading = false);
    AppFeedback.toast(
      context,
      ok
          ? context.t('biometric.registered')
          : context.t('biometric.registerFailed'),
      tone: ok ? BadgeTone.success : BadgeTone.alert,
    );
    await _loadBiometric();
  }

  Future<void> _removeDevice(BiometricDevice d) async {
    setState(() => _removingId = d.id);
    final ok = await _bio.removeCredential(d, _id);
    if (!mounted) return;
    setState(() => _removingId = null);
    AppFeedback.toast(
      context,
      ok
          ? context.st('sa.set.deviceRemoved')
          : context.st('sa.set.deviceRemoveFailed'),
      tone: ok ? BadgeTone.success : BadgeTone.alert,
    );
    await _loadBiometric();
  }

  Future<void> _pickAppLogo() async {
    try {
      final f =
          await SuperadminImagePicker.pickOne(source: ImageSource.gallery);
      if (f != null && mounted) setState(() => _pendingLogo = f);
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.st('sa.pick.failed'),
            tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _saveBranding() async {
    setState(() => _brandingSaving = true);
    final repo = SuperadminScope.read(context).repo;
    final saved = context.t('superadmin.mobileBrandingSaved');
    final failed = context.t('superadmin.mobileBrandingSaveFailed');
    try {
      String? logoUrl = _logoUrl.trim().isEmpty ? null : _logoUrl.trim();
      if (_pendingLogo != null) {
        final uploaded = await SuperadminUploads(onError: (m) {
          if (mounted) AppFeedback.toast(context, m, tone: BadgeTone.alert);
        }).platformLogo(_pendingLogo!);
        if (uploaded != null) logoUrl = uploaded;
      }
      await repo.upsertBranding({
        'app_name':
            _appName.text.trim().isEmpty ? 'Kutumbika' : _appName.text.trim(),
        'tagline': _tagline.text.trim().isEmpty ? null : _tagline.text.trim(),
        'logo_url': logoUrl,
        'primary_color': _primary,
        'primary_dark_color': _primaryDark,
        'background_color': _background,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _logoUrl = logoUrl ?? '';
        _pendingLogo = null;
      });
      AppFeedback.toast(context, saved, tone: BadgeTone.success);
      await ref.read(platformBrandingProvider.notifier).refresh();
    } catch (_) {
      if (mounted) AppFeedback.toast(context, failed, tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _brandingSaving = false);
    }
  }

  Widget _card(IconData icon, String title, List<Widget> children) =>
      CardSection(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(title, icon: icon),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final thisDeviceRegistered = _devices.any((d) => d.thisDevice);
    return SuperadminTabPage(
      ctx: widget.ctx,
      onRefresh: _load,
      children: [
        SaTabTitle(context.t('nav.settings')),
        _card(Icons.shield_outlined, context.st('sa.set.totpTitle'), [
          Text(context.st('sa.set.totpText'), style: AppText.caption(context)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _totpEnabled
                              ? context.st('sa.set.enabled')
                              : context.st('sa.set.disabled'),
                          style: AppText.bodyMedium(context)),
                      Text(
                        _totpConfigured
                            ? context.st('sa.set.totpConfigured')
                            : context.st('sa.set.totpNotConfigured'),
                        style: AppText.tiny(context),
                      ),
                    ],
                  ),
                ),
                Switch(
                    value: _totpEnabled,
                    onChanged: _totpSaving ? null : _toggleTotp),
              ],
            ),
          ),
          if (_totpEnabled && !_totpConfigured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.st('sa.set.totpPending'),
                  style: TextStyle(fontSize: 10, color: t.warning)),
            ),
        ]),
        _card(
            Icons.mail_outline, context.t('superadmin.recoveryEmailSettings'), [
          Text(context.t('superadmin.recoveryEmailStepHelp'),
              style: AppText.caption(context)),
          const SizedBox(height: 12),
          AppTextField(
              controller: _recoveryEmail,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              caps: false),
          const SizedBox(height: 12),
          AppButton(
            label: _recoverySaving
                ? '…'
                : context.t('superadmin.saveRecoveryEmail'),
            onPressed: _recoverySaving ? null : _saveRecovery,
          ),
        ]),
        if (_bioAvailable)
          _card(Icons.fingerprint, context.t('biometric.title'), [
            Text(
              '${context.t('biometric.subtitle')} (${_devices.length}/${SuperadminBiometric.maxCredentialsPerUser} ${context.st('sa.set.devices')})',
              style: AppText.caption(context),
            ),
            const SizedBox(height: 12),
            if (thisDeviceRegistered)
              Row(
                children: [
                  Icon(Icons.check, size: 16, color: t.success),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(context.t('biometric.enabled'),
                          style: TextStyle(fontSize: 14, color: t.success))),
                ],
              )
            else
              AppButton(
                label: _bioLoading
                    ? context.t('biometric.registering')
                    : context.t('biometric.enable'),
                loading: _bioLoading,
                onPressed: _bioLoading ? null : _registerBio,
              ),
            if (_devices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: t.border),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                child: Column(
                  children: [
                    for (var i = 0; i < _devices.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: t.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${context.st('sa.set.device')} ${i + 1} (${_devices[i].shortId}...)'
                                    '${_devices[i].thisDevice ? ' · ${context.st('sa.set.thisDevice')}' : ''}',
                                    style: AppText.caption(context).copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: t.foreground),
                                  ),
                                  Text(
                                      '${context.st('sa.set.added')} ${Fmt.dateTimeFull(_devices[i].createdAt)}',
                                      style: AppText.tiny(context)),
                                ],
                              ),
                            ),
                            SaLinkButton(
                              label: _removingId == _devices[i].id
                                  ? context.st('sa.set.removing')
                                  : context.st('sa.set.remove'),
                              color: t.destructive,
                              onTap: _removingId == null
                                  ? () => _removeDevice(_devices[i])
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_devices.length >= SuperadminBiometric.maxCredentialsPerUser)
              SaHint(context.st('sa.set.maxDevices',
                  {'max': SuperadminBiometric.maxCredentialsPerUser})),
          ]),
        _card(
            Icons.smartphone_outlined, context.t('superadmin.mobileBranding'), [
          Text(context.t('superadmin.mobileBrandingHelp'),
              style: AppText.caption(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_pendingLogo != null || _logoUrl.isNotEmpty) ...[
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.border),
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                  ),
                  child: _pendingLogo != null
                      ? Image.memory(_pendingLogo!.bytes, fit: BoxFit.contain)
                      : SaNetImage(_logoUrl,
                          width: 48, height: 48, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
              ],
              AppButton.secondary(
                label: context.t('superadmin.uploadAppLogo'),
                icon: Icons.image_outlined,
                dense: true,
                expand: false,
                onPressed: _brandingSaving ? null : _pickAppLogo,
              ),
            ],
          ),
          if (_pendingLogo != null)
            SaHint(
                '${_pendingLogo!.name} — ${context.t('superadmin.logoUploadOnSave')}'),
          const SizedBox(height: 12),
          AppTextField(
              controller: _appName,
              hint: context.t('superadmin.appName'),
              label: context.t('superadmin.appName'),
              caps: false),
          const SizedBox(height: 12),
          AppTextField(
              controller: _tagline,
              hint: context.t('superadmin.appTagline'),
              label: context.t('superadmin.appTagline'),
              caps: false),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ColorSwatchField(
                  label: context.t('superadmin.primaryColor'),
                  value: _primary,
                  onChanged: (v) => setState(() => _primary = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ColorSwatchField(
                  label: context.t('superadmin.primaryDarkColor'),
                  value: _primaryDark,
                  onChanged: (v) => setState(() => _primaryDark = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ColorSwatchField(
                  label: context.t('superadmin.backgroundColor'),
                  value: _background,
                  onChanged: (v) => setState(() => _background = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: _brandingSaving
                ? '…'
                : context.t('superadmin.saveMobileBranding'),
            loading: _brandingSaving,
            onPressed: _brandingSaving ? null : _saveBranding,
          ),
        ]),
        _card(Icons.tune, context.st('sa.set.appPrefs'), [
          Row(
            children: [
              Expanded(
                  child: Text(context.st('sa.set.language'),
                      style: AppText.body(context))),
              const LanguageToggle(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: Text(context.st('sa.set.theme'),
                      style: AppText.body(context))),
              const ThemeToggle(),
            ],
          ),
        ]),
      ],
    );
  }
}
