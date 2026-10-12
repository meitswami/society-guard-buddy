/**
 * Face detection for the AI kiosk: MediaPipe BlazeFace (wasm, self-hosted) with the
 * native Shape Detection `FaceDetector` as a fallback.
 */

export interface FaceBox {
  /** Normalised 0..1 relative to the video frame. */
  x: number;
  y: number;
  width: number;
  height: number;
  score: number;
}

export interface KioskFaceDetector {
  kind: 'mediapipe' | 'native';
  detect: (video: HTMLVideoElement, nowMs: number) => Promise<FaceBox[]>;
  close: () => void;
}

const MODEL_URL = '/models/blaze_face_short_range.tflite';

async function createMediaPipeDetector(): Promise<KioskFaceDetector> {
  const [{ FaceDetector }, loaderUrl, binaryUrl] = await Promise.all([
    import('@mediapipe/tasks-vision'),
    import('@mediapipe/tasks-vision/vision_wasm_internal.js?url').then((m) => m.default as string),
    import('@mediapipe/tasks-vision/vision_wasm_internal.wasm?url').then((m) => m.default as string),
  ]);
  const fileset = { wasmLoaderPath: loaderUrl, wasmBinaryPath: binaryUrl };
  const make = (delegate: 'GPU' | 'CPU') =>
    FaceDetector.createFromOptions(fileset, {
      baseOptions: { modelAssetPath: MODEL_URL, delegate },
      runningMode: 'VIDEO',
      minDetectionConfidence: 0.6,
    });
  let detector;
  try {
    detector = await make('GPU');
  } catch {
    detector = await make('CPU');
  }
  let lastTs = 0;
  return {
    kind: 'mediapipe',
    detect: async (video, nowMs) => {
      const vw = video.videoWidth;
      const vh = video.videoHeight;
      if (!vw || !vh) return [];
      const ts = Math.max(nowMs, lastTs + 1);
      lastTs = ts;
      const res = detector.detectForVideo(video, ts);
      return res.detections
        .filter((d) => d.boundingBox)
        .map((d) => ({
          x: d.boundingBox!.originX / vw,
          y: d.boundingBox!.originY / vh,
          width: d.boundingBox!.width / vw,
          height: d.boundingBox!.height / vh,
          score: d.categories[0]?.score ?? 0,
        }));
    },
    close: () => detector.close(),
  };
}

/* eslint-disable @typescript-eslint/no-explicit-any */
function createNativeDetector(): KioskFaceDetector | null {
  const Native = (window as any).FaceDetector;
  if (!Native) return null;
  const detector = new Native({ fastMode: true, maxDetectedFaces: 3 });
  return {
    kind: 'native',
    detect: async (video) => {
      const vw = video.videoWidth;
      const vh = video.videoHeight;
      if (!vw || !vh) return [];
      const faces: any[] = await detector.detect(video);
      return faces.map((f) => ({
        x: f.boundingBox.x / vw,
        y: f.boundingBox.y / vh,
        width: f.boundingBox.width / vw,
        height: f.boundingBox.height / vh,
        score: 1,
      }));
    },
    close: () => {},
  };
}
/* eslint-enable @typescript-eslint/no-explicit-any */

export async function createKioskFaceDetector(): Promise<KioskFaceDetector | null> {
  try {
    return await createMediaPipeDetector();
  } catch (e) {
    console.warn('MediaPipe face detector unavailable, trying native FaceDetector', e);
  }
  try {
    return createNativeDetector();
  } catch {
    return null;
  }
}

export type FramingStatus = 'none' | 'tooFar' | 'tooClose' | 'offCenter' | 'framed';

/** How well the largest face sits in the frame. */
export function evaluateFraming(faces: FaceBox[]): { status: FramingStatus; face: FaceBox | null } {
  if (!faces.length) return { status: 'none', face: null };
  const face = [...faces].sort((a, b) => b.width * b.height - a.width * a.height)[0];
  const cx = face.x + face.width / 2;
  const cy = face.y + face.height / 2;
  if (face.width < 0.2) return { status: 'tooFar', face };
  if (face.width > 0.65) return { status: 'tooClose', face };
  if (Math.abs(cx - 0.5) > 0.17 || Math.abs(cy - 0.45) > 0.22) return { status: 'offCenter', face };
  return { status: 'framed', face };
}
