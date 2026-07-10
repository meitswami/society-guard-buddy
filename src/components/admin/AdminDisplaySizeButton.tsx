import { useState, useCallback } from 'react';
import { Monitor, X } from 'lucide-react';

const AdminDisplaySizeButton = () => {
  const [open, setOpen] = useState(false);

  const readSizes = useCallback(() => {
    if (typeof window === 'undefined') {
      return { viewport: '—', screen: '—', dpr: '—', orientation: '—' };
    }
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const sw = window.screen.width;
    const sh = window.screen.height;
    const dpr = window.devicePixelRatio ?? 1;
    const orientation = vw >= vh ? 'Landscape' : 'Portrait';
    return {
      viewport: `${vw} × ${vh} px`,
      screen: `${sw} × ${sh} px`,
      dpr: String(dpr),
      orientation,
    };
  }, []);

  const [sizes, setSizes] = useState(readSizes);

  const handleOpen = () => {
    setSizes(readSizes());
    setOpen(true);
  };

  return (
    <>
      <button
        type="button"
        onClick={handleOpen}
        className="p-2 rounded-lg bg-secondary/80 text-muted-foreground hover:text-foreground hover:bg-secondary border border-border/60"
        title="Display size"
        aria-label="Display size"
      >
        <Monitor className="w-4 h-4" />
      </button>

      {open && (
        <div className="fixed inset-0 z-[80] bg-black/40 p-4 flex items-start justify-end">
          <div
            className="w-full max-w-xs bg-card border border-border rounded-xl shadow-xl p-4 space-y-3 mt-12 mr-0 sm:mr-2"
            role="dialog"
            aria-label="Display size information"
          >
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Monitor className="w-4 h-4 text-primary" />
                <p className="text-sm font-semibold">Display size</p>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="text-muted-foreground hover:text-foreground p-1"
                aria-label="Close"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <dl className="space-y-2 text-xs">
              <div className="flex justify-between gap-3">
                <dt className="text-muted-foreground">Viewport</dt>
                <dd className="font-mono font-medium tabular-nums">{sizes.viewport}</dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-muted-foreground">Screen</dt>
                <dd className="font-mono font-medium tabular-nums">{sizes.screen}</dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-muted-foreground">Pixel ratio</dt>
                <dd className="font-mono font-medium">{sizes.dpr}</dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-muted-foreground">Orientation</dt>
                <dd className="font-medium">{sizes.orientation}</dd>
              </div>
            </dl>
            <p className="text-[10px] text-muted-foreground">
              Shown on demand only — tap the monitor button anytime to refresh.
            </p>
          </div>
        </div>
      )}
    </>
  );
};

export default AdminDisplaySizeButton;
