import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/prefs/app_prefs.dart';
import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/kiosk_ai.dart';
import '../data/kiosk_approval.dart';
import '../data/kiosk_repository.dart';
import '../device/kiosk_camera.dart';
import '../device/kiosk_speech.dart';
import '../kiosk_lock.dart';
import '../logic/kiosk_conversation.dart';
import '../logic/kiosk_copy.dart';
import '../logic/kiosk_framing.dart';
import '../logic/kiosk_parsers.dart';
import '../logic/kiosk_settings.dart';
import '../logic/kiosk_signal.dart';
import 'kiosk_camera_bubble.dart';
import 'kiosk_effects.dart';
import 'kiosk_palette.dart';
import 'kiosk_screensaver.dart';

/// How long a face must stay framed before the receptionist starts talking.
const Duration kFramedHold = Duration(milliseconds: 1200);

/// End a conversation when nobody has been in front of the camera for this long.
const int kAbandonAfterMs = 25000;
const Duration kResultScreen = Duration(milliseconds: 6000);

enum _Phase { idle, session, result, cooldown }

class _StepInfo {
  const _StepInfo(this.step, this.key, this.icon);

  final KioskStep step;
  final KioskCopyKey key;
  final IconData icon;
}

const List<_StepInfo> _stepOrder = [
  _StepInfo(KioskStep.name, KioskCopyKey.fieldName, Icons.person_outline),
  _StepInfo(KioskStep.phone, KioskCopyKey.fieldPhone, Icons.phone_outlined),
  _StepInfo(KioskStep.flat, KioskCopyKey.fieldFlat, Icons.home_outlined),
  _StepInfo(KioskStep.purpose, KioskCopyKey.fieldPurpose, Icons.adjust),
  _StepInfo(KioskStep.vehicle, KioskCopyKey.fieldVehicle, Icons.directions_car_outlined),
];

final RegExp _idleTapPrefixRe = RegExp(r'^(या|ya|or)\s+', caseSensitive: false);

/// The running kiosk (web `KioskRunner`): full-screen, its own route, Android back
/// blocked, screen kept awake. Pops itself when the guard exits.
class KioskRunnerPage extends ConsumerStatefulWidget {
  const KioskRunnerPage({super.key, required this.settings, required this.session});

  final KioskSettings settings;
  final SessionGuard session;

  @override
  ConsumerState<KioskRunnerPage> createState() => _KioskRunnerPageState();
}

