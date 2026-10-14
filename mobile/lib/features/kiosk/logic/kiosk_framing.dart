/// Face framing rules for the AI kiosk — port of `evaluateFraming` in web
/// `src/lib/kiosk/kioskFaceDetector.ts` (same thresholds). Pure Dart.
library;

/// A detected face, normalised 0..1 relative to the (upright) camera frame.
class FaceBox {
  const FaceBox({required this.x, required this.y, required this.width, required this.height, this.score = 1});

  final double x;
  final double y;
  final double width;
  final double height;
  final double score;
}

enum FramingStatus { none, tooFar, tooClose, offCenter, framed }

/// Face narrower than this share of the frame width → "come closer".
const double kMinFaceWidth = 0.12;

/// Face wider than this share of the frame width → "step back".
const double kMaxFaceWidth = 0.7;

/// Allowed horizontal offset of the face centre from the middle (0.5).
const double kCenterBandX = 0.22;

/// Allowed vertical offset of the face centre from 0.45 (slightly above the middle).
const double kCenterBandY = 0.27;

/// How well the largest face sits in the frame.
({FramingStatus status, FaceBox? face}) evaluateFraming(List<FaceBox> faces) {
  if (faces.isEmpty) return (status: FramingStatus.none, face: null);
  final face = ([...faces]..sort((a, b) => (b.width * b.height).compareTo(a.width * a.height))).first;
  final cx = face.x + face.width / 2;
  final cy = face.y + face.height / 2;
  // Thresholds suit a phone at a gate: a face ~1 m away is roughly 15–20% of the frame width.
  if (face.width < kMinFaceWidth) return (status: FramingStatus.tooFar, face: face);
  if (face.width > kMaxFaceWidth) return (status: FramingStatus.tooClose, face: face);
  if ((cx - 0.5).abs() > kCenterBandX || (cy - 0.45).abs() > kCenterBandY) {
    return (status: FramingStatus.offCenter, face: face);
  }
  return (status: FramingStatus.framed, face: face);
}
