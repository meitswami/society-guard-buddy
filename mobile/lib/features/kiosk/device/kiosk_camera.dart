import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../logic/kiosk_framing.dart';
import 'kiosk_frame_codec.dart';

enum KioskCameraState { starting, ready, denied, error }

/// Web `KioskDetectorState` (`mediapipe` / `native` → [mlkit] on the app).
enum KioskDetectorState { loading, mlkit, none }

/// Gap between face detections (web `DETECT_INTERVAL_MS`).
const Duration kDetectInterval = Duration(milliseconds: 160);

/// Front camera + continuous face framing for the AI kiosk — port of web
/// `useKioskCamera` (camera image stream + ML Kit face detection, same thresholds).
/// [framedSince] is when the face became properly framed (null when it isn't).
class KioskCamera extends ChangeNotifier {
  KioskCamera();

  /// Cameras can only be opened once at a time; a new instance waits for the
  /// previous one to release the device.
  static Future<void> _lastRelease = Future.value();

  CameraController? _controller;
  CameraDescription? _description;
  FaceDetector? _detector;
  bool _disposed = false;
  bool _active = false;
  int _attempt = 0;

  /// Completes when the current open attempt has finished (or cleaned up after itself).
  Future<void> _opening = Future.value();

  KioskCameraState cameraState = KioskCameraState.starting;
  KioskDetectorState detectorState = KioskDetectorState.loading;
  FramingStatus framing = FramingStatus.none;
  DateTime? framedSince;
  DateTime? _lastFaceAt;

  CameraImage? _latest;
  bool _busy = false;
  DateTime _nextDetectAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _failures = 0;

  /// Controller for [CameraPreview] (null until ready).
  CameraController? get controller => cameraState == KioskCameraState.ready ? _controller : null;

  bool get faceDetection => detectorState == KioskDetectorState.mlkit;