class _KioskRunnerPageState extends ConsumerState<KioskRunnerPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final KioskCamera _camera = KioskCamera();
  late final KioskRepository _repo = KioskRepository(widget.session.societyId);
  final KioskSpeech _speech = KioskSpeech.instance;

  late KioskLang _lang = widget.settings.defaultLang;
  _Phase _phase = _Phase.idle;
  KioskStep _step = KioskStep.greeting;
  KioskDraft _draft = KioskDraft.empty;
  KioskLine? _assistantLine;
  bool _listening = false;
  KioskHearMode? _inputMode;
  String _interim = '';
  String? _understood;
  bool _typing = false;
  final TextEditingController _typed = TextEditingController();
  int? _approvalLeft;
  KioskOutcome? _outcome;
  late String _societyName = widget.session.societyName;
  DateTime _now = DateTime.now();
  bool _facePresent = false;
  bool _speechSupported = true;
  bool _datesReady = false;

  KioskAbortController? _sessionCtrl;
  KioskAbortController? _call;
  void Function(KioskInput input)? _inputResolver;
  DateTime _cooldownStart = DateTime.now();

  Timer? _clock;
  Timer? _faceHold;
  Timer? _autoStart;
  DateTime? _autoStartFor;
  Timer? _cooldownTick;
  Timer? _abandonTick;
  Timer? _resultTimer;
  bool _cameraPaused = false;

  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  bool _holding = false;
  bool _exitOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setKioskLocked(true);
    unawaited(WakelockPlus.enable().catchError((_) {}));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky).catchError((_) {}));
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    initializeDateFormatting().then((_) {
      if (mounted) setState(() => _datesReady = true);
    }, onError: (Object _) {});
    _camera.addListener(_onCamera);
    unawaited(_camera.start());
    _repo.loadSocietyName().then((name) {
      if (mounted && name != null) setState(() => _societyName = name);
    });
    unawaited(_repo.refresh());
    _speech.initRecognizer().then((state) {
      if (mounted) setState(() => _speechSupported = state != KioskRecognizerState.unavailable);
    });
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _holding = false);
        _hold.reset();
        unawaited(_requestExit());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    setKioskLocked(false);
    unawaited(WakelockPlus.disable().catchError((_) {}));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).catchError((_) {}));
    for (final t in [_clock, _faceHold, _autoStart, _cooldownTick, _abandonTick, _resultTimer]) {
      t?.cancel();
    }
    _sessionCtrl?.abort();
    unawaited(_speech.cancelSpeech());
    unawaited(_speech.stopListening());
    _camera
      ..removeListener(_onCamera)
      ..dispose();
    _typed.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Web re-requests the wake lock when the page becomes visible again.
      unawaited(WakelockPlus.enable().catchError((_) {}));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky).catchError((_) {}));
      if (_cameraPaused) {
        _cameraPaused = false;
        unawaited(_camera.start());
      }
    } else if (state == AppLifecycleState.paused) {
      _cameraPaused = true;
      unawaited(_camera.stop());
    }
  }

  // ── camera-driven state (web effects) ──

  void _onCamera() {
    if (!mounted) return;
    // Face present, with a short hold so the screensaver doesn't flicker.
    if (_camera.framing != FramingStatus.none) {
      _faceHold?.cancel();
      _faceHold = null;
      _facePresent = true;
    } else if (_facePresent && _faceHold == null) {
      _faceHold = Timer(const Duration(milliseconds: 2500), () {
        _faceHold = null;
        if (mounted) setState(() => _facePresent = false);
      });
    }
    _syncAutoStart();
    setState(() {});
  }

  /// Auto-start when a face has been properly framed for a moment.
  void _syncAutoStart() {
    final since = _camera.framedSince;
    if (_phase != _Phase.idle || since == null) {
      _autoStart?.cancel();
      _autoStart = null;
      _autoStartFor = null;
      return;
    }
    if (_autoStartFor == since && _autoStart != null) return;
    _autoStart?.cancel();
    _autoStartFor = since;
    final wait = since.add(kFramedHold).difference(DateTime.now());
    _autoStart = Timer(wait.isNegative ? Duration.zero : wait, () {
      _autoStart = null;
      if (mounted && _phase == _Phase.idle) unawaited(_startSession());
    });
  }

  void _goPhase(_Phase p) {
    _phase = p;
    _cooldownTick?.cancel();
    _cooldownTick = null;
    _abandonTick?.cancel();
    _abandonTick = null;
    if (p == _Phase.cooldown) {
      // Cooldown: wait until the last visitor has left (or 12 s) before re-arming.
      _cooldownTick = Timer.periodic(const Duration(milliseconds: 500), (_) {
        final away = _camera.msSinceFace() > 2500 || !_camera.faceDetection;
        if (away || DateTime.now().difference(_cooldownStart).inMilliseconds > 12000) {
          if (!mounted) return;
          setState(() {
            _draft = KioskDraft.empty;
            _assistantLine = null;
            _outcome = null;
          });
          _goPhase(_Phase.idle);
        }
      });
    } else if (p == _Phase.session) {
      // Abandoned conversation: nobody in front of the camera for a while.
      final startedAt = DateTime.now();
      _abandonTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_camera.faceDetection) return;
        final busy = _step == KioskStep.approval || _step == KioskStep.saving;
        // A session started by a tap may not have seen a face yet — count from the start.
        final away = math.min(_camera.msSinceFace(), DateTime.now().difference(startedAt).inMilliseconds.toDouble());
        if (!busy && away > kAbandonAfterMs) _sessionCtrl?.abort();
      });
    }
    _syncAutoStart();
    if (mounted) setState(() {});
  }

  // ── conversation ──

  void _changeLang(KioskLang l) {
    if (l == _lang) return;
    setState(() => _lang = l);
    unawaited(_speech.cancelSpeech());
    _call?.abort(const LanguageChangedError());
  }

  void _sendInput(KioskInput input) => _inputResolver?.call(input);

  void _notifyGuard(KioskOutcome result, KioskDraft d) {
    final vars = {'name': d.name.isNotEmpty ? d.name : d.nameDisplay, 'flat': d.flat, 'phone': d.phone};
    switch (result) {
      case KioskOutcome.saved:
        AppFeedback.toast(context, context.t('kiosk.toast.saved', vars), tone: BadgeTone.success);
      case KioskOutcome.blocked:
        AppFeedback.toast(context, context.t('kiosk.toast.blocked', vars), tone: BadgeTone.alert, duration: const Duration(seconds: 15));
      case KioskOutcome.rejected:
        AppFeedback.toast(context, context.t('kiosk.toast.rejected', vars), tone: BadgeTone.warning, duration: const Duration(seconds: 10));
      case KioskOutcome.timeout:
        AppFeedback.toast(context, context.t('kiosk.toast.timeout', vars), tone: BadgeTone.warning, duration: const Duration(seconds: 15));
      case KioskOutcome.failed:
        break;
    }
  }

  Future<void> _startSession() async {
    if (_sessionCtrl != null || _phase == _Phase.session) return;
    final session = KioskAbortController();
    _sessionCtrl = session;
    var latestDraft = KioskDraft.empty;
    _resultTimer?.cancel();
    setState(() {
      _draft = KioskDraft.empty;
      _outcome = null;
      _understood = null;
      _interim = '';
      _typed.clear();
      _approvalLeft = null;
      _step = KioskStep.greeting;
    });
    _goPhase(_Phase.session);
    unawaited(_repo.refresh());

    final io = KioskIO(
      signal: session.signal,
      lang: () => _lang,
      say: (key, vars) async {
        final link = linkedController(session.signal);
        _call = link.ctrl;
        final l = _lang;
        if (mounted) {
          setState(() {
            _assistantLine = KioskLine(key, vars);
            _listening = false;
            _inputMode = null;
          });
        }
        try {
          await _speech.speak(kioskSpeech(key, l, vars), locale: kVoiceLocale[l]!, signal: link.ctrl.signal);
        } catch (e) {
          if (link.ctrl.signal.reason is LanguageChangedError) throw const LanguageChangedError();
          rethrow;
        } finally {
          link.dispose();
          if (identical(_call, link.ctrl)) _call = null;
        }
        if (link.ctrl.signal.reason is LanguageChangedError) throw const LanguageChangedError();
      },
      hear: (mode, {required typing}) {
        final link = linkedController(session.signal);
        _call = link.ctrl;
        final result = Completer<KioskInput>();
        var done = false;
        Timer? timer;
        void finish(void Function() fn) {
          if (done) return;
          done = true;
          timer?.cancel();
          link.dispose();
          _inputResolver = null;
          if (identical(_call, link.ctrl)) _call = null;
          if (mounted) {
            setState(() {
              _listening = false;
              _inputMode = null;
            });
          }
          fn();
        }

        Object abortError() =>
            link.ctrl.signal.reason is LanguageChangedError ? const LanguageChangedError() : const KioskAbortError();
        if (link.ctrl.aborted) {
          finish(() => result.completeError(abortError()));
          return result.future;
        }
        _inputResolver = (input) {
          finish(() => result.complete(input));
          link.ctrl.abort();
        };
        link.ctrl.signal.onAbort(() => finish(() => result.completeError(abortError())));
        if (mounted) {
          setState(() {
            _inputMode = mode;
            _interim = '';
          });
        }
        if (typing || !_speechSupported) {
          timer = Timer(const Duration(seconds: 60), () => finish(() => result.complete(const KioskInput.speech([]))));
          return result.future;
        }
        if (mounted) setState(() => _listening = true);
        _speech
            .listen(
          locale: kRecognitionLocale[_lang]!,
          signal: link.ctrl.signal,
          onInterim: (text) {
            if (mounted && !done) setState(() => _interim = text);
          },
          maxMs: mode == KioskHearMode.yesno ? 7000 : 11000,
        )
            .then((alts) {
          if (alts.isNotEmpty && mounted && !done) setState(() => _interim = alts.first);
          finish(() => result.complete(KioskInput.speech(alts)));
        }, onError: (Object e) {
          finish(() => result.completeError(e));
        });
        return result.future;
      },
      setStep: (s) {
        if (mounted) setState(() => _step = s);
      },
      setDraft: (d) {
        latestDraft = d;
        if (mounted) setState(() => _draft = d);
      },
      setUnderstood: (text) {
        if (mounted) setState(() => _understood = text);
      },
      setTyping: (on) {
        if (!mounted) return;
        setState(() {
          _typing = on;
          if (on) _typed.clear();
        });
      },
    );

    final guard = widget.session.guard;
    final guardName = '${guard.name} · AI Kiosk';
    final ctx = KioskContext(
      societyName: _societyName.isNotEmpty ? _societyName : 'Kutumbika',
      societyId: widget.session.societyId,
      settings: widget.settings,
      flatNumbers: List.of(_repo.flatNumbers),
      findPreviousVisit: _repo.findPreviousVisit,
      isBlacklisted: _repo.isBlacklisted,
      capturePhoto: _camera.captureFrame,
      requestApproval: (d, onTick) async {
        if (widget.session.societyId.isEmpty) return KioskApprovalOutcome.noFlat;
        return requestResidentApproval(
          societyId: widget.session.societyId,
          flatNumber: d.flat,
          visitorName: d.name,
          visitorPhone: d.phone,
          purpose: d.purpose?.label ?? '',
          guardId: guard.guardId,
          guardName: guardName,
          signal: session.signal,
          onTick: onTick,
        );
      },
      onApprovalTick: (s) {
        if (mounted) setState(() => _approvalLeft = s);
      },
      saveEntry: (d) => _repo.saveEntry(
        d,
        guardId: guard.guardId,
        guardName: guardName,
        capsEntry: ref.read(entryCapsProvider),
      ),
      aiExtract: kioskAiExtract,
    );

    KioskOutcome? outcome;
    try {
      outcome = await runKioskConversation(io, ctx);
    } on KioskAbortError {
      outcome = null;
    } catch (e) {
      debugPrint('Kiosk conversation failed: $e');
      outcome = KioskOutcome.failed;
    } finally {
      _sessionCtrl = null;
      _call = null;
      _inputResolver = null;
      unawaited(_speech.cancelSpeech());
      if (mounted) {
        setState(() {
          _listening = false;
          _inputMode = null;
          _typing = false;
        });
      }
    }
    if (!mounted) return;

    if (outcome != null) {
      _notifyGuard(outcome, latestDraft);
      setState(() => _outcome = outcome);
      _goPhase(_Phase.result);
      _resultTimer = Timer(kResultScreen, () {
        if (mounted && _phase == _Phase.result) {
          _cooldownStart = DateTime.now();
          _goPhase(_Phase.cooldown);
        }
      });
    } else {
      _cooldownStart = DateTime.now();
      _goPhase(_Phase.cooldown);
    }
  }

  // ── hold-to-exit lock ──

  Future<void> _requestExit() async {
    if (_exitOpen) return;
    _exitOpen = true;
    try {
      final pin = widget.settings.exitPin;
      if (pin.isNotEmpty) {
        final value = await _pinPrompt();
        if (!mounted || value == null) return;
        if (value != pin) {
          AppFeedback.toast(context, context.t('kiosk.exit.wrongPin'), tone: BadgeTone.alert);
          return;
        }
      } else {
        final ok = await AppFeedback.confirm(
          context,
          title: context.t('kiosk.exit.confirmTitle'),
          message: context.t('kiosk.exit.confirmText'),
          confirmLabel: context.t('swal.yes'),
          cancelLabel: context.t('swal.no'),
        );
        if (!ok || !mounted) return;
      }
      _sessionCtrl?.abort();
      unawaited(_speech.cancelSpeech());
      if (mounted) Navigator.of(context).pop();
    } finally {
      _exitOpen = false;
    }
  }

  Future<String?> _pinPrompt() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('kiosk.exit.pinPrompt')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _startHold() {
    setState(() => _holding = true);
    _hold.forward(from: 0);
  }

  void _endHold() {
    if (!_holding && !_hold.isAnimating) return;
    _hold
      ..stop()
      ..reset();
    setState(() => _holding = false);
  }

  // ── labels ──

  String get _locale => _lang == KioskLang.en ? 'en_IN' : 'hi';

  String _format(String pattern) {
    if (_datesReady) {
      try {
        return DateFormat(pattern, _locale).format(_now);
      } catch (_) {}
    }
    return DateFormat(pattern).format(_now);
  }

  String get _timeLabel => _format('hh:mm a');

  String get _dateLabel => _format('EEEE, d MMMM');

  KioskStatus _screensaverStatus() {
    final retryLabel = kioskText(KioskCopyKey.retryCamera, _lang);
    return switch (_camera.cameraState) {
      KioskCameraState.starting => KioskStatus(kioskText(KioskCopyKey.statusCamStarting, _lang), KioskStatusTone.warn),
      KioskCameraState.denied => KioskStatus(kioskText(KioskCopyKey.statusCamDenied, _lang), KioskStatusTone.error,
          onRetry: _camera.retry, retryLabel: retryLabel),
      KioskCameraState.error => KioskStatus(kioskText(KioskCopyKey.statusCamErrorApp, _lang), KioskStatusTone.error,
          onRetry: _camera.retry, retryLabel: retryLabel),
      KioskCameraState.ready => switch (_camera.detectorState) {
          KioskDetectorState.loading => KioskStatus(kioskText(KioskCopyKey.statusDetectorLoading, _lang), KioskStatusTone.warn),
          KioskDetectorState.none => KioskStatus(kioskText(KioskCopyKey.statusNoDetector, _lang), KioskStatusTone.warn),
          KioskDetectorState.mlkit => KioskStatus(kioskText(KioskCopyKey.statusLooking, _lang), KioskStatusTone.ok),
        },
    };
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final showScreensaver = (_phase == _Phase.idle || _phase == _Phase.cooldown) && !_facePresent;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: KioskPalette.background,
        resizeToAvoidBottomInset: true,
        body: DefaultTextStyle.merge(
          style: const TextStyle(color: KioskPalette.white),
          child: IconTheme.merge(
            data: const IconThemeData(color: KioskPalette.white),
            child: showScreensaver ? _buildScreensaver() : _buildMain(context),
          ),
        ),
      ),
    );
  }

  Widget _buildScreensaver() {
    return Stack(
      children: [
        Positioned.fill(
          child: KioskScreensaver(
            lang: _lang,
            societyName: _societyName,
            timeLabel: _timeLabel,
            dateLabel: _dateLabel,
            camera: _camera,
            status: _screensaverStatus(),
            onTap: () => unawaited(_startSession()),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _topBar()),
      ],
    );
  }

  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _societyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: KioskPalette.orange300),
                  ),
                  Text(
                    _timeLabel,
                    style: TextStyle(fontSize: 11, color: KioskPalette.whiteA(0.5), fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: KioskPalette.whiteA(0.10), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final l in kKioskLangs) ...[
                    if (l != kKioskLangs.first) const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _changeLang(l),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _lang == l ? KioskPalette.orange500 : KioskPalette.a(KioskPalette.orange500, 0),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _lang == l
                              ? [BoxShadow(color: KioskPalette.a(KioskPalette.black, 0.25), blurRadius: 3, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Text(
                          l.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _lang == l ? KioskPalette.white : KioskPalette.whiteA(0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: context.t('kiosk.exit.hold'),
              child: Listener(
                onPointerDown: (_) => _startHold(),
                onPointerUp: (_) => _endHold(),
                onPointerCancel: (_) => _endHold(),
                child: GestureDetector(
                  // Swallow taps so the screensaver underneath does not start a session.
                  onTap: () {},
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: KioskPalette.whiteA(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: _holding ? Border.all(color: KioskPalette.orange400, width: 2) : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_holding)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _hold,
                              builder: (_, __) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _hold.value,
                                child: ColoredBox(color: KioskPalette.a(KioskPalette.orange500, 0.4)),
                              ),
                            ),
                          ),
                        Icon(Icons.lock_outline, size: 16, color: KioskPalette.whiteA(0.6)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 768;
    final sm = width >= 640;
    final editable = _phase == _Phase.session && _step == KioskStep.summary;
    final showDetails = _phase == _Phase.session || ((_phase == _Phase.result || _phase == _Phase.cooldown) && _outcome != null);

    final cameraSection = _cameraSection(sm);
    final details = showDetails ? _detailsCard(editable) : null;
    final conversation = _conversation(sm);

    final Widget content;
    if (tablet) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(children: [cameraSection, if (details != null) ...[const SizedBox(height: 20), details]]),
          ),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: conversation),
        ],
      );
    } else {
      // Phones: camera → conversation → details (details first on the summary step).
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cameraSection,
          if (details != null && editable) ...[const SizedBox(height: 20), details],
          const SizedBox(height: 20),
          conversation,
          if (details != null && !editable) ...[const SizedBox(height: 20), details],
        ],
      );
    }

    return Stack(
      children: [
        Positioned(top: -160, left: -128, child: KioskBlob(size: 480, color: KioskPalette.a(KioskPalette.orange500, 0.15))),
        Positioned(bottom: -160, right: -128, child: KioskBlob(size: 480, color: KioskPalette.a(KioskPalette.emerald500, 0.10))),
        Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1024), child: content),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cameraSection(bool sm) {
    final framing = _camera.framing;
    final ring = framing == FramingStatus.framed
        ? KioskPalette.emerald400
        : framing == FramingStatus.none
            ? KioskPalette.whiteA(0.20)
            : KioskPalette.amber400;
    final hint = switch (framing) {
      FramingStatus.tooFar => KioskCopyKey.frameTooFar,
      FramingStatus.tooClose => KioskCopyKey.frameTooClose,
      FramingStatus.offCenter => KioskCopyKey.frameOffCenter,
      FramingStatus.framed => KioskCopyKey.frameHold,
      FramingStatus.none => KioskCopyKey.frameNone,
    };
    final size = sm ? 240.0 : (_phase == _Phase.idle ? 192.0 : 144.0);
    return Column(
      children: [
        KioskCameraBubble(
          camera: _camera,
          size: size,
          borderColor: ring,
          shadow: true,
          overlay: _phase == _Phase.session
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: KioskPalette.a(KioskPalette.black, 0.6), borderRadius: BorderRadius.circular(999)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_outlined, size: 12, color: KioskPalette.white),
                          SizedBox(width: 4),
                          Text('AI', style: TextStyle(fontSize: 10, color: KioskPalette.white)),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
        if (_phase == _Phase.idle) ...[
          const SizedBox(height: 16),
          Text(
            kioskText(hint, _lang),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: framing == FramingStatus.framed ? KioskPalette.emerald300 : KioskPalette.amber200,
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailsCard(bool editable) {
    final d = _draft;
    final rows = <({KioskEditField field, KioskCopyKey key, IconData icon, String value})>[
      (
        field: KioskEditField.name,
        key: KioskCopyKey.fieldName,
        icon: Icons.person_outline,
        value: d.nameDisplay.isNotEmpty && d.nameDisplay != d.name ? '${d.nameDisplay} · ${d.name}' : d.name,
      ),
      (field: KioskEditField.phone, key: KioskCopyKey.fieldPhone, icon: Icons.phone_outlined, value: d.phone.isNotEmpty ? formatPhoneForDisplay(d.phone) : ''),
      (field: KioskEditField.flat, key: KioskCopyKey.fieldFlat, icon: Icons.home_outlined, value: d.flat),
      (
        field: KioskEditField.purpose,
        key: KioskCopyKey.fieldPurpose,
        icon: Icons.adjust,
        value: d.purpose != null
            ? purposeLabel(d.purpose!.label, _lang) + (d.company != null && d.company!.isNotEmpty ? ' · ${d.company}' : '')
            : '',
      ),
      if (widget.settings.askVehicle)
        (
          field: KioskEditField.vehicle,
          key: KioskCopyKey.fieldVehicle,
          icon: Icons.directions_car_outlined,
          value: d.vehicleAsked && d.vehicle == null ? kioskText(KioskCopyKey.noVehicle, _lang) : (d.vehicle ?? ''),
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KioskPalette.whiteA(0.05),
        border: Border.all(color: KioskPalette.whiteA(0.10)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: editable ? KioskPalette.whiteA(0.05) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(row.icon, size: 16, color: row.value.isNotEmpty ? KioskPalette.emerald300 : KioskPalette.whiteA(0.3)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kioskText(row.key, _lang), style: TextStyle(fontSize: 11, color: KioskPalette.whiteA(0.5))),
                        Text(
                          row.value.isNotEmpty ? row.value : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: row.value.isNotEmpty ? KioskPalette.white : KioskPalette.whiteA(0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (editable)
                    _pillButton(kioskText(KioskCopyKey.edit, _lang), () => _sendInput(KioskInput.edit(row.field)), small: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap, {IconData? icon, bool small = false, Color? color, Color? textColor}) {
    return Material(
      color: color ?? KioskPalette.whiteA(0.10),
      borderRadius: BorderRadius.circular(small ? 8 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(small ? 8 : 12),
        onTap: onTap,
        child: Padding(
          padding: small ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: textColor ?? KioskPalette.white), const SizedBox(width: 8)],
              Text(label, style: TextStyle(fontSize: small ? 12 : 14, fontWeight: FontWeight.w600, color: textColor ?? KioskPalette.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversation(bool sm) {
    final children = <Widget>[];
    final assistantText = _assistantLine == null ? '' : kioskText(_assistantLine!.key, _lang, _assistantLine!.vars);

    if (_phase == _Phase.idle) {
      children.add(Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: KioskPalette.whiteA(0.05),
          border: Border.all(color: KioskPalette.whiteA(0.10)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Text(kioskText(KioskCopyKey.idleTitle, _lang),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(kioskText(KioskCopyKey.idleSubtitle, _lang),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: KioskPalette.whiteA(0.7))),
            const SizedBox(height: 20),
            Material(
              color: KioskPalette.orange500,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => unawaited(_startSession()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    kioskText(KioskCopyKey.idleTap, _lang).replaceFirst(_idleTapPrefixRe, ''),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: KioskPalette.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    if (_phase == _Phase.session) {
      final activeIdx = _stepOrder.indexWhere((s) => s.step == _step);
      final steps = _stepOrder.where((s) => s.step != KioskStep.vehicle || widget.settings.askVehicle).toList();
      final showTyping = _inputMode == KioskHearMode.field && (_typing || !_speechSupported);
      final canSkip = _inputMode == KioskHearMode.field && (_step == KioskStep.purpose || _step == KioskStep.vehicle);

      // Step progress
      children.add(Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: (activeIdx > i || _step == KioskStep.summary || _step == KioskStep.approval || _step == KioskStep.saving)
                      ? KioskPalette.emerald400
                      : activeIdx == i
                          ? KioskPalette.orange400
                          : KioskPalette.whiteA(0.15),
                ),
              ),
            ),
          ],
        ],
      ));

      // Assistant bubble
      final left = math.max(_approvalLeft ?? 0, 0);
      children.add(KioskFadeIn(
        childKey: assistantText,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [KioskPalette.a(KioskPalette.orange500, 0.25), KioskPalette.a(KioskPalette.orange500, 0.05)],
            ),
            border: Border.all(color: KioskPalette.a(KioskPalette.orange400, 0.30)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy_outlined, size: 14, color: KioskPalette.a(KioskPalette.orange200, 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    'AI RECEPTIONIST',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: KioskPalette.a(KioskPalette.orange200, 0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(assistantText, style: TextStyle(fontSize: sm ? 30 : 24, fontWeight: FontWeight.w600, height: 1.35)),
              if (_step == KioskStep.approval && _approvalLeft != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${kioskText(KioskCopyKey.waitingResident, _lang)} · ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 14, color: KioskPalette.whiteA(0.7), fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
              if (_step == KioskStep.saving) ...[
                const SizedBox(height: 12),
                Text(kioskText(KioskCopyKey.savingEntry, _lang), style: TextStyle(fontSize: 14, color: KioskPalette.whiteA(0.7))),
              ],
            ],
          ),
        ),
      ));

      // Live transcript
      if (_listening || _interim.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: KioskPalette.whiteA(0.10),
              border: Border.all(color: KioskPalette.whiteA(0.15)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(6),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_listening) const KioskWaveBars() else Icon(Icons.mic_none_outlined, size: 16, color: KioskPalette.whiteA(0.5)),
                    const SizedBox(width: 8),
                    Text(
                      (_listening && _interim.isEmpty ? kioskText(KioskCopyKey.listening, _lang) : kioskText(KioskCopyKey.youSaid, _lang))
                          .toUpperCase(),
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: KioskPalette.whiteA(0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Text(_interim.isNotEmpty ? _interim : '…', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ));
      }

      // "I understood" chip
      if (_understood != null) {
        children.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: KioskPalette.a(KioskPalette.emerald500, 0.15),
            border: Border.all(color: KioskPalette.a(KioskPalette.emerald400, 0.40)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: KioskPalette.emerald300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kioskText(KioskCopyKey.understood, _lang).toUpperCase(),
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: KioskPalette.a(KioskPalette.emerald200, 0.8)),
                    ),
                    Text(_understood!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  ],
                ),
              ),
            ],
          ),
        ));
      }

      // Yes / No
      if (_inputMode == KioskHearMode.yesno) {
        Widget big(String label, Color bg, VoidCallback onTap, {Color? border}) => Expanded(
              child: Material(
                color: bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: border == null ? BorderSide.none : BorderSide(color: border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: KioskPalette.white)),
                  ),
                ),
              ),
            );
        children.add(Row(
          children: [
            big('✓ ${kioskText(KioskCopyKey.yes, _lang)}', KioskPalette.emerald500, () => _sendInput(KioskInput.yes)),
            const SizedBox(width: 12),
            big('✗ ${kioskText(KioskCopyKey.no, _lang)}', KioskPalette.whiteA(0.10), () => _sendInput(KioskInput.no),
                border: KioskPalette.whiteA(0.20)),
          ],
        ));
      }

      // Typing fallback
      if (showTyping) {
        void submit() {
          final text = _typed.text.trim();
          if (text.isEmpty) return;
          _typed.clear();
          _sendInput(KioskInput.text(text));
        }

        final placeholderKey = _stepOrder.where((s) => s.step == _step).map((s) => s.key).firstOrNull ?? KioskCopyKey.fieldName;
        children.add(Row(
          children: [
            Expanded(
              child: TextField(
                controller: _typed,
                autofocus: true,
                keyboardType: _step == KioskStep.phone ? TextInputType.phone : TextInputType.text,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => submit(),
                cursorColor: KioskPalette.slate900,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: KioskPalette.slate900),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: KioskPalette.white,
                  hintText: kioskText(placeholderKey, _lang),
                  hintStyle: TextStyle(color: KioskPalette.a(KioskPalette.slate900, 0.45), fontSize: 20, fontWeight: FontWeight.w600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 60,
              child: Material(
                color: KioskPalette.orange500,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(kioskText(KioskCopyKey.submit, _lang),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: KioskPalette.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
      }

      // Actions
      children.add(Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_inputMode == KioskHearMode.field && !showTyping)
                  _pillButton(kioskText(KioskCopyKey.typeIt, _lang), () => _sendInput(KioskInput.typeMode), icon: Icons.keyboard_outlined),
                if (canSkip) _pillButton(kioskText(KioskCopyKey.skip, _lang), () => _sendInput(KioskInput.skip)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _sessionCtrl?.abort(),
            icon: Icon(Icons.close, size: 16, color: KioskPalette.whiteA(0.6)),
            label: Text(kioskText(KioskCopyKey.cancelSession, _lang), style: TextStyle(fontSize: 14, color: KioskPalette.whiteA(0.6))),
          ),
        ],
      ));
    }

    if ((_phase == _Phase.result || _phase == _Phase.cooldown) && _outcome != null) {
      final (icon, color) = switch (_outcome!) {
        KioskOutcome.saved => (Icons.check_circle_outline, KioskPalette.emerald400),
        KioskOutcome.blocked => (Icons.gpp_bad_outlined, KioskPalette.red400),
        _ => (Icons.cancel_outlined, KioskPalette.amber400),
      };
      children.add(KioskFadeIn(
        childKey: 'result-$_outcome',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: KioskPalette.whiteA(0.05),
            border: Border.all(color: KioskPalette.whiteA(0.10)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 12),
              Text(assistantText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
      ],
    );
  }
}
