import 'dart:typed_data';

import '../features/comms/data/emergency_alert_service.dart';

export '../features/comms/data/emergency_alert_service.dart'
    show EmergencyAlertResult;

/// Legacy API kept for older callers; delegates to the COMMS `EmergencyAlertService`
/// (web `sendEmergencyAlert` → `send-emergency-alert`).
class EmergencyService {
  Future<EmergencyAlertResult> sendAlert({
    required String societyId,
    required String title,
    required String message,
    required String senderRole,
    required String senderName,
    String? senderFlatNumber,
    List<({Uint8List bytes, String mimeType, String fileName})> images =
        const [],
  }) {
    return const EmergencyAlertService().send(
      societyId: societyId,
      title: title.trim().isEmpty ? kEmergencyDefaultTitle : title.trim(),
      message: message.trim(),
      senderRole: senderRole,
      senderName: senderName,
      senderFlatNumber: senderFlatNumber,
      images: [
        for (final i in images)
          EmergencyImage(
              bytes: i.bytes, fileName: i.fileName, mimeType: i.mimeType)
      ],
    );
  }
}
