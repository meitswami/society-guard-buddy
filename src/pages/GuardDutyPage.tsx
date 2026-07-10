import { useState } from 'react';
import {
  ArrowUpFromLine,
  CheckCircle2,
  ClipboardCheck,
  Loader2,
  Users,
  Wrench,
  AlertTriangle,
} from 'lucide-react';
import { format } from 'date-fns';
import { toast } from 'sonner';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { useGuardDuty, useGuardDutyMutations } from '@/hooks/useGuardDuty';
import { BigTapButton } from '@/components/guardDuty/BigTapButton';
import PhotoCapture from '@/components/PhotoCapture';
import { confirmAction } from '@/lib/swal';
import {
  ABSENCE_REASONS,
  INCIDENT_CATEGORIES,
  INCIDENT_PRESETS,
  PROBLEM_PRESETS,
  STAFF_ROLES,
  SYSTEM_CHECKS,
  type IncidentCategory,
  type IncidentSeverity,
  type StaffAttendanceStatus,
  type SystemCheckKey,
  type SystemCheckStatus,
} from '@/lib/guardDutyTypes';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { cn } from '@/lib/utils';

const ATTENDANCE_OPTIONS: { status: StaffAttendanceStatus; icon: string; variant: 'success' | 'danger' | 'warning' | 'muted' }[] = [
  { status: 'present', icon: '✅', variant: 'success' },
  { status: 'absent', icon: '❌', variant: 'danger' },
  { status: 'late', icon: '⏰', variant: 'warning' },
  { status: 'not_required', icon: '➖', variant: 'muted' },
];

const CHECK_STATUS_OPTIONS: { status: SystemCheckStatus; icon: string; variant: 'success' | 'warning' | 'danger' }[] = [
  { status: 'ok', icon: '✅', variant: 'success' },
  { status: 'problem', icon: '⚠️', variant: 'warning' },
  { status: 'not_working', icon: '🚫', variant: 'danger' },
];

const SEVERITY_OPTIONS: { severity: IncidentSeverity; icon: string; variant: 'success' | 'warning' | 'danger' }[] = [
  { severity: 'low', icon: '🟢', variant: 'success' },
  { severity: 'medium', icon: '🟡', variant: 'warning' },
  { severity: 'high', icon: '🔴', variant: 'danger' },
];

function statusColor(status: StaffAttendanceStatus | SystemCheckStatus): string {
  if (status === 'present' || status === 'ok') return 'border-success/50 bg-success/10';
  if (status === 'absent' || status === 'not_working') return 'border-destructive/50 bg-destructive/10';
  if (status === 'late' || status === 'problem') return 'border-warning/50 bg-warning/10';
  if (status === 'not_required' || status === 'not_checked' || status === 'not_marked') return '';
  return '';
}

