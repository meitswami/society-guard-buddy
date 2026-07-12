import type { ReportDefinition } from '../types';

export const guardShiftsReport: ReportDefinition = {
  id: 'guard_shifts',
  title: 'Guard Shifts',
  description: 'Guard login/logout shifts for duty reporting.',
  permission: 'report',
  baseTable: 'guard_shifts',
  societyColumn: 'society_id',
  defaultSort: { field: 'login_time', direction: 'desc' },
  defaultPageSize: 50,
  rowLimit: 2000,
  columns: [
    { key: 'guard_name', label: 'Guard', type: 'string', field: 'guard_name', searchable: true, sortable: true },
    { key: 'guard_id', label: 'Guard ID', type: 'string', field: 'guard_id', searchable: true, sortable: true },
    { key: 'login_time', label: 'Login', type: 'datetime', field: 'login_time', format: 'datetime', sortable: true },
    { key: 'logout_time', label: 'Logout', type: 'datetime', field: 'logout_time', format: 'datetime', sortable: true },
  ],
  filters: [
    { key: 'period', label: 'Login period', type: 'date_range', field: 'login_time' },
    { key: 'guard_name', label: 'Guard name', type: 'text', field: 'guard_name', operator: 'ilike' },
  ],
};
