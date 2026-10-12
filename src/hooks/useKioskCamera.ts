import { useCallback, useEffect, useRef, useState } from 'react';
import {
  createKioskFaceDetector,
  evaluateFraming,
  type FramingStatus,
  type KioskFaceDetector,
} from '@/lib/kiosk/kioskFaceDetector';

export type KioskCameraState = 'starting' | 'ready' | 'denied' | 'error';
export type KioskDetectorState = 'loading' | 'mediapipe' | 'native' | 'none';

const DETECT_INTERVAL_MS = 160;

/**
 * Front camera + continuous face framing for the AI kiosk.
 * `framedSince` is when the face became properly framed (null when it isn't).
 */
export function useKioskCamera(active: boolean) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const detectorRef = useRef<KioskFaceDetector | null>(null);
  const framedSinceRef = useRef<number | null>(null);
  const lastFaceAtRef = useRef(0);
  const [cameraState, setCameraState] = useState<KioskCameraState>('starting');
  const [detectorState, setDetectorState] = useState<KioskDetectorState>('loading');
  const [framing, setFraming] = useState<FramingStatus>('none');
  const [framedSince, setFramedSince] = useState<number | null>(null);

  // Camera
  useEffect(() => {
    if (!active) return;
    let cancelled = false;
    setCameraState('starting');
    (async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
          audio: false,
        });
        if (cancelled) { stream.getTracks().forEach((t) => t.stop()); return; }
        streamRef.current = stream;
        const video = videoRef.current;
        if (video) {
          video.srcObject = stream;
          await video.play().catch(() => undefined);
        }
        setCameraState('ready');
      } catch (e) {
        if (cancelled) return;
        const name = (e as DOMException)?.name;
        setCameraState(name === 'NotAllowedError' || name === 'SecurityError' ? 'denied' : 'error');
      }
    })();
    return () => {
      cancelled = true;
      streamRef.current?.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
      if (videoRef.current) videoRef.current.srcObject = null;
    };
  }, [active]);

  // Detector
  useEffect(() => {
    if (!active) return;
    let cancelled = false;
    setDetectorState('loading');
    void createKioskFaceDetector().then((d) => {
      if (cancelled) { d?.close(); return; }
      detectorRef.current = d;
      setDetectorState(d ? d.kind : 'none');
    });
    return () => {
      cancelled = true;
      detectorRef.current?.close();
      detectorRef.current = null;
    };
  }, [active]);

  // Detection loop
  useEffect(() => {
    if (!active || cameraState !== 'ready' || (detectorState !== 'mediapipe' && detectorState !== 'native')) return;
    let stopped = false;
    let timer: ReturnType<typeof setTimeout>;
    let busy = false;
    let lastStatus: FramingStatus = 'none';

    const step = async () => {
      if (stopped) return;
      const video = videoRef.current;
      const detector = detectorRef.current;
      if (!busy && video && detector && !document.hidden && video.readyState >= 2) {
        busy = true;
        try {
          const faces = await detector.detect(video, performance.now());
          const { status } = evaluateFraming(faces);
          const now = Date.now();
          if (status !== 'none') lastFaceAtRef.current = now;
          if (status === 'framed') {
            if (framedSinceRef.current === null) {
              framedSinceRef.current = now;
              setFramedSince(now);
            }
          } else if (framedSinceRef.current !== null) {
            framedSinceRef.current = null;
            setFramedSince(null);
          }
          if (status !== lastStatus) {
            lastStatus = status;
            setFraming(status);
          }
        } catch {
          /* a dropped frame is fine */
        } finally {
          busy = false;
        }
      }
      timer = setTimeout(step, DETECT_INTERVAL_MS);
    };
    void step();
    return () => {
      stopped = true;
      clearTimeout(timer);
    };
  }, [active, cameraState, detectorState]);

  /** Callback ref for the <video>; re-attaches the stream if the element remounts. */
  const attachVideo = useCallback((el: HTMLVideoElement | null) => {
    videoRef.current = el;
    const stream = streamRef.current;
    if (el && stream && el.srcObject !== stream) {
      el.srcObject = stream;
      void el.play().catch(() => undefined);
    }
  }, []);

  /** JPEG snapshot of the current frame (max 640px), or null. */
  const captureFrame = useCallback((): string | null => {
    const video = videoRef.current;
    if (!video || !video.videoWidth) return null;
    const ratio = Math.min(640 / video.videoWidth, 640 / video.videoHeight, 1);
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(video.videoWidth * ratio);
    canvas.height = Math.round(video.videoHeight * ratio);
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/jpeg', 0.72);
  }, []);

  /** Milliseconds since a face was last seen (Infinity if never). */
  const msSinceFace = useCallback(
    () => (lastFaceAtRef.current ? Date.now() - lastFaceAtRef.current : Number.POSITIVE_INFINITY),
    [],
  );

  return { attachVideo, cameraState, detectorState, framing, framedSince, captureFrame, msSinceFace };
}
