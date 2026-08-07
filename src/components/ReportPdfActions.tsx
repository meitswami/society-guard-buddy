import { useEffect, useState } from 'react';
import { Download, Eye, FileText, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  downloadSocietyReportPdf,
  LETTERHEAD_NOT_CONFIGURED_WARNING,
  previewSocietyReportPdf,
  resolveLetterheadReportContext,
} from '@/lib/letterheadReportEngine';
import type { ReportPdfMode, SocietyLetterhead } from '@/lib/pdfLetterhead';

type Props = {
  societyId: string | null | undefined;
  filename: string;
  /** Build PDF for the chosen mode using the resolved society letterhead. */
  buildPdf: (opts: {
    mode: ReportPdfMode;
    letterhead: SocietyLetterhead | null;
  }) => Blob | Promise<Blob>;
  label?: string;
  className?: string;
  disabled?: boolean;
};

/**
 * Generate Report → Plain PDF | Official Society Letterhead PDF, plus Preview.
 * Official letterhead is the default when configured for the current society.
 */
export default function ReportPdfActions({
  societyId,
  filename,
  buildPdf,
  label = 'Generate Report',
  className = 'btn-secondary text-xs px-2.5 py-2 flex items-center gap-1',
  disabled,
}: Props) {
  const [busy, setBusy] = useState(false);
  const [defaultMode, setDefaultMode] = useState<ReportPdfMode>('letterhead');
  const [hasLetterhead, setHasLetterhead] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const ctx = await resolveLetterheadReportContext(societyId);
      if (cancelled || !ctx) return;
      setDefaultMode(ctx.settings.defaultReportFormat);
      setHasLetterhead(!!(ctx.letterhead?.letterheadDataUrl || ctx.letterhead?.letterheadUrl || ctx.letterhead?.letterheadStoragePath));
    })();
    return () => {
      cancelled = true;
    };
  }, [societyId]);

  const run = async (action: 'preview' | 'download', preferred?: ReportPdfMode) => {
    if (!societyId) {
      toast.error('Select a society first');
      return;
    }
    setBusy(true);
    try {
      const ctx = await resolveLetterheadReportContext(societyId, preferred ?? defaultMode);
      if (!ctx) {
        toast.error('Society not found');
        return;
      }
      if (ctx.warning) toast.warning(ctx.warning);
      const blob = await buildPdf({ mode: ctx.mode, letterhead: ctx.letterhead });
      if (action === 'preview') {
        await previewSocietyReportPdf(blob, filename);
        toast.success('Preview opened');
      } else {
        await downloadSocietyReportPdf(blob, filename);
        toast.success('PDF ready');
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'PDF failed');
    } finally {
      setBusy(false);
    }
  };

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild disabled={disabled || busy}>
        <button type="button" className={className} disabled={disabled || busy}>
          {busy ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <FileText className="w-3.5 h-3.5" />}
          {label}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-[220px]">
        <DropdownMenuItem
          className="text-xs gap-2 cursor-pointer"
          onClick={() => void run('preview', defaultMode)}
        >
          <Eye className="w-3.5 h-3.5" />
          Preview Report
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          className="text-xs gap-2 cursor-pointer"
          onClick={() => void run('download', 'letterhead')}
        >
          <Download className="w-3.5 h-3.5" />
          Official Society Letterhead PDF
          {defaultMode === 'letterhead' ? ' (default)' : ''}
        </DropdownMenuItem>
        <DropdownMenuItem
          className="text-xs gap-2 cursor-pointer"
          onClick={() => void run('download', 'plain')}
        >
          <Download className="w-3.5 h-3.5" />
          Plain PDF
          {defaultMode === 'plain' ? ' (default)' : ''}
        </DropdownMenuItem>
        {!hasLetterhead && (
          <p className="px-2 py-1.5 text-[10px] text-amber-700 dark:text-amber-300 max-w-[210px] leading-snug">
            {LETTERHEAD_NOT_CONFIGURED_WARNING}
          </p>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
