import { AlertTriangle } from 'lucide-react';
import { UnpaidFlatGridTable } from '@/components/finance/UnpaidFlatGridTable';
import type { UnpaidFlatGridRow } from '@/lib/financeManagerTypes';

interface Props {
  unpaidCount: number;
  rows: UnpaidFlatGridRow[];
  onSendReminders: () => void;
  autoReminderEnabled: boolean;
  autoReminderSchedule: 'once_12pm' | 'twice_12pm_7pm';
  reminderDueDay: number;
  onAutoReminderEnabledChange: (enabled: boolean) => void;
  onAutoReminderScheduleChange: (schedule: 'once_12pm' | 'twice_12pm_7pm') => void;
  onReminderDueDayChange: (dueDay: number) => void;
  onSaveAutoReminderSettings: () => void;
  onTestAutoReminderNow: () => void;
  savingAutoReminder: boolean;
  testingAutoReminder: boolean;
  lastReminderTestStatus: string;
  includeVacantFlats: boolean;
  onIncludeVacantFlatsChange: (include: boolean) => void;
  vacantScopeLabel: string;
}

export function FinanceRemindersTab({
  unpaidCount,
  rows,
  onSendReminders,
  autoReminderEnabled,
  autoReminderSchedule,
  reminderDueDay,
  onAutoReminderEnabledChange,
  onAutoReminderScheduleChange,
  onReminderDueDayChange,
  onSaveAutoReminderSettings,
  onTestAutoReminderNow,
  savingAutoReminder,
  testingAutoReminder,
  lastReminderTestStatus,
  includeVacantFlats,
  onIncludeVacantFlatsChange,
  vacantScopeLabel,
}: Props) {
  return (
    <div className="mb-4 space-y-4">
      <div className="card-section p-4 space-y-3 border-amber-500/20 bg-amber-500/5">
        <div className="flex items-center gap-2">
          <AlertTriangle className="w-5 h-5 text-amber-500" />
          <h3 className="font-semibold text-sm">Due reminders</h3>
        </div>

        <label className="text-xs flex flex-col gap-1 max-w-xs">
          <span className="text-muted-foreground">Flat scope for reminders</span>
          <select
            className="input-field"
            value={includeVacantFlats ? 'include_vacant' : 'occupied_only'}
            onChange={(e) => onIncludeVacantFlatsChange(e.target.value === 'include_vacant')}
          >
            <option value="occupied_only">Occupied / sold flats only</option>
            <option value="include_vacant">Include vacant flats</option>
          </select>
          <span className="text-[10px] text-muted-foreground">{vacantScopeLabel}</span>
        </label>

        <div className="space-y-2 pt-1 border-t border-border/60">
          <p className="text-xs font-medium text-foreground">Automatic due reminders</p>
          <label className="text-xs flex flex-col gap-1 max-w-xs">
            <span className="text-muted-foreground">Monthly due day (1–28)</span>
            <input
              className="input-field"
              type="number"
              min={1}
              max={28}
              value={reminderDueDay}
              onChange={(e) => onReminderDueDayChange(Number(e.target.value))}
            />
            <span className="text-[10px] text-muted-foreground">
              Daily reminders start after this day each month for unpaid maintenance.
            </span>
          </label>
          <label className="flex items-center gap-2 text-xs">
            <input
              type="checkbox"
              checked={autoReminderEnabled}
              onChange={(e) => onAutoReminderEnabledChange(e.target.checked)}
            />
            Enable daily due reminders after monthly due date
          </label>
          <select
            className="input-field"
            value={autoReminderSchedule}
            onChange={(e) => onAutoReminderScheduleChange(e.target.value as 'once_12pm' | 'twice_12pm_7pm')}
            disabled={!autoReminderEnabled}
          >
            <option value="once_12pm">Once daily at 12:00 PM</option>
            <option value="twice_12pm_7pm">Twice daily at 12:00 PM and 7:00 PM</option>
          </select>
          <div className="flex flex-col sm:flex-row gap-2">
            <button
              type="button"
              className="btn-secondary flex-1"
              onClick={onSaveAutoReminderSettings}
              disabled={savingAutoReminder}
            >
              {savingAutoReminder ? 'Saving…' : 'Save reminder settings'}
            </button>
            <button
              type="button"
              className="btn-secondary flex-1"
              onClick={onTestAutoReminderNow}
              disabled={testingAutoReminder}
            >
              {testingAutoReminder ? 'Testing…' : 'Test reminder now'}
            </button>
          </div>
          {lastReminderTestStatus ? (
            <p className="text-[10px] text-muted-foreground">{lastReminderTestStatus}</p>
          ) : null}
        </div>
      </div>

      <div className="card-section p-4">
        <p className="text-sm text-muted-foreground mb-3">{unpaidCount} flats have not paid maintenance</p>
        {unpaidCount > 0 && (
          <button onClick={onSendReminders} className="btn-primary w-full flex items-center justify-center gap-2 mb-4">
            Send reminders to all ({unpaidCount})
          </button>
        )}
        <UnpaidFlatGridTable rows={rows} emptyMessage="All flats have paid maintenance" />
      </div>
    </div>
  );
}
