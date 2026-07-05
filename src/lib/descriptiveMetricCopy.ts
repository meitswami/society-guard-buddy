/** Shared explanatory copy for count / amount cards (tap to read). */

export const ADMIN_HOME_METRICS = {
  meetingsHeld: {
    title: 'Meetings held',
    description:
      'Number of society meetings recorded in the Meetings module (published or saved with minutes). Used for governance tracking.',
    howCalculated: 'Count of meeting records for this society in the meetings table.',
  },
  maintenanceCollected: {
    title: 'Total collection (verified)',
    description:
      'Sum of all verified maintenance and society receipt payments — money recorded as collected from flat owners or outsiders.',
    howCalculated:
      'Adds amounts from maintenance_payments where payment_status = verified, for charges linked to this society.',
  },
  splitwiseExpenseTotal: {
    title: 'Event food expenses (active)',
    description:
      'Total of active food/catering bills linked to calendar events, split among flats. Not monthly maintenance or general society payments.',
    howCalculated:
      'Sums expenses.total_amount where record_status = active, expense_category = food, and group_kind = event.',
  },
  visitors: {
    title: 'Total visitors',
    description: 'All visitor log entries (guests and servicemen) recorded by guards or admins.',
    howCalculated: 'Count of rows in visitors for this society.',
  },
  visitorsGuest: {
    title: 'Guest visitors',
    description: 'Visitors categorised as guests (not recurring servicemen).',
    howCalculated: 'Visitors where category is guest-type (non-serviceman).',
  },
  visitorsService: {
    title: 'Serviceman visits',
    description: 'Recurring service staff entries (maids, delivery regulars, etc.).',
    howCalculated: 'Visitors where category indicates serviceman.',
  },
  vehicles: {
    title: 'Resident vehicles',
    description: 'Vehicles registered to flats in the society.',
    howCalculated: 'Count of resident_vehicles (or equivalent) for this society.',
  },
  vehiclesCars: {
    title: 'Cars',
    description: 'Registered four-wheeler vehicles.',
    howCalculated: 'Vehicles filtered by car / four-wheeler type.',
  },
  vehiclesTwoWheelers: {
    title: 'Two-wheelers',
    description: 'Registered bikes and scooters.',
    howCalculated: 'Vehicles filtered by two-wheeler type.',
  },
  flats: {
    title: 'Flats',
    description: 'Total flat units defined in the society layout.',
    howCalculated: 'Count of flats for this society_id.',
  },
  members: {
    title: 'Members registered',
    description: 'People linked to flats in Residents (owners, family, tenants).',
    howCalculated: 'Count of members whose flat belongs to this society.',
  },
  guards: {
    title: 'Guards',
    description: 'Security staff profiles active in the system.',
    howCalculated: 'Count of guard records for this society.',
  },
  blacklist: {
    title: 'Blacklist entries',
    description: 'Visitors or persons blocked from entry.',
    howCalculated: 'Count of blacklist records for this society.',
  },
} as const;

export const FINANCE_PERIOD_METRICS = {
  openingCash: {
    title: 'Opening cash in hand',
    description: 'Physical cash balance at the start of the selected period.',
    howCalculated:
      'Verified receipts in cash before period start minus cash expenses (separate-entry) before period start.',
  },
  openingBank: {
    title: 'Opening cash in bank',
    description: 'Bank / UPI / online balance at period start.',
    howCalculated: 'Same as opening cash, for non-cash channels (UPI, transfer, Razorpay, etc.).',
  },
  openingOther: {
    title: 'Opening other',
    description: 'Other payment channels at period start.',
    howCalculated: 'Receipts minus expenses classified as “other” channel before the period.',
  },
  openingBalance: {
    title: 'Opening balance (total)',
    description: 'Combined opening position across all channels.',
    howCalculated: 'Opening cash + opening bank + opening other.',
  },
  cashInHand: {
    title: 'Cash in hand (net)',
    description: 'Net cash movement during the period only.',
    howCalculated: 'Cash receipts in period minus cash expenses in period.',
  },
  cashInBank: {
    title: 'Cash in bank (net)',
    description: 'Net bank/UPI movement during the period.',
    howCalculated: 'Bank-channel receipts in period minus bank-channel expenses in period.',
  },
  otherNet: {
    title: 'Other channels (net)',
    description: 'Net movement on other methods in the period.',
    howCalculated: 'Other-channel receipts minus other-channel expenses in the period.',
  },
  totalBalance: {
    title: 'Period net',
    description: 'Overall surplus or deficit for the selected date range.',
    howCalculated: 'Total receipts in period minus total expenses in period (all channels).',
  },
  closingCash: {
    title: 'Closing cash in hand',
    description: 'Cash position at end of period.',
    howCalculated: 'Opening cash + period cash net.',
  },
  closingBank: {
    title: 'Closing cash in bank',
    description: 'Bank/UPI position at end of period.',
    howCalculated: 'Opening bank + period bank net.',
  },
  closingOther: {
    title: 'Closing other',
    description: 'Other channels at end of period.',
    howCalculated: 'Opening other + period other net.',
  },
  closingBalance: {
    title: 'Closing balance (total)',
    description: 'Total funds carry-forward after the period.',
    howCalculated: 'Opening balance + period net.',
  },
  extraLedgerReceipt: {
    title: 'Ledger-only inflows added',
    description:
      'Extra receipt amount from finance_entries in the period that are not backed by linked maintenance_payments — can inflate period totals.',
    howCalculated:
      'Sum of unlinked finance_entries (maintenance/corpus destinations) whose transaction month falls in the selected period range.',
  },
} as const;

