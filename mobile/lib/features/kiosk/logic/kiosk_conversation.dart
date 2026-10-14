/// The AI receptionist's dialogue: asks each visitor detail by voice, reads it back,
/// and hands a finished draft to the page for approval + saving.
/// 1:1 port of web `src/lib/kiosk/kioskConversation.ts`. UI, speech, camera, network
/// and the cloud AI are injected through [KioskIO] / [KioskContext] — pure Dart.
library;

import 'dart:async';

import 'kiosk_copy.dart';
import 'kiosk_parsers.dart';
import 'kiosk_settings.dart';
import 'kiosk_signal.dart';

/// The visitor switched the kiosk language mid-sentence; the current line is re-asked.
class LanguageChangedError implements Exception {
  const LanguageChangedError();

  @override
  String toString() => 'LanguageChangedError: language changed';
}

enum KioskStep { greeting, name, phone, flat, purpose, vehicle, summary, approval, saving, done, blocked, failed }

/// Visitor details collected so far (web `KioskDraft`).
class KioskDraft {
  const KioskDraft({
    this.nameDisplay = '',
    this.name = '',
    this.phone = '',
    this.flat = '',
    this.purpose,
    this.company,
    this.vehicleAsked = false,
    this.vehicle,
    this.photo,
  });

  /// Web `EMPTY_DRAFT`.
  static const KioskDraft empty = KioskDraft();

  /// As the visitor said it (may be Devanagari).
  final String nameDisplay;

  /// Roman script, stored in the visitor log.
  final String name;
  final String phone;
  final String flat;

  /// null = not answered yet (web `''`).
  final KioskPurpose? purpose;
  final String? company;

  /// false = vehicle not asked yet (web `vehicle === undefined`).
  final bool vehicleAsked;

  /// Registration number; null together with [vehicleAsked] = no vehicle (web `null`).
  final String? vehicle;

  /// JPEG data URL from the kiosk camera.
  final String? photo;

  KioskDraft copyWith({String? nameDisplay, String? name, String? phone, String? flat}) => KioskDraft(
        nameDisplay: nameDisplay ?? this.nameDisplay,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        flat: flat ?? this.flat,
        purpose: purpose,
        company: company,
        vehicleAsked: vehicleAsked,
        vehicle: vehicle,
        photo: photo,
      );

  /// Web `update({ purpose, company })` — company is replaced even when null.
  KioskDraft withPurpose(KioskPurpose purpose, String? company) => KioskDraft(
        nameDisplay: nameDisplay,
        name: name,
        phone: phone,
        flat: flat,
        purpose: purpose,
        company: company,
        vehicleAsked: vehicleAsked,
        vehicle: vehicle,
        photo: photo,
      );

  /// Web `update({ vehicle })` — null means "no vehicle".
  KioskDraft withVehicle(String? plate) => KioskDraft(
        nameDisplay: nameDisplay,
        name: name,
        phone: phone,
        flat: flat,
        purpose: purpose,
        company: company,
        vehicleAsked: true,
        vehicle: plate,
        photo: photo,
      );

  KioskDraft withPhoto(String? photo) => KioskDraft(
        nameDisplay: nameDisplay,
        name: name,
        phone: phone,
        flat: flat,
        purpose: purpose,
        company: company,
        vehicleAsked: vehicleAsked,
        vehicle: vehicle,
        photo: photo,
      );
}

enum KioskInputKind { speech, text, yes, no, skip, typeMode, edit }

/// What the visitor did (web `KioskInput`).
class KioskInput {
  const KioskInput._(this.kind, {this.alternatives = const [], this.text = '', this.field});

  /// Recogniser transcripts, best first (empty = nothing heard).
  const KioskInput.speech(List<String> alternatives) : this._(KioskInputKind.speech, alternatives: alternatives);

  /// Typed on the on-screen keyboard.
  const KioskInput.text(String text) : this._(KioskInputKind.text, text: text);

  /// Tapped "Change" next to a detail on the summary.
  const KioskInput.edit(KioskEditField field) : this._(KioskInputKind.edit, field: field);

  static const KioskInput yes = KioskInput._(KioskInputKind.yes);
  static const KioskInput no = KioskInput._(KioskInputKind.no);
  static const KioskInput skip = KioskInput._(KioskInputKind.skip);