const GuardDutyPage = () => {
  const { t } = useLanguage();
  const { currentGuard, flats } = useStore();
  const { data: bundle, isLoading, error } = useGuardDuty();
  const { staff, check, incident, submit } = useGuardDutyMutations();

  const [activeCheck, setActiveCheck] = useState<SystemCheckKey | null>(null);
  const [checkStatus, setCheckStatus] = useState<SystemCheckStatus>('not_checked');
  const [checkPreset, setCheckPreset] = useState<string | null>(null);

  const [incidentOpen, setIncidentOpen] = useState(false);
  const [incidentCategory, setIncidentCategory] = useState<IncidentCategory | null>(null);
  const [incidentSeverity, setIncidentSeverity] = useState<IncidentSeverity>('medium');
  const [incidentPreset, setIncidentPreset] = useState<string | null>(null);
  const [incidentFlat, setIncidentFlat] = useState<string | null>(null);
  const [incidentPhotos, setIncidentPhotos] = useState<string[]>([]);

  const [absenceRole, setAbsenceRole] = useState<string | null>(null);
  const [absenceStatus, setAbsenceStatus] = useState<StaffAttendanceStatus>('absent');

  const saving = staff.isPending || check.isPending || incident.isPending || submit.isPending;

  const handleStaffTap = async (staffRole: string, status: StaffAttendanceStatus) => {
    if (!bundle) return;
    if (status === 'absent' || status === 'late') {
      setAbsenceRole(staffRole);
      setAbsenceStatus(status);
      return;
    }
    try {
      await staff.mutateAsync({ dutyId: bundle.duty.id, staffRole, status });
      toast.success(t('duty.saved'));
    } catch {
      toast.error(t('duty.saveFailed'));
    }
  };

  const confirmAbsence = async (reason: string) => {
    if (!bundle || !absenceRole) return;
    try {
      await staff.mutateAsync({
        dutyId: bundle.duty.id,
        staffRole: absenceRole,
        status: absenceStatus,
        absenceReason: reason,
      });
      toast.success(t('duty.saved'));
      setAbsenceRole(null);
    } catch {
      toast.error(t('duty.saveFailed'));
    }
  };

  const openCheckDialog = (key: SystemCheckKey) => {
    if (!bundle) return;
    const existing = bundle.checks.find((c) => c.check_key === key);
    setActiveCheck(key);
    setCheckStatus(existing?.status ?? 'not_checked');
    setCheckPreset(existing?.problem_preset ?? null);
  };

  const saveCheck = async () => {
    if (!bundle || !activeCheck) return;
    try {
      await check.mutateAsync({
        dutyId: bundle.duty.id,
        checkKey: activeCheck,
        status: checkStatus,
        problemPreset: checkPreset,
      });
      toast.success(t('duty.saved'));
      setActiveCheck(null);
    } catch {
      toast.error(t('duty.saveFailed'));
    }
  };

  const openIncident = (category: IncidentCategory) => {
    setIncidentCategory(category);
    setIncidentSeverity('medium');
    setIncidentPreset(null);
    setIncidentFlat(null);
    setIncidentPhotos([]);
    setIncidentOpen(true);
  };

  const saveIncident = async () => {
    if (!bundle || !incidentCategory) return;
    try {
      await incident.mutateAsync({
        dutyId: bundle.duty.id,
        category: incidentCategory,
        severity: incidentSeverity,
        flatNumber: incidentFlat,
        problemPreset: incidentPreset,
        photoUrls: incidentPhotos.length ? incidentPhotos : undefined,
      });
      toast.success(t('duty.incidentSaved'));
      setIncidentOpen(false);
      setIncidentCategory(null);
    } catch {
      toast.error(t('duty.saveFailed'));
    }
  };

  const handleSubmitDuty = async () => {
    if (!bundle) return;
    const ok = await confirmAction(
      t('duty.submitTitle'),
      t('duty.submitDesc'),
      t('duty.submitConfirm'),
      t('common.cancel'),
    );
    if (!ok) return;
    try {
      await submit.mutateAsync(bundle.duty.id);
      toast.success(t('duty.submitted'));
    } catch {
      toast.error(t('duty.saveFailed'));
    }
  };

  if (isLoading) {
    return (
      <div className="page-container flex items-center justify-center min-h-[60vh]">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (error || !bundle || !currentGuard) {
    return (
      <div className="page-container">
        <p className="text-destructive text-center mt-10">{t('duty.loadError')}</p>
      </div>
    );
  }

  const { duty, staff: staffRows, checks, incidents: incidentRows } = bundle;
  const isSubmitted = duty.status === 'submitted';

  return (
    <div className="page-container space-y-5">
      <header className="space-y-1">
        <div className="flex items-center gap-2">
          <ClipboardCheck className="w-6 h-6 text-primary" />
          <h1 className="page-title">{t('duty.title')}</h1>
        </div>
        <p className="text-sm text-muted-foreground">
          {format(new Date(duty.duty_date), 'dd MMM yyyy')} · {currentGuard.name}
        </p>
        {isSubmitted && (
          <p className="text-xs text-[hsl(var(--success))] flex items-center gap-1">
            <CheckCircle2 className="w-4 h-4" />
            {t('duty.alreadySubmitted')}
          </p>
        )}
      </header>

      {/* Staff attendance */}
      <section className="card-section space-y-3">
        <div className="flex items-center gap-2">
          <Users className="w-5 h-5 text-primary" />
          <h2 className="font-semibold">{t('duty.staffTitle')}</h2>
        </div>
        <p className="text-xs text-muted-foreground">{t('duty.staffHint')}</p>
        <div className="space-y-3">
          {STAFF_ROLES.map((role) => {
            const row = staffRows.find((s) => s.staff_role === role.key);
            const status = row?.status ?? 'not_marked';
            return (
              <div
                key={role.key}
                className={cn('rounded-xl border p-3 space-y-2', statusColor(status))}
              >
                <div className="flex items-center gap-2">
                  <span className="text-xl">{role.icon}</span>
                  <span className="font-medium">{t(`duty.staff.${role.key}`)}</span>
                  {status !== 'not_marked' && (
                    <span className="ml-auto text-xs font-semibold uppercase">
                      {t(`duty.attendance.${status}`)}
                    </span>
                  )}
                </div>
                <div className="grid grid-cols-4 gap-2">
                  {ATTENDANCE_OPTIONS.map((opt) => (
                    <BigTapButton
                      key={opt.status}
                      icon={opt.icon}
                      label={t(`duty.attendance.${opt.status}`)}
                      selected={status === opt.status}
                      variant={opt.variant}
                      disabled={isSubmitted || saving}
                      onClick={() => handleStaffTap(role.key, opt.status)}
                    />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* System checks */}
      <section className="card-section space-y-3">
        <div className="flex items-center gap-2">
          <Wrench className="w-5 h-5 text-primary" />
          <h2 className="font-semibold">{t('duty.checksTitle')}</h2>
        </div>
        <p className="text-xs text-muted-foreground">{t('duty.checksHint')}</p>
        <div className="grid grid-cols-3 gap-2">
          {SYSTEM_CHECKS.map((item) => {
            const row = checks.find((c) => c.check_key === item.key);
            const status = row?.status ?? 'not_checked';
            return (
              <button
                key={item.key}
                type="button"
                disabled={isSubmitted || saving}
                onClick={() => openCheckDialog(item.key)}
                className={cn(
                  'flex flex-col items-center gap-1 rounded-xl border-2 p-3 min-h-[5rem] active:scale-[0.97] transition-all',
                  statusColor(status) || 'border-border bg-card',
                )}
              >
                <span className="text-2xl">{item.icon}</span>
                <span className="text-xs font-semibold text-center leading-tight">
                  {t(`duty.check.${item.key}`)}
                </span>
                {status !== 'not_checked' && (
                  <span className="text-[10px] font-bold uppercase text-muted-foreground">
                    {t(`duty.checkStatus.${status}`)}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </section>

      {/* Report incident */}
      <section className="card-section space-y-3">
        <div className="flex items-center gap-2">
          <AlertTriangle className="w-5 h-5 text-destructive" />
          <h2 className="font-semibold">{t('duty.incidentTitle')}</h2>
        </div>
        <p className="text-xs text-muted-foreground">{t('duty.incidentHint')}</p>
        <div className="grid grid-cols-3 gap-2">
          {INCIDENT_CATEGORIES.map((cat) => (
            <button
              key={cat.key}
              type="button"
              disabled={isSubmitted || saving}
              onClick={() => openIncident(cat.key)}
              className="flex flex-col items-center gap-1 rounded-xl border-2 border-border bg-card p-3 min-h-[5rem] active:scale-[0.97] transition-all"
            >
              <span className="text-2xl">{cat.icon}</span>
              <span className="text-[11px] font-semibold text-center leading-tight">
                {t(`duty.incident.${cat.key}`)}
              </span>
            </button>
          ))}
        </div>

        {incidentRows.length > 0 && (
          <div className="space-y-2 pt-2 border-t border-border">
            <p className="text-xs font-semibold text-muted-foreground">{t('duty.todayIncidents')}</p>
            {incidentRows.map((inc) => (
              <div key={inc.id} className="rounded-lg bg-muted/40 px-3 py-2 text-sm flex items-center gap-2">
                <span>
                  {INCIDENT_CATEGORIES.find((c) => c.key === inc.category)?.icon}
                </span>
                <span className="flex-1">
                  {t(`duty.incident.${inc.category}`)}
                  {inc.flat_number ? ` · ${inc.flat_number}` : ''}
                  {inc.problem_preset ? ` · ${t(`duty.preset.${inc.problem_preset}`)}` : ''}
                </span>
                <span className="text-[10px] uppercase font-bold text-muted-foreground">
                  {t(`duty.severity.${inc.severity}`)}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      {!isSubmitted && (
        <button
          type="button"
          disabled={saving}
          onClick={handleSubmitDuty}
          className="btn-primary w-full flex items-center justify-center gap-2"
        >
          <ArrowUpFromLine className="w-5 h-5" />
          {t('duty.submitShift')}
        </button>
      )}

      {/* Absence reason dialog */}
      <Dialog open={!!absenceRole} onOpenChange={(o) => !o && setAbsenceRole(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>{t('duty.absenceReason')}</DialogTitle>
          </DialogHeader>
          <div className="grid grid-cols-2 gap-2">
            {ABSENCE_REASONS.map((reason) => (
              <BigTapButton
                key={reason}
                label={t(`duty.absence.${reason}`)}
                selected={false}
                variant="muted"
                onClick={() => confirmAbsence(reason)}
              />
            ))}
          </div>
        </DialogContent>
      </Dialog>

      {/* System check dialog */}
      <Dialog open={!!activeCheck} onOpenChange={(o) => !o && setActiveCheck(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>
              {activeCheck && t(`duty.check.${activeCheck}`)}
            </DialogTitle>
          </DialogHeader>
          <div className="grid grid-cols-3 gap-2">
            {CHECK_STATUS_OPTIONS.map((opt) => (
              <BigTapButton
                key={opt.status}
                icon={opt.icon}
                label={t(`duty.checkStatus.${opt.status}`)}
                selected={checkStatus === opt.status}
                variant={opt.variant}
                onClick={() => setCheckStatus(opt.status)}
              />
            ))}
          </div>
          {(checkStatus === 'problem' || checkStatus === 'not_working') && activeCheck && (
            <div className="space-y-2">
              <p className="text-xs text-muted-foreground">{t('duty.pickProblem')}</p>
              <div className="flex flex-wrap gap-2">
                {PROBLEM_PRESETS[activeCheck].map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => setCheckPreset(preset)}
                    className={cn(
                      'px-3 py-2 rounded-lg text-sm font-medium border active:scale-[0.98]',
                      checkPreset === preset
                        ? 'border-primary bg-primary/15 text-primary'
                        : 'border-border bg-card',
                    )}
                  >
                    {t(`duty.preset.${preset}`)}
                  </button>
                ))}
              </div>
            </div>
          )}
          <button type="button" onClick={saveCheck} className="btn-primary w-full">
            {t('duty.saveCheck')}
          </button>
        </DialogContent>
      </Dialog>

      {/* Incident dialog */}
      <Dialog open={incidentOpen} onOpenChange={setIncidentOpen}>
        <DialogContent className="max-w-sm max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {incidentCategory && t(`duty.incident.${incidentCategory}`)}
            </DialogTitle>
          </DialogHeader>

          <p className="text-xs text-muted-foreground">{t('duty.pickSeverity')}</p>
          <div className="grid grid-cols-3 gap-2">
            {SEVERITY_OPTIONS.map((opt) => (
              <BigTapButton
                key={opt.severity}
                icon={opt.icon}
                label={t(`duty.severity.${opt.severity}`)}
                selected={incidentSeverity === opt.severity}
                variant={opt.variant}
                onClick={() => setIncidentSeverity(opt.severity)}
              />
            ))}
          </div>

          {incidentCategory && (
            <>
              <p className="text-xs text-muted-foreground">{t('duty.pickProblem')}</p>
              <div className="flex flex-wrap gap-2">
                {INCIDENT_PRESETS[incidentCategory].map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => setIncidentPreset(preset)}
                    className={cn(
                      'px-3 py-2 rounded-lg text-sm font-medium border active:scale-[0.98]',
                      incidentPreset === preset
                        ? 'border-primary bg-primary/15 text-primary'
                        : 'border-border bg-card',
                    )}
                  >
                    {t(`duty.preset.${preset}`)}
                  </button>
                ))}
              </div>
            </>
          )}

          {flats.length > 0 && (
            <>
              <p className="text-xs text-muted-foreground">{t('duty.pickFlat')}</p>
              <div className="flex flex-wrap gap-2 max-h-32 overflow-y-auto">
                <button
                  type="button"
                  onClick={() => setIncidentFlat(null)}
                  className={cn(
                    'px-3 py-2 rounded-lg text-sm border',
                    !incidentFlat ? 'border-primary bg-primary/15' : 'border-border',
                  )}
                >
                  {t('duty.noFlat')}
                </button>
                {flats.slice(0, 40).map((f) => (
                  <button
                    key={f.id}
                    type="button"
                    onClick={() => setIncidentFlat(f.flatNumber)}
                    className={cn(
                      'px-3 py-2 rounded-lg text-sm border',
                      incidentFlat === f.flatNumber ? 'border-primary bg-primary/15' : 'border-border',
                    )}
                  >
                    {f.flatNumber}
                  </button>
                ))}
              </div>
            </>
          )}

          <PhotoCapture
            photos={incidentPhotos}
            onChange={setIncidentPhotos}
            maxPhotos={2}
            label={t('duty.photoOptional')}
          />

          <button type="button" onClick={saveIncident} className="btn-primary w-full">
            {t('duty.saveIncident')}
          </button>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default GuardDutyPage;