  /// Starts the camera (and the detector). Safe to call again after [stop].
  Future<void> start() async {
    if (_disposed) return;
    _active = true;
    final attempt = ++_attempt;
    _setCamera(KioskCameraState.starting);
    await _lastRelease;
    if (!_isCurrent(attempt)) return;

    // Detector (web `createKioskFaceDetector`).
    if (_detector == null) {
      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
        detectorState = KioskDetectorState.none;
      } else {
        try {
          _detector = FaceDetector(
            options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast, minFaceSize: 0.05),
          );
          detectorState = KioskDetectorState.mlkit;
        } catch (_) {
          detectorState = KioskDetectorState.none;
        }
      }
      _notify();
    }

    final opening = Completer<void>();
    _opening = opening.future;
    try {
      await _open(attempt);
    } finally {
      opening.complete();
    }
  }

  Future<void> _open(int attempt) async {
    CameraController? controller;
    try {
      final cameras = await availableCameras().timeout(const Duration(seconds: 12));
      if (!_isCurrent(attempt)) return;
      if (cameras.isEmpty) {
        _setCamera(KioskCameraState.error);
        return;
      }
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final description = front.isNotEmpty ? front.first : cameras.first;
      _description = description;
      controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      // Some devices never answer the permission request (web: 12 s hang guard).
      await controller.initialize().timeout(const Duration(seconds: 12));
      if (!_isCurrent(attempt)) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      if (faceDetection) {
        try {
          await controller.startImageStream(_onFrame);
        } catch (_) {
          detectorState = KioskDetectorState.none;
        }
      }
      _setCamera(KioskCameraState.ready);
    } on CameraException catch (e) {
      await _safeDispose(controller);
      if (!_isCurrent(attempt)) return;
      final code = e.code.toLowerCase();
      _setCamera(code.contains('denied') || code.contains('restricted') || code.contains('permission')
          ? KioskCameraState.denied
          : KioskCameraState.error);
    } catch (_) {
      await _safeDispose(controller);
      if (_isCurrent(attempt)) _setCamera(KioskCameraState.error);
    }
  }

  bool _isCurrent(int attempt) => !_disposed && _active && attempt == _attempt;

  /// Web `retryCamera`.
  Future<void> retry() async {
    await stop();
    if (_disposed) return;
    if (detectorState == KioskDetectorState.none && _detector != null) detectorState = KioskDetectorState.mlkit;
    _failures = 0;
    await start();
  }

  /// Releases the camera (detector stays loaded).
  Future<void> stop() async {
    _active = false;
    _attempt++;
    final c = _controller;
    _controller = null;
    _latest = null;
    _resetFraming();
    final release = Future.wait([_opening, _safeDispose(c)]);
    _lastRelease = release;
    await release;
  }

  static Future<void> _safeDispose(CameraController? c) async {
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  void _resetFraming() {
    final changed = framing != FramingStatus.none || framedSince != null;
    framing = FramingStatus.none;
    framedSince = null;
    if (changed) _notify();
  }

  void _setCamera(KioskCameraState s) {
    cameraState = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── detection loop ──

  void _onFrame(CameraImage image) {
    _latest = image;
    if (_busy || !faceDetection || _disposed || !_active) return;
    final now = DateTime.now();
    if (now.isBefore(_nextDetectAt)) return;
    _busy = true;
    unawaited(_detect(image));
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Clockwise rotation that makes the streamed frame upright (ML Kit example logic).
  int _rotationDegrees() {
    final d = _description;
    final c = _controller;
    if (d == null || c == null) return 0;
    if (Platform.isIOS) return d.sensorOrientation;
    final comp = _orientations[c.value.deviceOrientation] ?? 0;
    return d.lensDirection == CameraLensDirection.front
        ? (d.sensorOrientation + comp) % 360
        : (d.sensorOrientation - comp + 360) % 360;
  }

  Future<void> _detect(CameraImage image) async {
    try {
      final detector = _detector;
      if (detector == null) return;
      final input = _inputImage(image);
      if (input == null) return;
      final rotation = _rotationDegrees();
      final faces = await detector.processImage(input);
      if (_disposed || !_active) return;
      final rotated = rotation == 90 || rotation == 270;
      final w = (rotated ? image.height : image.width).toDouble();
      final h = (rotated ? image.width : image.height).toDouble();
      final boxes = [
        for (final f in faces)
          FaceBox(
            x: f.boundingBox.left / w,
            y: f.boundingBox.top / h,
            width: f.boundingBox.width / w,
            height: f.boundingBox.height / h,
          ),
      ];
      final status = evaluateFraming(boxes).status;
      final now = DateTime.now();
      var changed = false;
      if (status != FramingStatus.none) _lastFaceAt = now;
      if (status == FramingStatus.framed) {
        if (framedSince == null) {
          framedSince = now;
          changed = true;
        }
      } else if (framedSince != null) {
        framedSince = null;
        changed = true;
      }
      if (status != framing) {
        framing = status;
        changed = true;
      }
      _failures = 0;
      if (changed) _notify();
    } catch (_) {
      // A dropped frame is fine; a detector that never works is not.
      if (++_failures == 25) {
        detectorState = KioskDetectorState.none;
        _notify();
      }
    } finally {
      _busy = false;
      _nextDetectAt = DateTime.now().add(kDetectInterval);
    }
  }

  InputImage? _inputImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw is int ? image.format.raw as int : -1);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    final rotation = InputImageRotationValue.fromRawValue(_rotationDegrees());
    if (rotation == null) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Milliseconds since a face was last seen (infinity if never) — web `msSinceFace`.
  double msSinceFace() {
    final at = _lastFaceAt;
    return at == null ? double.infinity : DateTime.now().difference(at).inMilliseconds.toDouble();
  }

  /// JPEG data URL of the current frame (max 640 px), or null — web `captureFrame`.
  Future<String?> captureFrame() async {
    try {
      final image = _latest;
      if (image != null && image.planes.length == 1) {
        final plane = image.planes.first;
        final format = Platform.isIOS ? KioskFrameFormat.bgra8888 : KioskFrameFormat.nv21;
        return await encodeKioskFrame(KioskFrame(
          bytes: Uint8List.fromList(plane.bytes),
          width: image.width,
          height: image.height,
          bytesPerRow: plane.bytesPerRow,
          format: format,
          rotation: _rotationDegrees(),
        )).timeout(const Duration(seconds: 4));
      }
      final c = _controller;
      if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return null;
      final file = await c.takePicture().timeout(const Duration(seconds: 5));
      return await encodeKioskJpeg(await file.readAsBytes()).timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _attempt++;
    final c = _controller;
    _controller = null;
    _latest = null;
    _lastRelease = Future.wait([_opening, _safeDispose(c)]);
    final d = _detector;
    _detector = null;
    if (d != null) unawaited(d.close().catchError((_) {}));
    super.dispose();
  }
}
