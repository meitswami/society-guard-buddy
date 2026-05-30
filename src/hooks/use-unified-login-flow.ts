import * as React from 'react';

/** Phones and tablets use the unified login page; desktop uses society gate + role chooser. */
const MAX_WIDTH_PX = 1023;

export function useUnifiedLoginFlow() {
  const [unified, setUnified] = React.useState(() =>
    typeof window !== 'undefined' ? window.innerWidth <= MAX_WIDTH_PX : true,
  );

  React.useEffect(() => {
    const mql = window.matchMedia(`(max-width: ${MAX_WIDTH_PX}px)`);
    const sync = () => setUnified(window.innerWidth <= MAX_WIDTH_PX);
    mql.addEventListener('change', sync);
    sync();
    return () => mql.removeEventListener('change', sync);
  }, []);

  return unified;
}
