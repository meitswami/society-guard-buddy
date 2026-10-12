// Port of web `src/lib/kiosk/kioskConversation.test.ts` (every case, same scripts).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_conversation.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_copy.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_parsers.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_settings.dart';
import 'package:kutumbika_mobile/features/kiosk/logic/kiosk_signal.dart';

/// `speech(...alternatives)` from the web test.
KioskInput speech([String? a, String? b, String? c]) =>
    KioskInput.speech([for (final s in [a, b, c]) if (s != null) s]);

final KioskSettings _testSettings =
    kDefaultKioskSettings.copyWith(requireApproval: false, useCloudAi: false, capturePhoto: false);

class _Harness {
  _Harness(
    List<Object> script, {
    KioskSettings? settings,
    FutureOr<KioskPreviousVisit?> Function(String phone)? findPreviousVisit,
    FutureOr<bool> Function(String? phone, String? vehicle)? isBlacklisted,
    Future<KioskApprovalOutcome> Function(KioskDraft draft, void Function(int) onTick)? requestApproval,
  }) : _queue = [...script] {
    io = KioskIO(
      signal: KioskAbortController().signal,
      lang: () => KioskLang.hi,
      say: (key, _) async => said.add(key),
      hear: (_, {required typing}) async {
        if (_queue.isEmpty) {
          throw StateError('script exhausted after: ${said.sublist(math.max(0, said.length - 3)).join(', ')}');
        }
        final next = _queue.removeAt(0);
        if (next is Exception) throw next;
        return next as KioskInput;
      },
      setStep: (_) {},
      setDraft: (_) {},
      setUnderstood: (_) {},
      setTyping: typingStates.add,
    );
    ctx = KioskContext(
      societyName: 'Green Park',
      societyId: 'soc-1',
      settings: settings ?? _testSettings,
      flatNumbers: const ['A-604', 'B-604', 'C-101'],
      findPreviousVisit: findPreviousVisit ?? (_) => null,
      isBlacklisted: isBlacklisted ?? (_, __) => false,
      capturePhoto: () => null,
      requestApproval: requestApproval ?? (_, __) async => KioskApprovalOutcome.approved,
      onApprovalTick: (_) {},
      saveEntry: (d) async {
        saved.add(d);
        return true;
      },
    );
  }

  final List<Object> _queue;
  final said = <KioskCopyKey>[];
  final typingStates = <bool>[];
  final saved = <KioskDraft>[];
  late final KioskIO io;
  late final KioskContext ctx;

  int get remaining => _queue.length;
}

