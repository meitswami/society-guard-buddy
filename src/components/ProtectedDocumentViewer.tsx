import { useCallback, useEffect, useRef, useState } from 'react';
import { X, Eye, ShieldAlert } from 'lucide-react';

const BLOCKED_KEYS = new Set(['c', 'p', 's', 'a', 'u', 'x']);

type Props = {
  title: string;
  signedUrl: string;
  mimeType?: string | null;
  watermark: string;
  onClose: () => void;
  /** When true, image/PDF content is heavily blurred (member default until admin reveals). */
  contentBlurred?: boolean;
  /** Seconds remaining on an active member reveal window. */
  revealSecondsLeft?: number | null;
};

export default function ProtectedDocumentViewer({
  title,
  signedUrl,
  mimeType,
  watermark,
  onClose,
  contentBlurred = false,
  revealSecondsLeft = null,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [obscured, setObscured] = useState(false);

  const blockEvent = useCallback((e: Event) => {
    e.preventDefault();
    e.stopPropagation();
    return false;
  }, []);

  useEffect(() => {
    const onVisibility = () => setObscured(document.hidden);
    document.addEventListener('visibilitychange', onVisibility);
    return () => document.removeEventListener('visibilitychange', onVisibility);
  }, []);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'PrintScreen') {
        e.preventDefault();
        setObscured(true);
        window.setTimeout(() => setObscured(false), 1500);
        return;
      }
      if (!(e.ctrlKey || e.metaKey)) return;
      if (BLOCKED_KEYS.has(e.key.toLowerCase())) e.preventDefault();
    };

    const onCopy = (e: ClipboardEvent) => blockEvent(e);
    const onCut = (e: ClipboardEvent) => blockEvent(e);
    const onPaste = (e: ClipboardEvent) => blockEvent(e);
    const onContextMenu = (e: MouseEvent) => blockEvent(e);
    const onDragStart = (e: DragEvent) => blockEvent(e);

    document.addEventListener('keydown', onKeyDown, true);
    document.addEventListener('copy', onCopy, true);
    document.addEventListener('cut', onCut, true);
    document.addEventListener('paste', onPaste, true);
    document.addEventListener('contextmenu', onContextMenu, true);
    document.addEventListener('dragstart', onDragStart, true);

    return () => {
      document.removeEventListener('keydown', onKeyDown, true);
      document.removeEventListener('copy', onCopy, true);
      document.removeEventListener('cut', onCut, true);
      document.removeEventListener('paste', onPaste, true);
      document.removeEventListener('contextmenu', onContextMenu, true);
      document.removeEventListener('dragstart', onDragStart, true);
    };
  }, [blockEvent]);

  const isPdf = mimeType === 'application/pdf' || signedUrl.toLowerCase().includes('.pdf');
  const isImage = mimeType?.startsWith('image/') ?? /\.(png|jpe?g|webp|gif)(\?|$)/i.test(signedUrl);

  return (
    <div className="fixed inset-0 z-[100] bg-black/80 flex flex-col protected-doc-root">
      <style>{`
        @media print {
          .protected-doc-root, .protected-doc-root * { display: none !important; visibility: hidden !important; }
        }
        .protected-doc-surface {
          -webkit-user-select: none;
          user-select: none;
          -webkit-touch-callout: none;
        }
        .protected-doc-surface img,
        .protected-doc-surface iframe,
        .protected-doc-surface embed,
        .protected-doc-surface object {
          pointer-events: none;
          -webkit-user-drag: none;
          user-drag: none;
        }
      `}</style>

      <header className="flex items-center justify-between gap-3 px-4 py-3 bg-card border-b border-border shrink-0">
        <div className="flex items-center gap-2 min-w-0">
          <Eye className="w-4 h-4 text-primary shrink-0" />
          <div className="min-w-0">
            <p className="text-sm font-medium truncate">{title}</p>
            <p className="text-[10px] text-muted-foreground flex items-center gap-1">
              <ShieldAlert className="w-3 h-3" />
              {contentBlurred
                ? 'Preview hidden — waiting for society office to enable viewing'
                : revealSecondsLeft != null && revealSecondsLeft > 0
                  ? `Viewing enabled — ${revealSecondsLeft}s remaining`
                  : 'View only — copying, saving, and printing are disabled'}
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="p-2 rounded-lg bg-muted hover:bg-muted/80 shrink-0"
          aria-label="Close viewer"
        >
          <X className="w-5 h-5" />
        </button>
      </header>

      <div
        ref={containerRef}
        className="protected-doc-surface relative flex-1 overflow-auto bg-muted/30"
        onContextMenu={(e) => e.preventDefault()}
      >
        <div
          className={`transition-[filter] duration-500 ${contentBlurred ? 'blur-2xl scale-105' : ''}`}
        >
          {isPdf && (
            <iframe
              title={title}
              src={`${signedUrl}#toolbar=0&navpanes=0&scrollbar=1`}
              className="w-full h-full min-h-[70vh] border-0 bg-white"
              sandbox="allow-scripts allow-same-origin"
            />
          )}
          {!isPdf && isImage && (
            <div className="flex items-center justify-center min-h-[70vh] p-4">
              <img src={signedUrl} alt="" draggable={false} className="max-w-full max-h-[75vh] object-contain" />
            </div>
          )}
        </div>
        {!isPdf && !isImage && (
          <div className="flex items-center justify-center min-h-[70vh] p-6 text-center text-sm text-muted-foreground">
            This file type cannot be previewed in the app. Contact your society office for access.
          </div>
        )}

        {/* Watermark overlay */}
        <div
          className="pointer-events-none absolute inset-0 overflow-hidden"
          aria-hidden
        >
          {Array.from({ length: 12 }).map((_, i) => (
            <div
              key={i}
              className="absolute whitespace-nowrap text-[11px] font-medium text-foreground/10 rotate-[-24deg] select-none"
              style={{
                left: `${(i % 4) * 28 - 8}%`,
                top: `${Math.floor(i / 4) * 32 + 8}%`,
              }}
            >
              {watermark}
            </div>
          ))}
        </div>

        {contentBlurred && (
          <div className="absolute inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center p-6 text-center">
            <div className="max-w-xs space-y-2">
              <p className="text-sm font-medium">Document preview hidden</p>
              <p className="text-xs text-muted-foreground">
                Your society office will enable viewing when needed. The image stays blurred until then.
              </p>
            </div>
          </div>
        )}

        {obscured && (
          <div className="absolute inset-0 bg-background/95 backdrop-blur-md flex items-center justify-center p-6 text-center">
            <p className="text-sm text-muted-foreground">Content hidden — return to this tab to continue viewing.</p>
          </div>
        )}
      </div>
    </div>
  );
}
