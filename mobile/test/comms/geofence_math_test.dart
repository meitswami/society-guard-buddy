import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/data/geofence_math.dart';

void main() {
  group('getDistanceMeters (haversine)', () {
    test('same point is 0 m', () {
      expect(getDistanceMeters(28.6139, 77.2090, 28.6139, 77.2090), 0);
    });

    test('one degree of latitude ≈ 111.2 km', () {
      final d = getDistanceMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 50));
    });

    test('New Delhi → Mumbai ≈ 1,148 km', () {
      final d = getDistanceMeters(28.6139, 77.2090, 19.0760, 72.8777);
      expect(d, closeTo(1148095, 5));
    });

    test('symmetric', () {
      final a = getDistanceMeters(12.97, 77.59, 13.08, 80.27);
      final b = getDistanceMeters(13.08, 80.27, 12.97, 77.59);
      expect(a, closeTo(b, 1e-6));
    });

    test('~100 m east at the equator', () {
      final d = getDistanceMeters(0, 0, 0, 0.0009);
      expect(d, closeTo(100.08, 0.5));
    });
  });

  group('evaluateGeofence (web checkSocietyGeofence)', () {
    const fence = GeofenceFence(latitude: 28.6139, longitude: 77.2090, radiusMeters: 500);

    test('no fence → allowed', () {
      final r = evaluateGeofence(fence: null, policy: GeofencePolicy.strict);
      expect(r.ok, isTrue);
    });

    test('inside the radius → allowed (boundary inclusive)', () {
      expect(evaluateGeofence(fence: fence, policy: GeofencePolicy.strict, latitude: 28.6139, longitude: 77.2090).ok, isTrue);
      final edge = GeofenceFence(latitude: 0, longitude: 0, radiusMeters: getDistanceMeters(0, 0, 0, 0.001));
      expect(evaluateGeofence(fence: edge, policy: GeofencePolicy.strict, latitude: 0, longitude: 0.001).ok, isTrue);
    });

    test('outside → outside with distance', () {
      final r = evaluateGeofence(fence: fence, policy: GeofencePolicy.permissive, latitude: 28.70, longitude: 77.2090);
      expect(r.ok, isFalse);
      expect(r.reason, GeofenceFailReason.outside);
      expect(r.distanceM, greaterThan(9000));
    });

    test('position errors: strict blocks, permissive allows', () {
      final strict = evaluateGeofence(fence: fence, policy: GeofencePolicy.strict, positionFailed: true);
      expect(strict.ok, isFalse);
      expect(strict.reason, GeofenceFailReason.positionUnavailable);
      final noGeo = evaluateGeofence(fence: fence, policy: GeofencePolicy.strict, positionFailed: true, geolocationAvailable: false);
      expect(noGeo.reason, GeofenceFailReason.noGeolocation);
      expect(evaluateGeofence(fence: fence, policy: GeofencePolicy.permissive, positionFailed: true).ok, isTrue);
    });
  });

  group('GeofenceSetup inputs', () {
    test('radius snaps to the 50 m slider grid within 50…2000', () {
      expect(snapGeofenceRadius(500), 500);
      expect(snapGeofenceRadius(524), 500);
      expect(snapGeofenceRadius(526), 550);
      expect(snapGeofenceRadius(10), 50);
      expect(snapGeofenceRadius(9999), 2000);
    });

    test('coordinate parsing and range checks', () {
      expect(parseCoordinate(' 28.6139 '), 28.6139);
      expect(parseCoordinate('abc'), isNull);
      expect(parseCoordinate(''), isNull);
      expect(isValidLatitude(90), isTrue);
      expect(isValidLatitude(-90.0001), isFalse);
      expect(isValidLongitude(180), isTrue);
      expect(isValidLongitude(181), isFalse);
      expect(isValidLatitude(null), isFalse);
    });

    test('toFixed(6) display', () {
      expect(formatCoordinate(28.61393912), '28.613939');
      expect(formatCoordinate(77.2), '77.200000');
    });
  });
}
