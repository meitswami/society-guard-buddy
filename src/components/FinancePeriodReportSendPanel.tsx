import { useState } from 'react';
import { Bell, Send, Undo2 } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import {
  buildFinancePeriodReportPdf,
  toFinancePeriodReportExportInput,
} from '@/lib/financePeriodReportExport';
import type { FinancePeriodReportResult } from '@/lib/financePeriodReport';
import { useFinanceMutations } from '@/hooks/finance/useFinanceMutations';
import { useFinancePeriodReportBatch } from '@/hooks/finance/useFinancePeriodReportBatch';

type Props = {
  societyId: string | null;
  societyName: string;
  adminName: string;
  periodFrom: string;
  periodTo: string;
  periodLabel: string;
  periodReport: FinancePeriodReportResult;
  flatNumbers: string[];
};

export default function FinancePeriodReportSendPanel({
  societyId,
  societyName,
  adminName,
  periodFrom,
  periodTo,
  periodLabel,
  periodReport,
  flatNumbers,
}: Props) {
  const financeMutations = useFinanceMutations(societyId);
  const { batchId, reload: reloadBatch } = useFinancePeriodReportBatch(societyId);
  const [sendPush, setSendPush] = useState(true);
  const [sending, setSending] = useState(false);

  const summaryMessage = `Receipts ₹${periodReport.totalReceipts.toLocaleString('en-IN')} · Expenses ₹${periodReport.totalExpenses.toLocaleString('en-IN')} · Net ₹${periodReport.totalBalance.toLocaleString('en-IN')} for ${periodLabel}.`;

  const sendToMembers = async () => {
    if (!societyId) return;
    const flats = [...new Set(flatNumbers.filter(Boolean))];
    if (flats.length === 0) {
      toast.error('No flats to notify');
      return;
    }
    const ok = await confirmAction(
      'Send period report to members?',
      `Delivers one in-app alert per flat (${flats.length})${sendPush ? ' and a push notification' : ''} for ${periodLabel}.`,
      'Send',
      'Cancel',
    );
    if (!ok) return;

    setSending(true);
    try {
      const ctx = await import('@/lib/letterheadReportEngine').then((m) =>
        m.resolveLetterheadReportContext(societyId),
      );
      const pdfBlob = buildFinancePeriodReportPdf(
        toFinancePeriodReportExportInput(periodReport, {
          societyName,
          periodFrom,
          periodTo,
          letterhead: ctx?.letterhead ?? null,
          pdfMode: ctx?.mode ?? 'letterhead',
        }),
      );
      await financeMutations.sendPeriodReportToMembers({
        adminName,
        periodLabel,
        summaryMessage,
        pdfBlob,
        flatNumbers: flats,
        sendPush,
      });
      toast.success(`Period report sent to ${flats.length} flat(s)`);
      await reloadBatch();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not send period report');
    } finally {
      setSending(false);
    }
  };

  const recallLast = async () => {
    if (!batchId) return;
    const ok = await confirmAction(
      'Recall last period report batch?',
      'Removes in-app notifications and the stored PDF for the most recent send.',
      'Recall',
      'Cancel',
    );
    if (!ok) return;
    try {
      await financeMutations.recallPeriodReport(batchId);
      toast.success('Last period report batch recalled');
      await reloadBatch();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Recall failed');
    }
  };

  if (!societyId) return null;

  return (
    <div className="mb-4 rounded-lg border border-border bg-card/40 p-3">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-[11px] font-medium text-foreground flex items-center gap-1.5">
            <Bell className="w-3.5 h-3.5" />
            Send to members
          </p>
          <p className="text-[10px] text-muted-foreground mt-0.5">
            {periodLabel} — PDF + in-app alert per flat{batchId ? ' · latest batch on file' : ''}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <label className="flex items-center gap-1.5 text-[10px] text-muted-foreground cursor-pointer">
            <input
              type="checkbox"
              className="rounded"
              checked={sendPush}
              onChange={(e) => setSendPush(e.target.checked)}
            />
            Push notification
          </label>
          <button
            type="button"
            className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1"
            disabled={sending || flatNumbers.length === 0}
            onClick={() => void sendToMembers()}
          >
            <Send className="w-3.5 h-3.5" />
            {sending ? 'Sending…' : 'Send'}
          </button>
          {batchId && (
            <button
              type="button"
              className="btn-secondary text-xs py-1.5 px-3 flex items-center gap-1"
              onClick={() => void recallLast()}
            >
              <Undo2 className="w-3.5 h-3.5" />
              Recall
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
