import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../logic/kiosk_signal.dart';

/// Device check result (web `Check`).
enum KioskCheck { checking, ok, missing, unknown }

/// Speech recogniser availability on this device.
enum KioskRecognizerState { unknown, ready, denied, unavailable }

/// Promise-style wrappers over the device TTS (flutter_tts) and speech recognition
/// (speech_to_text) — the native counterpart of web `src/lib/kiosk/kioskSpeech.ts`.
/// One shared instance: both plugins are process-wide on Android.
class KioskSpeech {
  KioskSpeech._();

  static final KioskSpeech instance = KioskSpeech._();

  // ── text to speech ──

  FlutterTts? _tts;
  Future<void>? _ttsInit;
  int _utterance = 0;
  final Map<int, void Function()> _errorHandlers = {};

  FlutterTts get _engine => _tts ??= FlutterTts();

  Future<void> _ensureTts() => _ttsInit ??= () async {
        try {
          final tts = _engine;
          await tts.awaitSpeakCompletion(true);
          await tts.setSpeechRate(0.5); // = web `rate 1` on Android and iOS
          await tts.setPitch(1.0);
          await tts.setVolume(1.0);
          tts.setErrorHandler((_) => _errorHandlers[_utterance]?.call());
        } catch (_) {
          // Engine missing — speak() becomes a no-op guard-timed wait.
        }
      }();

  /// Web `cancelSpeech`.
  Future<void> cancelSpeech() async {
    _utterance++;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Speak [text] in [locale] (e.g. `hi-IN`). Completes when done; throws
  /// [KioskAbortError] when [signal] aborts. Never hangs: a guard timer ends the
  /// line if the engine never reports completion (as on the web).
  Future<void> speak(String text, {required String locale, KioskSignal? signal}) async {
    if (text.trim().isEmpty) return;
    if (signal?.aborted ?? false) throw const KioskAbortError();
    await _ensureTts();
    final id = ++_utterance;
    final tts = _engine;
    try {
      await tts.stop();
      await tts.setLanguage(locale);
    } catch (_) {}
    if (signal?.aborted ?? false) throw const KioskAbortError();

    final done = Completer<void>();
    Timer? guard;
    void Function()? removeAbort;
    void finish([Object? error]) {
      if (done.isCompleted) return;
      guard?.cancel();
      removeAbort?.call();
      _errorHandlers.remove(id);
      if (error != null) {
        done.completeError(error);
      } else {
        done.complete();
      }
    }

    // Android sometimes never reports completion; don't hang the conversation.
    guard = Timer(Duration(milliseconds: math.max(3000, text.length * 110) + 2500), finish);
    removeAbort = signal?.onAbort(() {
      _utterance++;
      unawaited(tts.stop().catchError((_) => null));
      finish(const KioskAbortError());
    });
    _errorHandlers[id] = finish;
    unawaited(() async {
      try {
        // With awaitSpeakCompletion this ends when the line is done or stopped
        // (a stop without abort resolves normally, like web 'interrupted').
        await tts.speak(text);
      } catch (_) {}
      finish();
    }());
    return done.future;
  }

  static String _norm(String l) => l.replaceAll('_', '-').toLowerCase();

  /// Web `hasVoiceFor`: an installed voice for [locale] (same base language counts).
  static bool hasVoiceFor(List<Map<String, String>> voices, String locale) {
    final want = _norm(locale);
    final base = want.split('-').first;
    bool installed(Map<String, String> v) => !(v['features'] ?? '').contains('notInstalled');
    final exact = voices.where((v) => _norm(v['locale'] ?? '') == want && installed(v));
    final sameBase = voices.where((v) => _norm(v['locale'] ?? '').startsWith(base) && installed(v));
    return exact.isNotEmpty || sameBase.isNotEmpty;
  }

  Future<List<Map<String, String>>> _voices() async {
    final raw = await _engine.getVoices;
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
    ];
  }

  /// Device check "Hindi voice": polls the voice list like the web (8 × 750 ms) —
  /// `ok` when listed, `unknown` when never listed ("test it"), `missing` without TTS.
  Future<KioskCheck> checkVoice(String locale) async {
    try {
      await _ensureTts();
      if (defaultTargetPlatform == TargetPlatform.android) {
        // getEngines is Android-only; no engine installed = no voice at all.
        final engines = await _engine.getEngines;
        if (engines is List && engines.isEmpty) return KioskCheck.missing;
      }
      for (var tries = 0; tries < 8; tries++) {
        if (hasVoiceFor(await _voices(), locale)) return KioskCheck.ok;
        await Future<void>.delayed(const Duration(milliseconds: 750));
      }
      return KioskCheck.unknown;
    } catch (_) {
      return KioskCheck.missing;
    }
  }

  // ── speech recognition ──