export const FINANCE_LEDGER_GROUP_METRICS = {
  inflowGroup: {
    title: 'Ledger inflow group total',
    description: 'Sum posted under this recording mode and destination for the selected month.',
    howCalculated:
      'Adds total_amount from finance_entries in totalsMonth matching this record_mode + destination (maintenance/corpus inflows).',
  },
  outflowHead: {
    title: 'Expense head total',
    description: 'Money recorded as paid out under this expense title in the selected month.',
    howCalculated:
      'Sums finance_entries with destination separate_entry for this expense head and payment method in totalsMonth.',
  },
} as const;

export const REPORT_MAINTENANCE_METRICS = {
  maintenanceStatus: {
    title: 'Maintenance payments by status',
    description: 'Verified maintenance_payments grouped by payment_status for the report month.',
    howCalculated: 'Count and sum of maintenance_payments where billing month matches reportMonth.',
  },
  maintenanceLinked: {
    title: 'Linked to ledger',
    description: 'Maintenance payments that have a finance_entry_id — included in both Payments and Receipts tabs.',
    howCalculated: 'Verified payments in month where finance_entry_id is set.',
  },
  maintenanceUnlinked: {
    title: 'Not linked to ledger',
    description: 'Verified payments without a finance_entry — may cause recording vs reporting mismatch.',
    howCalculated: 'Verified payments in month where finance_entry_id is null.',
  },
} as const;

export const FINANCE_TOTALS_METRICS = {
  inflow: {
    title: 'Inflow (ledger)',
    description: 'Money recorded as coming into society books for the selected month.',
    howCalculated:
      'Sum of finance_entries with inflow destinations (maintenance/corpus), excluding separate-entry outflows.',
  },
  groups: {
    title: 'Ledger groups',
    description: 'Distinct combinations of recording mode and destination in this month.',
    howCalculated: 'Unique mode + destination keys from finance_entries for totalsMonth.',
  },
  flatUnits: {
    title: 'Flat allocation rows',
    description: 'Total flat-level allocation units posted in ledger entries.',
    howCalculated: 'Sum of aggregate_flat_count (and allocation rows) for inflow entries in the month.',
  },
  outflow: {
    title: 'Outflow (payments made)',
    description: 'Money recorded as paid out (separate-entry expenses) in the selected month.',
    howCalculated: 'Sum of finance_entries with destination separate_entry for totalsMonth.',
  },
  expenseHeads: {
    title: 'Expense heads',
    description: 'Distinct expense titles in outflow for the month.',
    howCalculated: 'Count of rows in totalsOutflowBreakdown.',
  },
  netInflowOutflow: {
    title: 'Net (Inflow − Outflow)',
    description: 'Ledger inflow minus outflow for the month.',
    howCalculated: 'totalsMonthNet − totalsMonthOutflow.',
  },
} as const;

export const FINANCE_FLAT_REPORT_METRICS = {
  totalReceipts: {
    title: 'Total receipts',
    description: 'Maintenance and verified payments attributed to flats in the report period.',
    howCalculated: 'Sum of maintenance_paid per flat in the flat report range.',
  },
  expenseShare: {
    title: 'Total expense share',
    description: 'Each flat’s share of event/function (and group) expenses in the period.',
    howCalculated: 'Sum of expense_share from expense_splits in range.',
  },
  settled: {
    title: 'Settled',
    description: 'Portion of expense shares already marked settled between flats.',
    howCalculated: 'Sum of settled_amount per flat.',
  },
  unsettled: {
    title: 'Unsettled',
    description: 'Outstanding share flats still owe each other or the pool.',
    howCalculated: 'Sum of unsettled_amount per flat.',
  },
} as const;