  /// Visitor tapped "Type it" — stop listening and wait for the keyboard.
  static const KioskInput typeMode = KioskInput._(KioskInputKind.typeMode);

  final KioskInputKind kind;
  final List<String> alternatives;
  final String text;
  final KioskEditField? field;
}

enum KioskHearMode { field, yesno }

/// A line of copy with its placeholders.
class KioskLine {
  const KioskLine(this.key, [this.vars]);

  final KioskCopyKey key;
  final Map<String, String>? vars;
}

/// UI side of the conversation (web `KioskIO`).
class KioskIO {
  const KioskIO({
    required this.signal,
    required this.lang,
    required this.say,
    required this.hear,
    required this.setStep,
    required this.setDraft,
    required this.setUnderstood,
    required this.setTyping,
  });

  final KioskSignal signal;
  final KioskLang Function() lang;

  /// Show + speak a line. Throws [LanguageChangedError] if the visitor switches language.
  final Future<void> Function(KioskCopyKey key, Map<String, String>? vars) say;

  /// Wait for the visitor: speech, typed text or a tap.
  final Future<KioskInput> Function(KioskHearMode mode, {required bool typing}) hear;
  final void Function(KioskStep step) setStep;
  final void Function(KioskDraft draft) setDraft;

  /// Value the AI understood and is about to confirm (null clears).
  final void Function(String? text) setUnderstood;
  final void Function(bool on) setTyping;
}

/// A returning visitor's last entry.
class KioskPreviousVisit {
  const KioskPreviousVisit({required this.name, required this.flatNumber});

  final String name;
  final String flatNumber;
}

/// Web `KioskApprovalOutcome` (`no_flat` → [noFlat]).
enum KioskApprovalOutcome { approved, rejected, timeout, noFlat }

/// Fields the `kiosk-assistant` Edge Function can extract (web `KioskAiField`).
enum KioskAiField { name, phone, flat, purpose, vehicle, yesno, editField }

/// Web `KioskAiResult`.
class KioskAiResult {
  const KioskAiResult({required this.found, required this.value});

  final bool found;
  final String value;
}

/// Web `aiExtract` signature (returns null when the function is unavailable or slow).
typedef KioskAiExtractor = Future<KioskAiResult?> Function(
  KioskAiField field,
  List<String> transcripts,
  KioskLang lang, {
  List<String>? flats,
  String? societyId,
});

/// Society data + side effects (web `KioskContext`). IO-backed callbacks may be async.
class KioskContext {
  const KioskContext({
    required this.societyName,
    required this.societyId,
    required this.settings,
    required this.flatNumbers,
    required this.findPreviousVisit,
    required this.isBlacklisted,
    required this.capturePhoto,
    required this.requestApproval,
    required this.onApprovalTick,
    required this.saveEntry,
    this.aiExtract,
  });

  final String societyName;
  final String? societyId;
  final KioskSettings settings;
  final List<String> flatNumbers;
  final FutureOr<KioskPreviousVisit?> Function(String phone) findPreviousVisit;
  final FutureOr<bool> Function(String? phone, String? vehicle) isBlacklisted;
  final FutureOr<String?> Function() capturePhoto;
  final Future<KioskApprovalOutcome> Function(KioskDraft draft, void Function(int secondsLeft) onTick) requestApproval;
  final void Function(int secondsLeft) onApprovalTick;
  final Future<bool> Function(KioskDraft draft) saveEntry;

  /// Cloud AI fallback (`kiosk-assistant`), used only when [KioskSettings.useCloudAi] is on.
  final KioskAiExtractor? aiExtract;
}

enum KioskOutcome { saved, blocked, rejected, timeout, failed }

final RegExp _devanagariRe = RegExp('[ऀ-ॿ]');
final RegExp _aiYesRe = RegExp(r'^(yes|true)$', caseSensitive: false);
final RegExp _aiNoRe = RegExp(r'^(no|false)$', caseSensitive: false);
final RegExp _flatSpeechRe = RegExp(r'[-_/]+');
final RegExp _plateTypedRe = RegExp('[^A-Z0-9]');

