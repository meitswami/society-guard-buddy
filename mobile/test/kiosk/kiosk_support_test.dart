// Extra coverage for the pure kiosk helpers (framing thresholds, copy, settings, signals).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_copy.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_framing.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_settings.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_signal.dart';

FaceBox box(double x, double y, double w, double h) => FaceBox(x: x, y: y, width: w, height: h);

void main() {
  group('evaluateFraming (web thresholds)', () {
    test('no face', () => expect(evaluateFraming(const []).status, FramingStatus.none));

    test('width < 12% is too far, > 70% too close', () {
      expect(evaluateFraming([box(0.45, 0.4, 0.11, 0.12)]).status, FramingStatus.tooFar);
      expect(evaluateFraming([box(0.1, 0.1, 0.75, 0.8)]).status, FramingStatus.tooClose);
    });

    test('centre band ±22% horizontally, ±27% around 0.45 vertically', () {
      // centre x = 0.5, y = 0.45
      expect(evaluateFraming([box(0.4, 0.35, 0.2, 0.2)]).status, FramingStatus.framed);
      // centre x = 0.75 (> 0.22 off)
      expect(evaluateFraming([box(0.65, 0.35, 0.2, 0.2)]).status, FramingStatus.offCenter);
      // centre y = 0.75 (> 0.27 off)
      expect(evaluateFraming([box(0.4, 0.65, 0.2, 0.2)]).status, FramingStatus.offCenter);
    });

    test('uses the largest face', () {
      final r = evaluateFraming([box(0.0, 0.0, 0.05, 0.05), box(0.4, 0.35, 0.2, 0.2)]);
      expect(r.status, FramingStatus.framed);
      expect(r.face!.width, 0.2);
    });
  });

  group('kiosk copy', () {
    test('Hinglish is shown in Roman but spoken from the Devanagari line', () {
      expect(kioskText(KioskCopyKey.askName, KioskLang.hinglish), 'Kripya apna poora naam bataiye.');
      expect(kioskSpeech(KioskCopyKey.askName, KioskLang.hinglish), kioskText(KioskCopyKey.askName, KioskLang.hi));
      expect(kioskSpeech(KioskCopyKey.askName, KioskLang.en), 'Please tell me your full name.');
    });

    test('fills placeholders (missing vars become empty, like web fill)', () {
      expect(kioskText(KioskCopyKey.confirmFlat, KioskLang.en, {'flat': 'A 604'}), 'Flat A 604, is that right?');
      expect(kioskText(KioskCopyKey.confirmFlat, KioskLang.en, {}), 'Flat , is that right?');
      expect(kioskText(KioskCopyKey.confirmFlat, KioskLang.en), 'Flat {flat}, is that right?');
    });

    test('locales and purpose labels', () {
      expect(kRecognitionLocale[KioskLang.hinglish], 'en-IN');
      expect(kVoiceLocale[KioskLang.hinglish], 'hi-IN');
      expect(purposeLabel('Maintenance', KioskLang.hi), 'मरम्मत / सर्विस');
      expect(purposeLabel('Unknown', KioskLang.en), 'Unknown');
    });
  });

  group('KioskSettings', () {
    test('defaults match the web', () {
      const d = kDefaultKioskSettings;
      expect(d.defaultLang, KioskLang.hi);
      expect([d.requireApproval, d.useCloudAi, d.capturePhoto, d.askVehicle], everyElement(isTrue));
      expect(d.exitPin, '');
    });

    test('JSON round trip and partial / malformed values keep defaults', () {
      final s = kDefaultKioskSettings.copyWith(defaultLang: KioskLang.en, askVehicle: false, exitPin: '1234');
      expect(KioskSettings.fromJson(s.toJson()), s);
      final partial = KioskSettings.fromJson({'defaultLang': 'hinglish', 'useCloudAi': 'yes'});
      expect(partial.defaultLang, KioskLang.hinglish);
      expect(partial.useCloudAi, isTrue);
      expect(KioskSettings.fromJson('garbage'), kDefaultKioskSettings);
    });
  });

  group('KioskSignal', () {
    test('linked controller follows the parent with its reason', () {
      final parent = KioskAbortController();
      final link = linkedController(parent.signal);
      var fired = 0;
      link.ctrl.signal.onAbort(() => fired++);
      parent.abort('lang');
      expect(link.ctrl.aborted, isTrue);
      expect(link.ctrl.signal.reason, 'lang');
      expect(fired, 1);
    });

    test('disposed link no longer follows; already-aborted parent aborts immediately', () {
      final parent = KioskAbortController();
      final link = linkedController(parent.signal);
      link.dispose();
      parent.abort();
      expect(link.ctrl.aborted, isFalse);
      final late = linkedController(parent.signal);
      expect(late.ctrl.aborted, isTrue);
      expect(late.ctrl.signal.reason, isA<KioskAbortError>());
    });
  });
}
