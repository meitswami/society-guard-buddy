import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/supabase/db.dart';
import '../../utils/geo_utils.dart';
import '../gate/data/gate_audit.dart';

/// Breach reasons written to `audit_logs.details.reason` (web values).
abstract final class GeofenceBreach {
  static const outsideRadius = 'outside_radius';
  static const locationDisabled = 'location_disabled';
}

/// Pure state machine of web `useGuardGeofenceMonitor`: arms after the first fix inside the
/// fence (avoids noisy GPS at start-up), alerts once per breach, re-arms when back inside.
class GeofenceBreachTracker {
  bool armed = false;
  bool breachActive = false;

  /// Returns the breach reason to report for this fix, or null.
  String? onFix(
      {required double distanceMeters, required double radiusMeters}) {
    if (distanceMeters <= radiusMeters) {
      armed = true;
      breachActive = false;
      return null;
    }
    if (!armed || breachActive) return null;
    breachActive = true;
    return GeofenceBreach.outsideRadius;
  }

  /// Location lost / turned off. Returns the reason to report, or null.
  String? onLocationLost() {
    if (!armed || breachActive) return null;
    breachActive = true;
    return GeofenceBreach.locationDisabled;
  }
}

/// Watches the device location during a guard shift against the society's latest geofence.
/// On a breach it calls [onBreach] (the shell shows the 10 s toast) and writes a
/// `geofence_violation` audit row like the web hook.
class GuardGeofenceMonitor {
  GuardGeofenceMonitor({
    required this.societyId,
    required this.guardId,
    required this.guardName,
    required this.onBreach,
  });

  final String societyId;
  final String guardId;
  final String guardName;
  final void Function(String reason) onBreach;

  final _tracker = GeofenceBreachTracker();
  StreamSubscription<Position>? _positions;
  StreamSubscription<ServiceStatus>? _service;
  bool _stopped = false;

  Future<void> start() async {
    if (!dbReady) return;
    try {
      // The web query is not society-scoped; scoping it keeps multi-society installs correct.
      final rows = rowsOf(await db
          .from('geofence_settings')
          .select('latitude, longitude, radius_meters')
          .eq('society_id', societyId)
          .order('created_at', ascending: false)
          .limit(1));
      if (_stopped || rows.isEmpty) return;
      final lat = (rows.first['latitude'] as num).toDouble();
      final lng = (rows.first['longitude'] as num).toDouble();
      final radius = (rows.first['radius_meters'] as num?)?.toDouble() ?? 100;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (_stopped ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _positions = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            timeLimit: null),
      ).listen(
        (pos) {
          final reason = _tracker.onFix(
            distanceMeters:
                distanceMeters(pos.latitude, pos.longitude, lat, lng),
            radiusMeters: radius,
          );
          if (reason != null) {
            _report(reason, {
              'distance_meters':
                  distanceMeters(pos.latitude, pos.longitude, lat, lng).round()
            });
          }
        },
        onError: (Object e) {
          final reason = _tracker.onLocationLost();
          if (reason != null) {
            _report(reason, {
              'error_code': e.runtimeType.toString(),
              'message': e.toString()
            });
          }
        },
        cancelOnError: false,
      );
      try {
        _service = Geolocator.getServiceStatusStream().listen((status) {
          if (status != ServiceStatus.disabled) return;
          final reason = _tracker.onLocationLost();
          if (reason != null) {
            _report(reason, {
              'error_code': 'service_disabled',
              'message': 'Location services turned off'
            });
          }
        });
      } catch (_) {
        // Not supported on this platform.
      }
    } catch (_) {
      // No geofence / location unavailable at start: nothing to watch (web behaviour).
    }
  }

  void _report(String reason, Map<String, dynamic> extra) {
    if (_stopped) return;
    onBreach(reason);
    unawaited(GateAudit.log(
      societyId: societyId,
      eventType: 'geofence_violation',
      userType: 'guard',
      userId: guardId,
      userName: guardName,
      details: {'reason': reason, ...extra},
      severity: 'warning',
    ));
  }

  Future<void> stop() async {
    _stopped = true;
    await _positions?.cancel();
    await _service?.cancel();
    _positions = null;
    _service = null;
  }
}