/// "A-604" → "A 604" so the voice doesn't read the dash.
String _flatForSpeech(String flat) => flat.replaceAll(_flatSpeechRe, ' ');

class _NameValue {
  const _NameValue(this.display, this.latin);

  final String display;
  final String latin;
}

Future<KioskOutcome> runKioskConversation(KioskIO io, KioskContext ctx) async {
  var draft = KioskDraft.empty;
  var micBlocked = false;
  void update(KioskDraft next) {
    draft = next;
    io.setDraft(draft);
  }

  void checkAbort() {
    if (io.signal.aborted) throw const KioskAbortError();
  }

  /// say() that tolerates a language switch (false = the caller re-asks).
  Future<bool> sayOrRetry(KioskCopyKey key, [Map<String, String>? vars]) async {
    try {
      await io.say(key, vars);
      return true;
    } on LanguageChangedError {
      return false;
    }
  }

  /// hear() that tolerates a language switch / blocked mic (null = retry).
  Future<KioskInput?> hearOrRetry(KioskHearMode mode, bool typing) async {
    try {
      return await io.hear(mode, typing: typing || micBlocked);
    } on LanguageChangedError {
      return null;
    } on MicPermissionError {
      micBlocked = true;
      io.setTyping(true);
      await sayOrRetry(KioskCopyKey.noMic);
      return null;
    }
  }

  Future<KioskAiResult?> ai(KioskAiField field, List<String> alts) async {
    final extract = ctx.aiExtract;
    if (!ctx.settings.useCloudAi || extract == null) return null;
    return extract(
      field,
      alts,
      io.lang(),
      flats: field == KioskAiField.flat ? ctx.flatNumbers : null,
      societyId: ctx.societyId,
    );
  }

  /// Yes / no with taps, voice and AI fallback. Returns null if still unclear.
  Future<bool?> confirm(KioskCopyKey key, [Map<String, String>? vars]) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      checkAbort();
      if (!(await sayOrRetry(attempt == 0 ? key : KioskCopyKey.sayYesNo, vars))) {
        attempt--;
        continue;
      }
      if (attempt > 0 && !(await sayOrRetry(key, vars))) {
        attempt--;
        continue;
      }
      final input = await hearOrRetry(KioskHearMode.yesno, false);
      if (input == null) {
        attempt--;
        continue;
      }
      if (input.kind == KioskInputKind.yes) return true;
      if (input.kind == KioskInputKind.no || input.kind == KioskInputKind.skip) return false;
      if (input.kind == KioskInputKind.typeMode || input.kind == KioskInputKind.edit) {
        attempt--;
        continue;
      }
      final alts = input.kind == KioskInputKind.speech
          ? input.alternatives
          : input.kind == KioskInputKind.text
              ? [input.text]
              : const <String>[];
      if (alts.isEmpty) continue;
      final local = firstParsed(alts, parseYesNo);
      if (local != null) return local;
      final remote = await ai(KioskAiField.yesno, alts);
      if (remote != null && remote.found) {
        if (_aiYesRe.hasMatch(remote.value)) return true;
        if (_aiNoRe.hasMatch(remote.value)) return false;
      }
    }
    return null;
  }

  /// Ask one detail until it is understood (and confirmed). After two misses the
  /// on-screen keyboard is offered; typed answers are taken as confirmed.
  Future<T?> ask<T extends Object>({
    required KioskStep step,
    required KioskCopyKey prompt,
    Map<String, String>? promptVars,
    required Future<T?> Function(List<String> alts, bool typed) understand,
    KioskLine Function(List<String> alts)? notUnderstood,
    required String Function(T v) show,
    KioskLine Function(T v)? confirmLine,
    bool allowSkip = false,
  }) async {
    io.setStep(step);
    io.setUnderstood(null);
    var typing = micBlocked;
    var misses = 0;
    var skipPrompt = false;
    io.setTyping(typing);
    try {
      for (;;) {
        checkAbort();
        if (!skipPrompt && !(await sayOrRetry(prompt, promptVars))) continue;
        skipPrompt = false;
        final input = await hearOrRetry(KioskHearMode.field, typing);
        if (input == null) continue;
        if (input.kind == KioskInputKind.skip && allowSkip) return null;
        if (input.kind == KioskInputKind.typeMode) {
          typing = true;
          io.setTyping(true);
          skipPrompt = true;
          continue;
        }
        if (input.kind == KioskInputKind.yes ||
            input.kind == KioskInputKind.no ||
            input.kind == KioskInputKind.edit ||
            input.kind == KioskInputKind.skip) {
          continue;
        }

        final typed = input.kind == KioskInputKind.text;
        final alts = input.kind == KioskInputKind.speech ? input.alternatives : [input.text];
        if (alts.isEmpty || alts.first.trim().isEmpty) {
          misses++;
          if (misses >= 2 && !typing) {
            typing = true;
            io.setTyping(true);
            await sayOrRetry(KioskCopyKey.typeInstead);
          } else {
            await sayOrRetry(KioskCopyKey.didNotHear);
          }
          continue;
        }

        final value = await understand(alts, typed);
        checkAbort();
        if (value == null) {
          misses++;
          final line = notUnderstood?.call(alts) ?? const KioskLine(KioskCopyKey.didNotUnderstand);
          await sayOrRetry(line.key, line.vars);
          if (misses >= 2 && !typing) {
            typing = true;
            io.setTyping(true);
            await sayOrRetry(KioskCopyKey.typeInstead);
          }
          continue;
        }

        io.setUnderstood(show(value));
        if (typed || confirmLine == null) return value;
        final line = confirmLine(value);
        final ok = await confirm(line.key, line.vars);
        if (ok == true) return value;
        io.setUnderstood(null);
      }
    } finally {
      io.setTyping(false);
      io.setUnderstood(null);
    }
  }

  // ── individual details ──

  Future<void> askName() async {
    final v = await ask<_NameValue>(
      step: KioskStep.name,
      prompt: KioskCopyKey.askName,
      understand: (alts, typed) async {
        String? local;
        if (typed) {
          final t = alts.first.trim();
          local = t.isEmpty ? null : t;
        } else {
          local = firstParsed(alts, parseName);
        }
        final needsRoman = local == null || _devanagariRe.hasMatch(local);
        if (needsRoman && !typed) {
          final remote = await ai(KioskAiField.name, alts);
          if (remote != null && remote.found && remote.value.isNotEmpty) {
            return _NameValue(local ?? remote.value, remote.value);
          }
        }
        if (local == null) return null;
        return _NameValue(local, transliterateToLatin(local));
      },
      show: (v) => v.display == v.latin ? v.display : '${v.display} (${v.latin})',
      confirmLine: (v) => KioskLine(KioskCopyKey.confirmName, {'name': io.lang() == KioskLang.en ? v.latin : v.display}),
    );
    if (v != null) update(draft.copyWith(nameDisplay: v.display, name: v.latin));
  }

  Future<void> askPhone() async {
    final phone = await ask<String>(
      step: KioskStep.phone,
      prompt: KioskCopyKey.askPhone,
      understand: (alts, _) async {
        final local = firstParsed(alts, parsePhone);
        if (local != null) return local;
        final remote = await ai(KioskAiField.phone, alts);
        return remote != null && remote.found ? parsePhone(remote.value) : null;
      },
      show: formatPhoneForDisplay,
      confirmLine: (p) => KioskLine(KioskCopyKey.confirmPhone, {'phone': phoneForSpeech(p)}),
    );
    if (phone != null && phone.isNotEmpty) update(draft.copyWith(phone: phone));
  }

  Future<void> askFlat() async {
    var lastHeard = '';
    final flat = await ask<String>(
      step: KioskStep.flat,
      prompt: KioskCopyKey.askFlat,
      understand: (alts, _) async {
        lastHeard = '';
        for (final alt in alts) {
          final r = parseFlat(alt, ctx.flatNumbers);
          if (lastHeard.isEmpty) lastHeard = r.heard;
          final hit = r.flat;
          if (hit != null && hit.isNotEmpty) return hit;
        }
        final remote = await ai(KioskAiField.flat, alts);
        if (remote != null && remote.found) {
          final hit = parseFlat(remote.value, ctx.flatNumbers).flat;
          if (hit != null && hit.isNotEmpty) return hit;
        }
        return null;
      },
      notUnderstood: (_) => lastHeard.isNotEmpty && ctx.flatNumbers.isNotEmpty
          ? KioskLine(KioskCopyKey.flatNotFound, {'flat': lastHeard})
          : const KioskLine(KioskCopyKey.didNotUnderstand),
      show: (f) => f,
      confirmLine: (f) => KioskLine(KioskCopyKey.confirmFlat, {'flat': _flatForSpeech(f)}),
    );
    if (flat != null && flat.isNotEmpty) update(draft.copyWith(flat: flat));
  }

  Future<void> askPurpose() async {
    var tries = 0;
    final v = await ask<KioskPurposeMatch>(
      step: KioskStep.purpose,
      prompt: KioskCopyKey.askPurpose,
      understand: (alts, _) async {
        tries++;
        final local = firstParsed(alts, parsePurpose);
        if (local != null) return local;
        final remote = await ai(KioskAiField.purpose, alts);
        if (remote != null && remote.found) {
          final p = KioskPurpose.fromLabel(remote.value);
          if (p != null) return KioskPurposeMatch(p);
        }
        // Don't keep a visitor stuck on the purpose question.
        return tries >= 2 ? const KioskPurposeMatch(KioskPurpose.other) : null;
      },
      show: (v) => v.purpose.label + (v.company != null && v.company!.isNotEmpty ? ' · ${v.company}' : ''),
      allowSkip: true,
    );
    update(draft.withPurpose(v?.purpose ?? KioskPurpose.other, v?.company));
  }

  Future<void> askVehicle() async {
    io.setStep(KioskStep.vehicle);
    final has = await confirm(KioskCopyKey.askVehicle);
    if (has != true) {
      update(draft.withVehicle(null));
      return;
    }
    final plate = await ask<String>(
      step: KioskStep.vehicle,
      prompt: KioskCopyKey.askVehicleNumber,
      understand: (alts, typed) async {
        String? local;
        if (typed) {
          final t = alts.first.toUpperCase().replaceAll(_plateTypedRe, '');
          local = t.isEmpty ? null : t;
        } else {
          local = firstParsed(alts, parseVehicleNumber);
        }
        if (local != null) return local;
        final remote = await ai(KioskAiField.vehicle, alts);
        return remote != null && remote.found ? parseVehicleNumber(remote.value) : null;
      },
      show: (p) => p,
      confirmLine: (p) => KioskLine(KioskCopyKey.confirmVehicle, {'vehicle': p.split('').join(' ')}),
      allowSkip: true,
    );
    update(draft.withVehicle(plate));
  }

  Future<void> askField(KioskEditField field) async {
    switch (field) {
      case KioskEditField.name:
        await askName();
      case KioskEditField.phone:
        await askPhone();
      case KioskEditField.flat:
        await askFlat();
      case KioskEditField.purpose:
        await askPurpose();
      case KioskEditField.vehicle:
        await askVehicle();
    }
  }

  Future<KioskOutcome> blocked() async {
    io.setStep(KioskStep.blocked);
    await sayOrRetry(KioskCopyKey.blacklisted);
    return KioskOutcome.blocked;
  }

  // ── the conversation ──

  io.setDraft(draft);
  io.setStep(KioskStep.greeting);
  if (ctx.settings.capturePhoto) {
    final photo = await ctx.capturePhoto();
    if (photo != null && photo.isNotEmpty) update(draft.withPhoto(photo));
  }
  await sayOrRetry(KioskCopyKey.greeting, {'society': ctx.societyName});

  while (draft.name.isEmpty) {
    await askName();
  }
  while (draft.phone.isEmpty) {
    await askPhone();
  }
  if (await ctx.isBlacklisted(draft.phone, null)) return blocked();

  final previous = await ctx.findPreviousVisit(draft.phone);
  if (previous != null &&
      previous.flatNumber.isNotEmpty &&
      (ctx.flatNumbers.isEmpty || ctx.flatNumbers.contains(previous.flatNumber))) {
    io.setStep(KioskStep.flat);
    final same = await confirm(KioskCopyKey.askSameFlat, {'flat': _flatForSpeech(previous.flatNumber)});
    if (same == true) update(draft.copyWith(flat: previous.flatNumber));
  }
  while (draft.flat.isEmpty) {
    await askFlat();
  }
  await askPurpose();
  if (ctx.settings.askVehicle) {
    await askVehicle();
    final plate = draft.vehicle;
    if (plate != null && plate.isNotEmpty && await ctx.isBlacklisted(null, plate)) return blocked();
  } else {
    update(draft.withVehicle(null));
  }

  // Summary with corrections.
  for (var round = 0; round < 6; round++) {
    checkAbort();
    io.setStep(KioskStep.summary);
    if (!(await sayOrRetry(KioskCopyKey.summary))) continue;
    final input = await hearOrRetry(KioskHearMode.yesno, false);
    if (input == null) continue;
    KioskEditField? field;
    if (input.kind == KioskInputKind.yes) break;
    if (input.kind == KioskInputKind.edit) {
      field = input.field;
    } else if (input.kind == KioskInputKind.speech || input.kind == KioskInputKind.text) {
      final alts = input.kind == KioskInputKind.speech ? input.alternatives : [input.text];
      if (alts.isEmpty) continue;
      field = firstParsed(alts, parseEditField);
      if (field == null) {
        final yn = firstParsed(alts, parseYesNo);
        if (yn == true) break;
        if (yn == null) {
          final remote = await ai(KioskAiField.editField, alts);
          final named = remote != null && remote.found ? _editFieldByName(remote.value) : null;
          if (named != null) {
            field = named;
          } else if (remote != null && remote.found && remote.value == 'none') {
            break;
          }
        }
      }
    }
    if (field == null) {
      io.setStep(KioskStep.summary);
      await sayOrRetry(KioskCopyKey.whichField);
      final which = await hearOrRetry(KioskHearMode.field, false);
      if (which == null) continue;
      if (which.kind == KioskInputKind.edit) {
        field = which.field;
      } else if (which.kind == KioskInputKind.speech || which.kind == KioskInputKind.text) {
        final alts = which.kind == KioskInputKind.speech ? which.alternatives : [which.text];
        field = firstParsed(alts, parseEditField);
      }
    }
    if (field != null) {
      if (field == KioskEditField.phone) update(draft.copyWith(phone: ''));
      await askField(field);
      while (draft.name.isEmpty) {
        await askName();
      }
      while (draft.phone.isEmpty) {
        await askPhone();
      }
      while (draft.flat.isEmpty) {
        await askFlat();
      }
      if (await ctx.isBlacklisted(draft.phone, draft.vehicle)) return blocked();
    }
  }

  if (ctx.settings.requireApproval) {
    io.setStep(KioskStep.approval);
    await sayOrRetry(KioskCopyKey.askingResident, {'flat': _flatForSpeech(draft.flat)});
    final outcome = await ctx.requestApproval(draft, ctx.onApprovalTick);
    checkAbort();
    if (outcome == KioskApprovalOutcome.approved) {
      await sayOrRetry(KioskCopyKey.approved);
    } else if (outcome == KioskApprovalOutcome.rejected) {
      io.setStep(KioskStep.failed);
      await sayOrRetry(KioskCopyKey.rejected);
      return KioskOutcome.rejected;
    } else if (outcome == KioskApprovalOutcome.timeout) {
      io.setStep(KioskStep.failed);
      await sayOrRetry(KioskCopyKey.approvalTimeout);
      return KioskOutcome.timeout;
    }
    // noFlat: flat not in the society table — save directly, as the manual form does.
  }

  io.setStep(KioskStep.saving);
  final saved = await ctx.saveEntry(draft);
  if (!saved) {
    io.setStep(KioskStep.failed);
    await sayOrRetry(KioskCopyKey.saveFailed);
    return KioskOutcome.failed;
  }
  io.setStep(KioskStep.done);
  final doneName = io.lang() == KioskLang.en ? draft.name : (draft.nameDisplay.isNotEmpty ? draft.nameDisplay : draft.name);
  await sayOrRetry(KioskCopyKey.done, {'name': doneName});
  return KioskOutcome.saved;
}

KioskEditField? _editFieldByName(String value) {
  for (final f in KioskEditField.values) {
    if (f.name == value) return f;
  }
  return null;
}
