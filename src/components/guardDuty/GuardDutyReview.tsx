import { useState } from 'react';
import { format } from 'date-fns';
import { ChevronDown, ChevronUp, ClipboardCheck, Loader2 } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import { useGuardDutyHistory } from '@/hooks/useGuardDuty';
import {
  INCIDENT_CATEGORIES,
  STAFF_ROLES,
  SYSTEM_CHECKS,
  type GuardDutyBundle,
} from '@/lib/guardDutyTypes';
import { cn } from '@/lib/utils';

function DutyCard({ bundle }: { bundle: GuardDutyBundle }) {
  const { t } = useLanguage();
  const [open, setOpen] = useState(false);
  const { duty, staff, checks, incidents } = bundle;

  const problems = checks.filter((c) => c.status === 'problem' || c.status === 'not_working');
  const absent = staff.filter((s) => s.status === 'absent' || s.status === 'late');

  return (
    <div className="card-section">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="w-full flex items-start gap-3 text-left"
      >
        <ClipboardCheck className="w-5 h-5 text-primary shrink-0 mt-0.5" />
        <div className="flex-1 min-w-0">
          <p className="font-semibold">
            {format(new Date(duty.duty_date), 'dd MMM yyyy')} · {duty.guard_name}
          </p>
          <p className="text-xs text-muted-foreground">
            {duty.status === 'submitted' ? t('duty.alreadySubmitted') : t('duty.inProgress')}
            {problems.length > 0 && ` · ${problems.length} ${t('duty.issues')}`}
            {incidents.length > 0 && ` · ${incidents.length} ${t('duty.reports')}`}
          </p>
        </div>
        {open ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
      </button>

      {open && (
        <div className="mt-4 space-y-4 text-sm border-t border-border pt-4">
          {absent.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-muted-foreground mb-2">{t('duty.staffTitle')}</p>
              {absent.map((s) => (
                <p key={s.id}>
                  {STAFF_ROLES.find((r) => r.key === s.staff_role)?.icon}{' '}
                  {t(`duty.staff.${s.staff_role}`)} — {t(`duty.attendance.${s.status}`)}
                  {s.absence_reason ? ` (${t(`duty.absence.${s.absence_reason}`)})` : ''}
                </p>
              ))}
            </div>
          )}

          {problems.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-muted-foreground mb-2">{t('duty.checksTitle')}</p>
              {problems.map((c) => (
                <p key={c.id}>
                  {SYSTEM_CHECKS.find((x) => x.key === c.check_key)?.icon}{' '}
                  {t(`duty.check.${c.check_key}`)} — {t(`duty.checkStatus.${c.status}`)}
                  {c.problem_preset ? ` · ${t(`duty.preset.${c.problem_preset}`)}` : ''}
                </p>
              ))}
            </div>
          )}

          {incidents.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-muted-foreground mb-2">{t('duty.incidentTitle')}</p>
              {incidents.map((inc) => (
                <p key={inc.id} className="mb-1">
                  {INCIDENT_CATEGORIES.find((c) => c.key === inc.category)?.icon}{' '}
                  {t(`duty.incident.${inc.category}`)}
                  {inc.flat_number ? ` · ${inc.flat_number}` : ''}
                  {' — '}
                  {t(`duty.severity.${inc.severity}`)}
                  {inc.problem_preset ? ` · ${t(`duty.preset.${inc.problem_preset}`)}` : ''}
                </p>
              ))}
            </div>
          )}

          {absent.length === 0 && problems.length === 0 && incidents.length === 0 && (
            <p className="text-muted-foreground">{t('duty.noIssues')}</p>
          )}
        </div>
      )}
    </div>
  );
}

const GuardDutyReview = () => {
  const { t } = useLanguage();
  const { data, isLoading, error } = useGuardDutyHistory();

  if (isLoading) {
    return (
      <div className="flex justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (error) {
    return <p className="text-destructive text-center py-8">{t('duty.loadError')}</p>;
  }

  if (!data?.length) {
    return (
      <div className="card-section text-center text-muted-foreground py-8">
        {t('duty.noReports')}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {data.map((bundle) => (
        <DutyCard key={bundle.duty.id} bundle={bundle} />
      ))}
    </div>
  );
};

export default GuardDutyReview;
