export const financeQueryKeys = {
  all: ['finance'] as const,
  core: (societyId: string | null | undefined) => [...financeQueryKeys.all, 'core', societyId] as const,
  flatReport: (societyId: string | null | undefined) => [...financeQueryKeys.all, 'flat-report', societyId] as const,
  eventReference: (societyId: string | null | undefined) =>
    [...financeQueryKeys.all, 'event-reference', societyId] as const,
  periodReport: (societyId: string | null | undefined) =>
    [...financeQueryKeys.all, 'period-report', societyId] as const,
  periodReportBatch: (societyId: string | null | undefined) =>
    [...financeQueryKeys.all, 'period-report-batch', societyId] as const,
};
