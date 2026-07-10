import { useRef, useState, useCallback, useEffect } from 'react';
import { Camera, X, ImagePlus } from 'lucide-react';

interface Props {
  photos: string[];
  onChange: (photos: string[]) => void;
  maxPhotos?: number;
  label?: string;
}

const compressImage = (dataUrl: string, maxWidth = 800, quality = 0.7): Promise<string> => {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      const ratio = Math.min(maxWidth / img.width, maxWidth / img.height, 1);
      canvas.width = img.width * ratio;
      canvas.height = img.height * ratio;
      const ctx = canvas.getContext('2d')!;
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      resolve(canvas.toDataURL('image/jpeg', quality));
    };
    img.src = dataUrl;
  });
};

const stopMediaStream = (mediaStream: MediaStream | null | undefined) => {
  mediaStream?.getTracks().forEach((track) => track.stop());
};

const PhotoCapture = ({ photos, onChange, maxPhotos = 3, label = 'Photos' }: Props) => {
  const fileRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [showCamera, setShowCamera] = useState(false);

  const releaseCamera = useCallback(() => {
    stopMediaStream(streamRef.current);
    streamRef.current = null;
    if (videoRef.current) videoRef.current.srcObject = null;
    setShowCamera(false);
  }, []);

  useEffect(() => () => {
    stopMediaStream(streamRef.current);
    streamRef.current = null;
  }, []);

  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;
    for (const file of Array.from(files)) {
      if (photos.length >= maxPhotos) break;
      const reader = new FileReader();
      reader.onload = async () => {
        const compressed = await compressImage(reader.result as string);
        onChange([...photos, compressed]);
      };
      reader.readAsDataURL(file);
    }
    e.target.value = '';
  };

  const startCamera = useCallback(async () => {
    try {
      releaseCamera();
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 800 }, height: { ideal: 600 } },
      });
      streamRef.current = mediaStream;
      mediaStream.getVideoTracks().forEach((track) => {
        track.addEventListener('ended', () => {
          if (streamRef.current === mediaStream) releaseCamera();
        });
      });
      setShowCamera(true);
      requestAnimationFrame(() => {
        if (videoRef.current && streamRef.current === mediaStream) {
          videoRef.current.srcObject = mediaStream;
        }
      });
    } catch {
      // Camera not available, fallback to file picker
      fileRef.current?.click();
    }
  }, [releaseCamera]);

  const capturePhoto = useCallback(async () => {
    if (!videoRef.current) return;
    const canvas = document.createElement('canvas');
    canvas.width = videoRef.current.videoWidth;
    canvas.height = videoRef.current.videoHeight;
    canvas.getContext('2d')!.drawImage(videoRef.current, 0, 0);
    const compressed = await compressImage(canvas.toDataURL('image/jpeg'));
    onChange([...photos, compressed]);
    releaseCamera();
  }, [photos, onChange, releaseCamera]);

  const removePhoto = (index: number) => {
    onChange(photos.filter((_, i) => i !== index));
  };

  return (
    <div>
      <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
        {label} ({photos.length}/{maxPhotos})
      </label>

      {/* Photo previews */}
      {photos.length > 0 && (
        <div className="flex gap-2 mb-2 flex-wrap">
          {photos.map((p, i) => (
            <div key={i} className="relative w-16 h-16 rounded-lg overflow-hidden border border-border">
              <img src={p} alt={`Photo ${i + 1}`} className="w-full h-full object-cover" />
              <button
                type="button"
                onClick={() => removePhoto(i)}
                className="absolute top-0 right-0 bg-destructive text-destructive-foreground rounded-bl-md p-0.5"
              >
                <X className="w-3 h-3" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Camera view */}
      {showCamera && (
        <div className="relative mb-2 rounded-lg overflow-hidden border border-border">
          <video ref={videoRef} autoPlay playsInline muted className="w-full h-48 object-cover bg-black" />
          <div className="absolute bottom-2 left-0 right-0 flex justify-center gap-3">
            <button type="button" onClick={capturePhoto} className="bg-primary text-primary-foreground rounded-full p-3">
              <Camera className="w-5 h-5" />
            </button>
            <button type="button" onClick={releaseCamera} className="bg-secondary text-secondary-foreground rounded-full p-3">
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>
      )}

      {/* Action buttons */}
      {photos.length < maxPhotos && !showCamera && (
        <div className="flex gap-2">
          <button type="button" onClick={startCamera} className="btn-secondary text-xs flex-1 flex items-center justify-center gap-1.5 py-2">
            <Camera className="w-3.5 h-3.5" /> Camera
          </button>
          <button type="button" onClick={() => fileRef.current?.click()} className="btn-secondary text-xs flex-1 flex items-center justify-center gap-1.5 py-2">
            <ImagePlus className="w-3.5 h-3.5" /> Upload
          </button>
        </div>
      )}

      <input ref={fileRef} type="file" accept="image/*" multiple className="hidden" onChange={handleFile} />
    </div>
  );
};

export default PhotoCapture;
