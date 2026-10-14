import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';
import '../logic/kiosk_conversation.dart';
import '../logic/kiosk_signal.dart';

/// Same request the guard's "Ask permission" button sends (`approval_requests` row +
/// realtime wait), without the modal UI — port of web `requestResidentApproval`
/// (`src/lib/kiosk/kioskApproval.ts`). Throws [KioskAbortError] when [signal] aborts.
Future<KioskApprovalOutcome> requestResidentApproval({
  required String societyId,
  required String flatNumber,
  required String visitorName,
  required String visitorPhone,
  required String purpose,
  required String guardId,
  required String guardName,
  int timeoutSec = 120,
  KioskSignal? signal,
  void Function(int secondsLeft)? onTick,
}) async {
  if (!dbReady) return KioskApprovalOutcome.noFlat;
  final Map<String, dynamic>? flat;
  try {
    flat = await db
        .from('flats')
        .select('id')
        .eq('flat_number', flatNumber)
        .eq('society_id', societyId)
        .maybeSingle();
  } catch (_) {
    // supabase-js resolves `{ data: null }` on errors → treated as "no flat".
    return KioskApprovalOutcome.noFlat;
  }
  if (flat == null) return KioskApprovalOutcome.noFlat;

  final Map<String, dynamic> request;
  try {
    request = await db
        .from('approval_requests')
        .insert({
          'visitor_name': visitorName,
          'visitor_phone': visitorPhone.isEmpty ? null : visitorPhone,
          'flat_number': flatNumber,
          'flat_id': flat['id'],
          'guard_id': guardId,
          'guard_name': guardName,
          'purpose': purpose.isEmpty ? null : purpose,
          'status': 'pending',
        })
        .select()
        .single();
  } catch (_) {
    return KioskApprovalOutcome.noFlat;
  }
  final requestId = '${request['id']}';
  if (signal?.aborted ?? false) throw const KioskAbortError();

  final done = Completer<KioskApprovalOutcome>();
  var left = timeoutSec;
  var settled = false;
  RealtimeChannel? channel;
  Timer? poll;
  Timer? tick;
  void Function()? removeAbort;

  void finish(KioskApprovalOutcome? outcome) {
    if (settled) return;
    settled = true;
    poll?.cancel();
    tick?.cancel();
    removeAbort?.call();
    final ch = channel;
    if (ch != null) unawaited(db.removeChannel(ch).catchError((_) => ''));
    if (outcome != null) {
      done.complete(outcome);
    } else {
      done.completeError(const KioskAbortError());
    }
  }

  KioskApprovalOutcome? fromStatus(Object? status) => switch (status) {
        'approved' => KioskApprovalOutcome.approved,
        'rejected' => KioskApprovalOutcome.rejected,
        _ => null,
      };

  try {
    channel = db
        .channel('kiosk-approval-$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'approval_requests',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: requestId),
          callback: (payload) {
            final outcome = fromStatus(payload.newRecord['status']);
            if (outcome != null) finish(outcome);
          },
        )
        .subscribe();
  } catch (_) {
    // Realtime unavailable — the 5 s poll below still picks up the answer.
  }

  // Poll as well, in case the realtime socket is slow on mobile data.
  poll = Timer.periodic(const Duration(seconds: 5), (_) async {
    try {
      final row = await db.from('approval_requests').select('status').eq('id', requestId).maybeSingle();
      final outcome = fromStatus(row?['status']);
      if (outcome != null) finish(outcome);
    } catch (_) {
      // Try again on the next tick.
    }
  });

  tick = Timer.periodic(const Duration(seconds: 1), (_) {
    left -= 1;
    onTick?.call(left);
    if (left <= 0) finish(KioskApprovalOutcome.timeout);
  });
  onTick?.call(left);

  removeAbort = signal?.onAbort(() => finish(null));
  return done.future;
}
