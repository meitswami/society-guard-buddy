import * as React from 'react';

/** Superadmin entry is shown only on desktop/laptop (lg+), hidden on phones and tablets. */
const MIN_WIDTH_PX = 1024;

export function useShowSuperadminLogin() {
  const [show, setShow] = React.useState(() =>
    typeof window !== 'undefined' ? window.innerWidth >= MIN_WIDTH_PX : true,
  );

  React.useEffect(() => {
    const mql = window.matchMedia(`(min-width: ${MIN_WIDTH_PX}px)`);
    const sync = () => setShow(window.innerWidth >= MIN_WIDTH_PX);
    mql.addEventListener('change', sync);
    sync();
    return () => mql.removeEventListener('change', sync);
  }, []);

  return show;
}
