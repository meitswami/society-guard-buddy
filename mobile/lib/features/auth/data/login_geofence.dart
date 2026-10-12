import 'package:geolocator/geolocator.dart';

import '../../../core/supabase/db.dart';
import '../../../utils/geo_utils.dart';

/// Web `GeofencePolicy`:
/// - strict: no location / position errors block login (desktop guard `LoginPage`);
/// - permissive: no location / position errors allow login (`UnifiedLoginPage`).
enum GeofencePolicy { strict, permissive }

enum GeofenceBlockReason { noGeolocation, positionUnavailable, outside }

class GeofenceRow {
  const GeofenceRow({required this.latitude, required this.longitude, required this.radiusMeters});
  final double latitude;
  final double longitude;
  final double radiusMeters;
}

class GeofenceCheckResult {
  const GeofenceCheckResult.ok()
      : ok = true,
        reason = null,
        distanceM = null;
  const GeofenceCheckResult.blocked(this.reason, {this.distanceM}) : ok = false;

  final bool ok;
  final GeofenceBlockReason? reason;
  final double? distanceM;
}

/// Pure distance rule: inside when the haversine distance is within the radius.
GeofenceCheckResult evaluateGeofence({
  required double latitude,
  required double longitude,
  required GeofenceRow fence,
}) {
  final d = distanceMeters(latitude, longitude, fence.latitude, fence.longitude);
  if (d <= fence.radiusMeters) return const GeofenceCheckResult.ok();
  return GeofenceCheckResult.blocked(GeofenceBlockReason.outside, distanceM: d);
}

/// Latest `geofence_settings` row of the society (null when none / on error, like web).
Future<GeofenceRow?> fetchActiveGeofence(String societyId) async {
  if (!dbReady) return null;
  try {
    final rows = await db
        .from('geofence_settings')
        .select('latitude, longitude, radius_meters')
        .eq('society_id', societyId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rowsOf(rows);
    if (list.isEmpty) return null;
    final r = list.first;
    return GeofenceRow(
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      radiusMeters: ((r['radius_meters'] as num?) ?? 100).toDouble(),
    );
  } catch (_) {
    return null;
  }
}

/// Web `checkSocietyGeofence(societyId, policy)`.
Future<GeofenceCheckResult> checkSocietyGeofence(String societyId, GeofencePolicy policy) async {
  if (societyId.isEmpty) return const GeofenceCheckResult.ok();
  final fence = await fetchActiveGeofence(societyId);
  if (fence == null) return const GeofenceCheckResult.ok();

  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _NoPosition(GeofenceBlockReason.noGeolocation);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const _NoPosition(GeofenceBlockReason.positionUnavailable);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
    );
    return evaluateGeofence(latitude: pos.latitude, longitude: pos.longitude, fence: fence);
  } on _NoPosition catch (e) {
    if (policy == GeofencePolicy.strict) return GeofenceCheckResult.blocked(e.reason);
    return const GeofenceCheckResult.ok();
  } catch (_) {
    if (policy == GeofencePolicy.strict) {
      return const GeofenceCheckResult.blocked(GeofenceBlockReason.positionUnavailable);
    }
    return const GeofenceCheckResult.ok();
  }
}

class _NoPosition implements Exception {
  const _NoPosition(this.reason);
  final GeofenceBlockReason reason;
}
