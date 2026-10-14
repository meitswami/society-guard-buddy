import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../device/kiosk_camera.dart';
import '../device/kiosk_speech.dart';
import '../logic/kiosk_copy.dart';
import '../logic/kiosk_framing.dart';
import '../logic/kiosk_settings.dart';
import 'kiosk_camera_bubble.dart';
import 'kiosk_i18n.dart';

/// Guard-facing screen: kiosk options + device readiness, then "Start kiosk" —
/// port of web `KioskSetupPanel.tsx`.
class KioskSetupPanel extends StatefulWidget {
  const KioskSetupPanel({
    super.key,
    required this.settings,
    required this.onChange,
    required this.onStart,
    this.onBack,
  });

  final KioskSettings settings;
  final ValueChanged<KioskSettings> onChange;
  final VoidCallback onStart;
  final VoidCallback? onBack;

  @override
  State<KioskSetupPanel> createState() => _KioskSetupPanelState();
}

class _KioskSetupPanelState extends State<KioskSetupPanel> {
  KioskCheck _camera = KioskCheck.checking;
  KioskCheck _voice = KioskCheck.checking;
  KioskCheck _speech = KioskCheck.checking;
  KioskRecognizerState _recognizer = KioskRecognizerState.unknown;
  bool _testOpen = false;
  late final TextEditingController _pin = TextEditingController(text: widget.settings.exitPin);

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _runChecks() async {
    // Camera (web `enumerateDevices` → any videoinput).
    availableCameras().then((cams) {
      if (mounted) setState(() => _camera = cams.isNotEmpty ? KioskCheck.ok : KioskCheck.missing);
    }, onError: (Object _) {
      if (mounted) setState(() => _camera = KioskCheck.missing);
    });
    // Hindi voice (polls the voice list like the web).
    KioskSpeech.instance.checkVoice(kVoiceLocale[KioskLang.hi]!).then((v) {
      if (mounted) setState(() => _voice = v);
    });
    await _checkSpeech();
  }

  Future<void> _checkSpeech({bool retry = false}) async {
    if (retry) setState(() => _speech = KioskCheck.checking);
    final state = await KioskSpeech.instance.initRecognizer(retry: retry);
    if (!mounted) return;
    setState(() {
      _recognizer = state;
      _speech = state == KioskRecognizerState.ready ? KioskCheck.ok : KioskCheck.missing;
    });
  }

  void _set(KioskSettings s) => widget.onChange(s);

  void _testVoice() {
    KioskSpeech.instance
        .speak(
          kioskSpeech(KioskCopyKey.greeting, KioskLang.hi, {'society': context.t('app.name')}),
          locale: kVoiceLocale[KioskLang.hi]!,
        )
        .catchError((Object _) {});
  }