export const REPORT_PAGE_METRICS = {
  reportCashInHand: {
    title: 'Cash in hand',
    description: 'Net cash movement in the selected report month from verified receipts minus cash expenses.',
    howCalculated:
      'Same as Finance → Period report: verified maintenance_payments (due_date in month) minus cash-channel society ledger outflows.',
  },
  reportCashInBank: {
    title: 'Balance in bank',
    description: 'Net bank / UPI / online movement for the report month.',
    howCalculated:
      'Same as Finance → Period report: verified receipts on bank channels minus bank-channel society ledger outflows.',
  },
  reportOtherNet: {
    title: 'Other (net)',
    description: 'Net movement on other payment methods in the report month.',
    howCalculated:
      'Same as Finance → Period report: other-channel receipts minus other-channel society ledger outflows.',
  },
  reportTotalBalance: {
    title: 'Total balance (net)',
    description: 'Overall net funds movement for the month across all channels.',
    howCalculated: 'Period cash in hand + balance in bank + other net (Finance → Period report totals).',
  },
  financeGross: {
    title: 'Finance gross',
    description: 'Sum of all finance ledger entry amounts in the month (before drilling into mode/destination).',
    howCalculated: 'Sum of total_amount on finance_entries where entry_month matches reportMonth.',
  },
  guardShifts: {
    title: 'Guard shifts',
    description: 'Guard login and logout records for the report month.',
    howCalculated: 'Count of guard shift rows with login_time in reportMonth.',
  },
  moduleVisitors: {
    title: 'Visitors (month)',
    description: 'Guest visitor log entries in the report month.',
    howCalculated: 'Visitor records in month where category is guest-type.',
  },
  moduleVehicles: {
    title: 'Vehicle entries',
    description: 'Visitor log rows that include a vehicle number in the month.',
    howCalculated: 'Month visitors with vehicle_number set.',
  },
  moduleDeliveries: {
    title: 'Deliveries / service',
    description: 'Delivery or recurring service entries in the month.',
    howCalculated: 'Visitors with category delivery or service in reportMonth.',
  },
  moduleDonations: {
    title: 'Donations',
    description: 'Donation pledges and payments recorded for the month.',
    howCalculated: 'Count and sum from donation payment rows grouped by status.',
  },
  moduleExpenseSplits: {
    title: 'Event expense splits',
    description: 'Split lines from event/function expense groups in the month.',
    howCalculated: 'Count and sum of expense_splits linked to groups for reportMonth.',
  },
} as const;

export const MANUAL_AUDIT_METRICS = {
  computedTotal: {
    title: 'System total',
    description: 'Amount the app calculates from ledger / maintenance data for the month you traced.',
    howCalculated: 'Built from finance_entries or maintenance_payments per the selected source.',
  },
  expectedTotal: {
    title: 'Expected total',
    description: 'The amount you entered as the correct figure to compare against the system.',
    howCalculated: 'Your manual expected amount input for this trace.',
  },
  difference: {
    title: 'Difference',
    description: 'Gap between system total and your expected amount.',
    howCalculated: 'computedTotal − expectedTotal. Positive = system shows more than expected.',
  },
  match: {
    title: 'Figures match',
    description: 'The system total equals your expected amount for this month and source.',
    howCalculated: 'No discrepancy when the absolute gap between computed and expected totals is under ₹1.',
  },
} as const;

export const EVENT_EXPENSE_METRICS = {
  balances: {
    title: 'Flat balances',
    description:
      'Who owes whom after event/function expenses. Green = others owe this flat; red = this flat owes.',
    howCalculated:
      'From expense_splits and who advanced payment (paid_by_flats), excluding settled lines and society_fund rows.',
  },
  eligibleFlatsPool: {
    title: 'Eligible flats pool',
    description:
      'Flats included when you split an event bill equally or by headcount. Vacant units can be excluded so only occupied flats share cost.',
    howCalculated:
      'If “Include vacant” is ON: all flats in the society. If OFF: flats marked occupied or sold (activeFlats).',
  },
} as const;

export const AUDIT_LOG_METRICS = {
  total: {
    title: 'Total events',
    description: 'All security audit log entries stored for this society.',
    howCalculated: 'Count of audit_logs rows loaded in this view.',
  },
  failed: {
    title: 'Failed logins',
    description: 'Unsuccessful login attempts — possible wrong password or abuse.',
    howCalculated: 'Rows where event_type = login_failed.',
  },
  resets: {
    title: 'Password changes',
    description: 'Password reset or change events for admins, guards, or residents.',
    howCalculated: 'Rows where event_type is password_reset or password_change.',
  },
} as const;
