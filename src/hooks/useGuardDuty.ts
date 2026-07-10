import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useStore } from '@/store/useStore';
import {
  addIncident,
  fetchDutyHistory,
  getOrCreateDutyForShift,
  resolveGuardUuid,
  submitDuty,
  updateStaffAttendance,
  updateSystemCheck,
} from '@/services/guardDuty/guardDutyService';
import type {
  IncidentCategory,
  IncidentSeverity,
  StaffAttendanceStatus,
  SystemCheckStatus,
} from '@/lib/guardDutyTypes';

export const guardDutyQueryKeys = {
  current: (shiftId: string) => ['guard_duty', shiftId] as const,
  history: (societyId: string) => ['guard_duty_history', societyId] as const,
};

export function useGuardDuty() {
  const societyId = useStore((s) => s.societyId) ?? '';
  const shiftId = useStore((s) => s.shiftId) ?? '';
  const currentGuard = useStore((s) => s.currentGuard);

  return useQuery({
    queryKey: guardDutyQueryKeys.current(shiftId),
    queryFn: async () => {
      if (!societyId || !shiftId || !currentGuard) return null;
      const guardUuid = await resolveGuardUuid(currentGuard.id, societyId);
      if (!guardUuid) throw new Error('Guard record not found');
      return getOrCreateDutyForShift({
        societyId,
        shiftId,
        guardUuid,
        guardId: currentGuard.id,
        guardName: currentGuard.name,
      });
    },
    enabled: !!societyId && !!shiftId && !!currentGuard,
  });
}

export function useGuardDutyHistory() {
  const societyId = useStore((s) => s.societyId) ?? '';
  return useQuery({
    queryKey: guardDutyQueryKeys.history(societyId),
    queryFn: () => fetchDutyHistory(societyId),
    enabled: !!societyId,
  });
}

export function useGuardDutyMutations() {
  const shiftId = useStore((s) => s.shiftId) ?? '';
  const societyId = useStore((s) => s.societyId) ?? '';
  const qc = useQueryClient();

  const invalidate = () => {
    if (shiftId) qc.invalidateQueries({ queryKey: guardDutyQueryKeys.current(shiftId) });
    if (societyId) qc.invalidateQueries({ queryKey: guardDutyQueryKeys.history(societyId) });
  };

  const staff = useMutation({
    mutationFn: ({
      dutyId,
      staffRole,
      status,
      absenceReason,
    }: {
      dutyId: string;
      staffRole: string;
      status: StaffAttendanceStatus;
      absenceReason?: string | null;
    }) => updateStaffAttendance(dutyId, staffRole, status, absenceReason),
    onSuccess: invalidate,
  });

  const check = useMutation({
    mutationFn: ({
      dutyId,
      checkKey,
      status,
      problemPreset,
    }: {
      dutyId: string;
      checkKey: string;
      status: SystemCheckStatus;
      problemPreset?: string | null;
    }) => updateSystemCheck(dutyId, checkKey, status, problemPreset),
    onSuccess: invalidate,
  });

  const incident = useMutation({
    mutationFn: ({
      dutyId,
      category,
      severity,
      flatNumber,
      problemPreset,
      photoUrls,
    }: {
      dutyId: string;
      category: IncidentCategory;
      severity: IncidentSeverity;
      flatNumber?: string | null;
      problemPreset?: string | null;
      photoUrls?: string[];
    }) => addIncident(dutyId, { category, severity, flatNumber, problemPreset, photoUrls }),
    onSuccess: invalidate,
  });

  const submit = useMutation({
    mutationFn: (dutyId: string) => submitDuty(dutyId),
    onSuccess: invalidate,
  });

  return { staff, check, incident, submit };
}
