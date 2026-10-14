/// Cancellation primitives for the AI kiosk — the Dart counterpart of the web
/// `AbortController` / `AbortSignal` plus the error types from `kioskSpeech.ts`.
/// Pure Dart (no Flutter imports) so the conversation engine stays testable.
library;

/// The conversation (or one speak / listen call) was cancelled.
class KioskAbortError implements Exception {
  const KioskAbortError();

  @override
  String toString() => 'KioskAbortError: aborted';
}

/// The microphone permission is blocked (web `MicPermissionError`).
class MicPermissionError implements Exception {
  const MicPermissionError([this.message = 'microphone blocked']);

  final String message;

  @override
  String toString() => 'MicPermissionError: $message';
}

/// Read side of a [KioskAbortController] (web `AbortSignal`).
class KioskSignal {
  KioskSignal._();

  /// A signal that is never aborted (handy for tests and one-off calls).
  factory KioskSignal.never() => KioskSignal._();

  bool _aborted = false;
  Object? _reason;
  final List<void Function()> _listeners = [];

  bool get aborted => _aborted;

  /// What [KioskAbortController.abort] was called with (defaults to [KioskAbortError]).
  Object? get reason => _reason;

  /// Runs [listener] once when the signal aborts. Like DOM `addEventListener('abort')`,
  /// nothing happens for a signal that is already aborted — check [aborted] first.
  /// Returns a function that removes the listener.
  void Function() onAbort(void Function() listener) {
    if (_aborted) return () {};
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _abort(Object reason) {
    if (_aborted) return;
    _aborted = true;
    _reason = reason;
    final pending = List.of(_listeners);
    _listeners.clear();
    for (final l in pending) {
      l();
    }
  }
}

/// Web `AbortController`.
class KioskAbortController {
  final KioskSignal signal = KioskSignal._();

  bool get aborted => signal.aborted;

  void abort([Object? reason]) => signal._abort(reason ?? const KioskAbortError());
}

/// A child controller that aborts (with the same reason) when [parent] aborts —
/// web `linkedController` in `KioskPage.tsx`. Call `dispose` when the call is done.
({KioskAbortController ctrl, void Function() dispose}) linkedController(KioskSignal parent) {
  final ctrl = KioskAbortController();
  if (parent.aborted) {
    ctrl.abort(parent.reason);
    return (ctrl: ctrl, dispose: () {});
  }
  final remove = parent.onAbort(() => ctrl.abort(parent.reason));
  return (ctrl: ctrl, dispose: remove);
}
