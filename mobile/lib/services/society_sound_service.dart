import '../features/comms/data/notification_repository.dart';
import '../features/comms/data/notification_sound_player.dart';

/// Society signature / notification tune (`societies.admin_push_sound_url`) — web
/// `societyNotificationSound.ts`. Playback goes through the shared COMMS sound player.
class SocietySoundService {
  SocietySoundService();

  /// Web plays once per browser-tab session (`sessionStorage`); mobile: once per app run.
  static final Set<String> _playedThisSession = {};

  Future<String?> fetchSoundUrl(String societyId) async {
    if (societyId.isEmpty) return null;
    try {
      return await const NotificationRepository()
          .fetchSocietySoundUrl(societyId);
    } catch (_) {
      return null;
    }
  }

  Future<void> playUrl(String url) => playNotificationAlert('custom', url);

  /// Web `playSocietySignatureTuneOnOpen(societyId, { force })`.
  Future<void> playSignatureTuneOnOpen(String societyId,
      {bool force = false}) async {
    if (societyId.isEmpty) return;
    if (!force && _playedThisSession.contains(societyId)) return;
    final url = await fetchSoundUrl(societyId);
    if (url == null) return;
    await playNotificationAlert('custom', url);
    _playedThisSession.add(societyId);
  }

  /// Kept for callers that dispose the service; the player is shared.
  Future<void> dispose() async {}
}
