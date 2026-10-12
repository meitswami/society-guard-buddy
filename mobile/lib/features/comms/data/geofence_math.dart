/// Port of `src/lib/geofenceUtils.ts` (pure parts) and the `GeofenceSetup.tsx` input rules.
library;

import 'dart:math' as math;

/// Haversine distance in meters between two WGS84 points (web `getDistanceMeters`).
double getDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.pow(math.sin(dLon / 2), 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// strict: missing location / errors block login (guard login).
/// permissive: missing location / errors allow login (unified login).
enum GeofencePolicy { strict, permissive }

enum GeofenceFailReason { noGeolocation, positionUnavailable, outside }

class GeofenceFence {
  const GeofenceFence(
      {required this.latitude,
      required this.longitude,
      required this.radiusMeters});

  final double latitude;
  final double longitude;
  final double radiusMeters;
}

class GeofenceCheckResult {
  const GeofenceCheckResult.ok()
      : ok = true,
        reason = null,
        distanceM = null;

  const GeofenceCheckResult.fail(this.reason, {this.distanceM}) : ok = false;

  final bool ok;
  final GeofenceFailReason? reason;
  final double? distanceM;
}

/// Decision logic of web `checkSocietyGeofence` once the fence and the device position
/// (or the position error) are known.
GeofenceCheckResult evaluateGeofence({
  required GeofenceFence? fence,
  required GeofencePolicy policy,
  double? latitude,
  double? longitude,
  bool positionFailed = false,
  bool geolocationAvailable = true,
}) {
  if (fence == null) return const GeofenceCheckResult.ok();
  if (positionFailed || latitude == null || longitude == null) {
    if (policy == GeofencePolicy.strict) {
      return GeofenceCheckResult.fail(
        geolocationAvailable
            ? GeofenceFailReason.positionUnavailable
            : GeofenceFailReason.noGeolocation,
      );
    }
    return const GeofenceCheckResult.ok();
  }
  final d =
      getDistanceMeters(latitude, longitude, fence.latitude, fence.longitude);
  if (d <= fence.radiusMeters) return const GeofenceCheckResult.ok();
  return GeofenceCheckResult.fail(GeofenceFailReason.outside, distanceM: d);
}

/// Radius slider in `GeofenceSetup.tsx`: 50 … 2000 m in steps of 50, default 500.
const int kGeofenceMinRadius = 50;
const int kGeofenceMaxRadius = 2000;
const int kGeofenceRadiusStep = 50;
const int kGeofenceDefaultRadius = 500;

/// Snap a radius to the slider grid.
int snapGeofenceRadius(num value) {
  final snapped = (value / kGeofenceRadiusStep).round() * kGeofenceRadiusStep;
  return snapped.clamp(kGeofenceMinRadius, kGeofenceMaxRadius).toInt();
}

/// `parseFloat` for the latitude / longitude inputs (null when not a finite number).
double? parseCoordinate(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null || !v.isFinite) return null;
  return v;
}

bool isValidLatitude(double? v) =>
    v != null && v.isFinite && v >= -90 && v <= 90;

bool isValidLongitude(double? v) =>
    v != null && v.isFinite && v >= -180 && v <= 180;

/// `toFixed(6)` display of an existing fence.
String formatCoordinate(double v) => v.toStringAsFixed(6);