  final SpeechToText _stt = SpeechToText();
  KioskRecognizerState _recognizer = KioskRecognizerState.unknown;
  Future<KioskRecognizerState>? _sttInit;
  _ListenSession? _session;

  KioskRecognizerState get recognizerState => _recognizer;

  /// Initialises the recogniser (asks for the microphone permission the first time).
  Future<KioskRecognizerState> initRecognizer({bool retry = false}) {
    if (retry && _recognizer != KioskRecognizerState.ready) _sttInit = null;
    return _sttInit ??= () async {
      try {
        final ok = await _stt.initialize(
          onError: _onSttError,
          onStatus: _onSttStatus,
          options: [SpeechToText.androidNoBluetooth],
        );
        if (ok) {
          _recognizer = KioskRecognizerState.ready;
        } else {
          final permitted = await _stt.hasPermission;
          _recognizer = permitted ? KioskRecognizerState.unavailable : KioskRecognizerState.denied;
        }
      } catch (_) {
        _recognizer = KioskRecognizerState.unavailable;
      }
      // A denied permission may be granted later in Settings — allow another try.
      if (_recognizer != KioskRecognizerState.ready) _sttInit = null;
      return _recognizer;
    }();
  }

  void _onSttError(SpeechRecognitionError e) => _session?.onError(e);

  void _onSttStatus(String status) => _session?.onStatus(status);

  /// Listen for one utterance (web `listen`). Resolves with transcripts, best first
  /// (empty when nothing was heard); throws [KioskAbortError] on abort and
  /// [MicPermissionError] when the microphone is blocked.
  Future<List<String>> listen({
    required String locale,
    KioskSignal? signal,
    void Function(String text)? onInterim,
    int maxMs = 10000,
  }) async {
    if (signal?.aborted ?? false) throw const KioskAbortError();
    final state = await initRecognizer();
    if (state == KioskRecognizerState.denied) throw const MicPermissionError('not-allowed');
    if (state != KioskRecognizerState.ready) return const [];
    if (signal?.aborted ?? false) throw const KioskAbortError();

    // One session at a time.
    final previous = _session;
    if (previous != null) {
      previous.finish(abort: true);
      try {
        await _stt.cancel();
      } catch (_) {}
    }

    final session = _ListenSession(onInterim: onInterim);
    _session = session;
    final removeAbort = signal?.onAbort(() {
      session.finish(abort: true);
      unawaited(_stt.cancel().catchError((_) {}));
    });
    // Safety net in case the plugin never reports "done".
    final guard = Timer(Duration(milliseconds: maxMs + 4000), () {
      session.finish();
      unawaited(_stt.cancel().catchError((_) {}));
    });
    try {
      await _stt.listen(
        onResult: session.onResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
          localeId: locale,
          listenFor: Duration(milliseconds: maxMs),
        ),
      );
    } catch (_) {
      session.finish();
    }
    try {
      return await session.result;
    } finally {
      guard.cancel();
      removeAbort?.call();
      if (identical(_session, session)) _session = null;
    }
  }

  /// Stop any listening session (used when the kiosk closes).
  Future<void> stopListening() async {
    _session?.finish(abort: true);
    _session = null;
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}

class _ListenSession {
  _ListenSession({this.onInterim});

  final void Function(String text)? onInterim;
  final Completer<List<String>> _done = Completer();
  List<String> _finals = const [];
  String _interim = '';
  Object? _fatal;

  Future<List<String>> get result => _done.future;

  void onResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    if (r.finalResult) {
      _finals = [for (final a in r.alternates) a.recognizedWords.trim()];
      onInterim?.call(words);
      // The final result ends a non-continuous session (web `onend`).
      finish();
    } else {
      _interim = words;
      onInterim?.call(words);
    }
  }

  void onError(SpeechRecognitionError e) {
    // 'error_no_match', 'error_speech_timeout', network … → treat as nothing heard.
    if (e.errorMsg == 'error_permission' || e.errorMsg == 'error_insufficient_permissions') {
      _fatal = const MicPermissionError('not-allowed');
    }
    finish();
  }

  void onStatus(String status) {
    if (status == SpeechToText.doneStatus) finish();
  }

  void finish({bool abort = false}) {
    if (_done.isCompleted) return;
    if (abort) {
      _done.completeError(const KioskAbortError());
      return;
    }
    final fatal = _fatal;
    if (fatal != null) {
      _done.completeError(fatal);
      return;
    }
    // Best guess first, then the recogniser's alternatives (max 3, like the web).
    final best = _finals.isNotEmpty && _finals.first.isNotEmpty ? _finals.first : _interim;
    final out = <String>[best, ..._finals.skip(1)].where((s) => s.isNotEmpty).take(3).toList();
    _done.complete(out);
  }
}
