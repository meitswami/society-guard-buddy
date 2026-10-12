import '../features/comms/data/notification_compose.dart';
import '../features/comms/data/notification_repository.dart';

/// Legacy broadcast API kept for older callers. Delegates to the COMMS notification
/// pipeline (same rows + `send-push-notification` as web `NotificationCenter`).
class AdminNotificationService {
  final _repo = const NotificationRepository();

  Future<void> broadcast({
    required String societyId,
    required String title,
    required String message,
    required String createdBy,
    String targetType = 'all',
    String type = 'general',
  }) async {
    final text = message.trim();
    if (title.trim().isEmpty || text.isEmpty) {
      throw StateError('Title and message are required');
    }
    final sound = await _repo.fetchSocietyNotificationSound(societyId);
    final plan = buildNotificationSendPlan(
      title: title.trim(),
      message: text,
      type: type,
      adminName: createdBy,
      societyId: societyId,
      mode: NotificationTargetMode.all,
      selectedFlats: const [],
      selectedResidents: const [],
      media: const [],
      alertSoundKey: sound.soundKey,
      societyCustomSoundUrl: sound.soundCustomUrl,
    );
    await _repo.insertNotifications(plan.rows);
    await _repo.invokePushBestEffort(plan.pushBody);
  }
}
