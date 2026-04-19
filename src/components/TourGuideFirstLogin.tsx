import { useCallback, useEffect, useState } from 'react';
import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import type { AppTourRole } from '@/lib/tourGuide';
import { getFirstLoginSteps, isTourCompleted, markTourCompleted } from '@/lib/tourGuide';
import TourGuideOverlay from '@/components/TourGuideOverlay';

type TFn = (key: string) => string;

type Props = {
  role: AppTourRole;
  userId: string;
  t: TFn;
  adminPermissions?: AdminPanelPermissions;
};

/** Full-screen first-time tour after login; completion stored per role + user id. */
const TourGuideFirstLogin = ({ role, userId, t, adminPermissions }: Props) => {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!userId || isTourCompleted(role, userId)) return;
    setOpen(true);
  }, [role, userId]);

  const steps = getFirstLoginSteps(role, adminPermissions);

  const handleClose = useCallback(() => setOpen(false), []);

  const handleFinished = useCallback(() => {
    markTourCompleted(role, userId);
    setOpen(false);
  }, [role, userId]);

  return (
    <TourGuideOverlay
      open={open}
      steps={steps}
      onClose={handleClose}
      onFinished={handleFinished}
      persistOnSkip
      t={t}
    />
  );
};

export default TourGuideFirstLogin;
