export const STANDARD_DUTY_PRESETS = [
  'Maintenance & Repairs',
  'Security & Gate',
  'Housekeeping',
  'Electrical',
  'Plumbing',
  'Garden & Landscaping',
  'Lift / Elevator',
  'Parking',
  'Accounts & Billing',
  'Event Coordination',
] as const;

export type CommitteeDutiesChartRow = {
  id: string;
  society_id: string;
  period_from: string;
  period_to: string | null;
  is_active: boolean;
};

export type CommitteeDutyRow = {
  id: string;
  chart_id: string;
  duty_label: string;
  supervisor_names: string[];
  sort_order: number;
};

export type DutyFormRow = {
  id: string | null;
  dutyLabel: string;
  supervisorNames: string;
  sortOrder: number;
};

export function parseSupervisorNames(input: string): string[] {
  return input
    .split(/[,;]+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

export function formatSupervisorNames(names: string[]): string {
  return names.filter(Boolean).join(', ');
}

export function dutiesPeriodLabel(chart: Pick<CommitteeDutiesChartRow, 'period_from' | 'period_to'>): string {
  const from = chart.period_from.slice(0, 10);
  const to = chart.period_to?.slice(0, 10);
  return to ? `${from} → ${to}` : `${from} → Ongoing`;
}