  void _start() {
    // Release the test camera before the kiosk opens its own.
    if (_testOpen) setState(() => _testOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onStart());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.settings;
    final speechHint = _recognizer == KioskRecognizerState.denied
        ? kioskT(context, 'kiosk.mobile.micDenied')
        : kioskT(context, 'kiosk.mobile.speechMissing');

    Widget switchRow(String label, bool value, ValueChanged<bool> onChanged, {String? hint}) {
      return InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: hint == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.body(context)),
                  if (hint != null) Text(hint, style: AppText.caption(context).copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
    }

    return PageContainer(
      children: [
        PageHeader(
          title: context.t('kiosk.setup.title'),
          icon: Icons.smart_toy_outlined,
          onBack: widget.onBack,
        ),
        Text(context.t('kiosk.setup.subtitle'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
        const SizedBox(height: 20),
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('kiosk.setup.defaultLang').toUpperCase(), style: AppText.fieldLabel(context)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final l in kKioskLangs) ...[
                    if (l != kKioskLangs.first) const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: s.defaultLang == l ? t.primary : t.secondary,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                          onTap: () => _set(s.copyWith(defaultLang: l)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Text(
                              l.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: s.defaultLang == l ? t.primaryForeground : t.secondaryForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switchRow(
                context.t('kiosk.setup.requireApproval'),
                s.requireApproval,
                (v) => _set(s.copyWith(requireApproval: v)),
                hint: context.t('kiosk.setup.requireApprovalHint'),
              ),
              const SizedBox(height: 12),
              switchRow(
                context.t('kiosk.setup.cloudAi'),
                s.useCloudAi,
                (v) => _set(s.copyWith(useCloudAi: v)),
                hint: context.t('kiosk.setup.cloudAiHint'),
              ),
              const SizedBox(height: 12),
              switchRow(context.t('kiosk.setup.capturePhoto'), s.capturePhoto, (v) => _set(s.copyWith(capturePhoto: v))),
              const SizedBox(height: 12),
              switchRow(context.t('kiosk.setup.askVehicle'), s.askVehicle, (v) => _set(s.copyWith(askVehicle: v))),
              const SizedBox(height: 16),
              Text(context.t('kiosk.setup.exitPin').toUpperCase(), style: AppText.fieldLabel(context)),
              const SizedBox(height: 6),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppText.mono(context, size: 15).copyWith(letterSpacing: 4),
                decoration: const InputDecoration(hintText: '••••', counterText: ''),
                onChanged: (v) => _set(s.copyWith(exitPin: v.replaceAll(RegExp(r'\D'), ''))),
              ),
              const SizedBox(height: 4),
              Text(context.t('kiosk.setup.exitPinHint'), style: AppText.caption(context).copyWith(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('kiosk.setup.checks').toUpperCase(), style: AppText.fieldLabel(context)),
              const SizedBox(height: 4),
              _CheckRow(icon: Icons.photo_camera_outlined, label: context.t('kiosk.check.camera'), state: _camera),
              _CheckRow(
                icon: Icons.mic_none_outlined,
                label: context.t('kiosk.check.speech'),
                state: _speech,
                hint: speechHint,
                action: _speech == KioskCheck.missing
                    ? _SmallButton(icon: Icons.refresh, label: kioskT(context, 'kiosk.mobile.retryMic'), onTap: () => _checkSpeech(retry: true))
                    : null,
              ),
              _CheckRow(
                icon: Icons.volume_up_outlined,
                label: context.t('kiosk.check.voice'),
                state: _voice,
                hint: context.t('kiosk.check.voiceHint'),
                action: _voice != KioskCheck.missing
                    ? _SmallButton(icon: Icons.play_arrow_rounded, label: context.t('kiosk.check.testVoice'), onTap: _testVoice)
                    : null,
              ),
              _testOpen
                  ? _CameraTest(onClose: () => setState(() => _testOpen = false))
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _testOpen = true),
                        icon: const Icon(Icons.face_unlock_outlined, size: 16),
                        label: Text(context.t('kiosk.test.open')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.foreground,
                          side: BorderSide(color: t.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(context.t('kiosk.setup.tips'), style: AppText.caption(context).copyWith(fontSize: 11)),
        const SizedBox(height: 16),
        Material(
          color: t.primary,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            onTap: _start,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_unlock_outlined, size: 20, color: t.primaryForeground),
                  const SizedBox(width: 8),
                  Text(
                    context.t('kiosk.setup.start'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.primaryForeground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: t.secondary,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: t.secondaryForeground),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.secondaryForeground)),
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

/// Web `CheckRow`.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.label, required this.state, this.hint, this.action});

  final IconData icon;
  final String label;
  final KioskCheck state;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Widget badge = switch (state) {
      KioskCheck.checking => Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: t.mutedForeground)),
          const SizedBox(width: 4),
          Text(context.t('kiosk.check.checking'), style: TextStyle(fontSize: 12, color: t.mutedForeground)),
        ]),
      KioskCheck.ok => _status(Icons.check_circle_outline, context.t('kiosk.check.ok'), t.success),
      KioskCheck.missing => _status(Icons.cancel_outlined, context.t('kiosk.check.missing'), t.destructive),
      KioskCheck.unknown => _status(Icons.error_outline, context.t('kiosk.check.notListed'), t.warning),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: t.mutedForeground)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(context)),
                if ((state == KioskCheck.missing || state == KioskCheck.unknown) && hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(hint!, style: AppText.caption(context).copyWith(fontSize: 11)),
                  ),
                if (action != null) action!,
              ],
            ),
          ),
          const SizedBox(width: 8),
          badge,
        ],
      ),
    );
  }

  Widget _status(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      );
}

/// Live preview so the guard can see whether the camera and face detection work on
/// this device (web `CameraTest`).
class _CameraTest extends StatefulWidget {
  const _CameraTest({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_CameraTest> createState() => _CameraTestState();
}

class _CameraTestState extends State<_CameraTest> {
  final KioskCamera _cam = KioskCamera();

  @override
  void initState() {
    super.initState();
    _cam.start();
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  static const Map<FramingStatus, String> _framingKeys = {
    FramingStatus.none: 'kiosk.test.none',
    FramingStatus.tooFar: 'kiosk.test.tooFar',
    FramingStatus.tooClose: 'kiosk.test.tooClose',
    FramingStatus.offCenter: 'kiosk.test.offCenter',
    FramingStatus.framed: 'kiosk.test.framed',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: _cam,
      builder: (context, _) {
        final status = switch (_cam.cameraState) {
          KioskCameraState.denied => kioskT(context, 'kiosk.mobile.camDenied'),
          KioskCameraState.error => kioskT(context, 'kiosk.mobile.camError'),
          KioskCameraState.starting => context.t('kiosk.check.checking'),
          KioskCameraState.ready => switch (_cam.detectorState) {
              KioskDetectorState.loading => context.t('kiosk.test.loadingDetector'),
              KioskDetectorState.none => context.t('kiosk.check.faceMissing'),
              KioskDetectorState.mlkit => context.t(_framingKeys[_cam.framing]!),
            },
        };
        final good = _cam.framing == FramingStatus.framed;
        final canRetry = _cam.cameraState == KioskCameraState.denied || _cam.cameraState == KioskCameraState.error;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Row(
            children: [
              KioskCameraBubble(
                camera: _cam,
                size: 80,
                borderColor: good ? t.success : AppTokens.tint(t.warning, 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: good ? t.success : t.foreground),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (canRetry)
                          GestureDetector(
                            onTap: _cam.retry,
                            child: Text(
                              kioskT(context, 'kiosk.mobile.retryCamera'),
                              style: TextStyle(fontSize: 12, color: t.primary, decoration: TextDecoration.underline),
                            ),
                          ),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Text(
                            context.t('kiosk.test.close'),
                            style: TextStyle(fontSize: 12, color: t.mutedForeground, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
