import type { ReportDefinition } from '../types';
import { financeReceiptsReport } from './financeReceipts';
import { fixedAssetsReport } from './fixedAssets';
import { guardShiftsReport } from './guardShifts';
import { maintenancePaymentsReport } from './maintenancePayments';
import { vehicleEntriesReport } from './vehicleEntries';
import { visitorLogReport } from './visitorLog';

/** Built-in report catalog. Add new reports here — no controller required. */
export const BUILTIN_REPORT_DEFINITIONS: ReportDefinition[] = [
  financeReceiptsReport,
  maintenancePaymentsReport,
  visitorLogReport,
  vehicleEntriesReport,
  guardShiftsReport,
  fixedAssetsReport,
];

export function getBuiltinReportMap(): Map<string, ReportDefinition> {
  return new Map(BUILTIN_REPORT_DEFINITIONS.map((r) => [r.id, r]));
}
