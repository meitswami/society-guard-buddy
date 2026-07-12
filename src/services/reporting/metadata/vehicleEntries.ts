import type { ReportDefinition } from '../types';

export const vehicleEntriesReport: ReportDefinition = {
  id: 'vehicle_entries',
  title: 'Vehicle Entries',
  description: 'Visitor vehicles that entered the society.',
  permission: 'report',
  baseTable: 'visitors',
  societyColumn: 'society_id',
  defaultSort: { field: 'entry_time', direction: 'desc' },
  defaultPageSize: 50,
  rowLimit: 2000,
  fixedFilters: [{ field: 'vehicle_number', op: 'not_null' }],
  columns: [
    { key: 'vehicle_number', label: 'Vehicle', type: 'string', field: 'vehicle_number', searchable: true, sortable: true },
    { key: 'name', label: 'Visitor', type: 'string', field: 'name', searchable: true, sortable: true },
    { key: 'flat_number', label: 'Flat', type: 'string', field: 'flat_number', searchable: true, sortable: true },
    { key: 'category', label: 'Category', type: 'string', field: 'category', searchable: true },
    { key: 'purpose', label: 'Purpose', type: 'string', field: 'purpose', searchable: true },
    { key: 'guard_name', label: 'Guard', type: 'string', field: 'guard_name', searchable: true },
    { key: 'entry_time', label: 'Entry', type: 'datetime', field: 'entry_time', format: 'datetime', sortable: true },
    {
      key: 'vehicle_entry_time',
      label: 'Vehicle in',
      type: 'datetime',
      field: 'vehicle_entry_time',
      format: 'datetime',
      defaultVisible: false,
    },
    {
      key: 'vehicle_exit_time',
      label: 'Vehicle out',
      type: 'datetime',
      field: 'vehicle_exit_time',
      format: 'datetime',
      defaultVisible: false,
    },
  ],
  filters: [
    { key: 'period', label: 'Entry period', type: 'date_range', field: 'entry_time' },
    { key: 'vehicle_number', label: 'Vehicle number', type: 'text', field: 'vehicle_number', operator: 'ilike' },
    { key: 'flat_number', label: 'Flat', type: 'text', field: 'flat_number', operator: 'ilike' },
  ],
};
