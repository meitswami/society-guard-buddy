import type { ReportDefinition } from '../types';

export const visitorLogReport: ReportDefinition = {
  id: 'visitor_log',
  title: 'Visitor Log',
  description: 'Gate visitor entries with category, flat, and timing filters.',
  permission: 'report',
  baseTable: 'visitors',
  societyColumn: 'society_id',
  defaultSort: { field: 'entry_time', direction: 'desc' },
  defaultPageSize: 50,
  rowLimit: 2000,
  columns: [
    { key: 'name', label: 'Visitor', type: 'string', field: 'name', searchable: true, sortable: true },
    { key: 'phone', label: 'Phone', type: 'string', field: 'phone', searchable: true },
    { key: 'flat_number', label: 'Flat', type: 'string', field: 'flat_number', searchable: true, sortable: true },
    { key: 'category', label: 'Category', type: 'string', field: 'category', searchable: true, sortable: true },
    { key: 'purpose', label: 'Purpose', type: 'string', field: 'purpose', searchable: true },
    { key: 'company', label: 'Company', type: 'string', field: 'company', searchable: true, defaultVisible: false },
    { key: 'vehicle_number', label: 'Vehicle', type: 'string', field: 'vehicle_number', searchable: true },
    { key: 'guard_name', label: 'Guard', type: 'string', field: 'guard_name', searchable: true },
    { key: 'entry_time', label: 'Entry', type: 'datetime', field: 'entry_time', format: 'datetime', sortable: true },
    { key: 'exit_time', label: 'Exit', type: 'datetime', field: 'exit_time', format: 'datetime', defaultVisible: false },
  ],
  filters: [
    { key: 'period', label: 'Entry period', type: 'date_range', field: 'entry_time' },
    {
      key: 'category',
      label: 'Category',
      type: 'select',
      field: 'category',
      operator: 'eq',
      options: [
        { value: 'visitor', label: 'Visitor' },
        { value: 'delivery', label: 'Delivery' },
        { value: 'service', label: 'Service' },
        { value: 'cab', label: 'Cab' },
        { value: 'other', label: 'Other' },
      ],
    },
    { key: 'flat_number', label: 'Flat', type: 'text', field: 'flat_number', operator: 'ilike' },
  ],
};