void main() {
  group('runKioskConversation', () {
    test('collects every detail from Hindi speech and saves the entry', () async {
      final h = _Harness([
        speech('मेरा नाम राहुल शर्मा है'), speech('हाँ'),
        speech('नौ आठ सात छह पांच चार तीन दो एक शून्य'), KioskInput.yes,
        speech('ए विंग छह सौ चार'), speech('हाँ सही है'),
        speech('अमेज़न का पार्सल'),
        speech('नहीं'),
        KioskInput.yes,
      ]);
      expect(await runKioskConversation(h.io, h.ctx), KioskOutcome.saved);
      expect(h.saved, hasLength(1));
      final d = h.saved.first;
      expect(d.nameDisplay, 'राहुल शर्मा');
      expect(d.name, 'Rahul Sharma');
      expect(d.phone, '9876543210');
      expect(d.flat, 'A-604');
      expect(d.purpose, KioskPurpose.delivery);
      expect(d.company, 'Amazon');
      expect(d.vehicleAsked, isTrue);
      expect(d.vehicle, isNull);
      expect(h.said.first, KioskCopyKey.greeting);
      expect(h.said.last, KioskCopyKey.done);
      expect(h.remaining, 0);
    });

    test('stops a blacklisted visitor before asking anything else', () async {
      final h = _Harness(
        [speech('Rahul'), KioskInput.yes, speech('9876543210'), KioskInput.yes],
        isBlacklisted: (phone, _) => phone == '9876543210',
      );
      expect(await runKioskConversation(h.io, h.ctx), KioskOutcome.blocked);
      expect(h.saved, isEmpty);
      expect(h.said.last, KioskCopyKey.blacklisted);
    });

    test('re-asks after a "no", a language switch and an unknown flat', () async {
      final h = _Harness([
        speech('mera naam amit hai'), KioskInput.no,
        const LanguageChangedError(),
        speech('my name is Amit Kumar'), KioskInput.yes,
        speech('9123456789'), KioskInput.yes,
        speech('flat 999'),
        speech('C 101'), KioskInput.yes,
        speech('milne aaya hoon'),
        speech('haan'), speech('MH 02 AB 1234'), KioskInput.yes,
        // Summary: change the flat by tapping, then confirm.
        const KioskInput.edit(KioskEditField.flat), speech('B 604'), KioskInput.yes,
        KioskInput.yes,
      ]);
      expect(await runKioskConversation(h.io, h.ctx), KioskOutcome.saved);
      final d = h.saved.first;
      expect(d.name, 'Amit Kumar');
      expect(d.phone, '9123456789');
      expect(d.flat, 'B-604');
      expect(d.purpose, KioskPurpose.visit);
      expect(d.vehicle, 'MH02AB1234');
      expect(h.said, contains(KioskCopyKey.flatNotFound));
    });

    test('offers the keyboard after two silent answers and accepts typed text', () async {
      final h = _Harness([
        speech(), speech(),
        const KioskInput.text('Sunita Devi'),
        const KioskInput.text('9988776655'),
        const KioskInput.text('A-604'),
        KioskInput.skip,
        KioskInput.no,
        KioskInput.yes,
      ]);
      expect(await runKioskConversation(h.io, h.ctx), KioskOutcome.saved);
      expect(h.said, contains(KioskCopyKey.typeInstead));
      expect(h.typingStates, contains(true));
      final d = h.saved.first;
      expect(d.name, 'Sunita Devi');
      expect(d.phone, '9988776655');
      expect(d.flat, 'A-604');
      expect(d.purpose, KioskPurpose.other);
    });

    test('suggests the previous flat to a returning visitor and waits for approval', () async {
      var approvalCalls = 0;
      final h = _Harness(
        [
          speech('Priya'), KioskInput.yes,
          speech('9000000001'), KioskInput.yes,
          KioskInput.yes, // same flat as last time
          speech('guest'),
          KioskInput.no,
          KioskInput.yes,
        ],
        findPreviousVisit: (_) => const KioskPreviousVisit(name: 'PRIYA', flatNumber: 'C-101'),
        settings: kDefaultKioskSettings.copyWith(requireApproval: true, useCloudAi: false, capturePhoto: false),
        requestApproval: (_, __) async {
          approvalCalls++;
          return KioskApprovalOutcome.approved;
        },
      );
      expect(await runKioskConversation(h.io, h.ctx), KioskOutcome.saved);
      expect(h.said, contains(KioskCopyKey.askSameFlat));
      expect(h.said, isNot(contains(KioskCopyKey.askFlat)));
      expect(approvalCalls, 1);
      final d = h.saved.first;
      expect(d.flat, 'C-101');
      expect(d.purpose, KioskPurpose.guest);
    });

    test('does not save when the resident declines', () async {
      final h = _Harness(
        [
          speech('Priya'), KioskInput.yes, speech('9000000001'), KioskInput.yes, speech('A 604'), KioskInput.yes,
          speech('visit'), KioskInput.no, KioskInput.yes,
        ],
        settings: kDefaultKioskSettings.copyWith(requireApproval: true, useCloudAi: false, capturePhoto: false),
        requestApproval: (_, __) async => KioskApprovalOutcome.rejected,
      );
      expect(await runKioskConversation(h.io, h.ctx), KioskOutcome.rejected);
      expect(h.saved, isEmpty);
    });
  });
}
