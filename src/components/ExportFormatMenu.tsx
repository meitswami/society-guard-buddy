import { Download, FileSpreadsheet, FileText, FileType } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import type { ExportFormat } from '@/lib/reportExportUtils';

type Props = {
  onExport: (format: ExportFormat) => void;
  disabled?: boolean;
  formats?: ExportFormat[];
  label?: string;
  className?: string;
};

const FORMAT_META: Record<ExportFormat, { label: string; icon: React.ElementType }> = {
  pdf: { label: 'PDF', icon: FileText },
  excel: { label: 'Excel (.xlsx)', icon: FileSpreadsheet },
  word: { label: 'Word (.doc)', icon: FileType },
  csv: { label: 'CSV', icon: Download },
};

export default function ExportFormatMenu({
  onExport,
  disabled,
  formats = ['pdf', 'excel', 'word', 'csv'],
  label = 'Export',
  className = 'btn-secondary text-xs px-2.5 py-2 flex items-center gap-1',
}: Props) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild disabled={disabled}>
        <button type="button" className={className} disabled={disabled}>
          <Download className="w-3.5 h-3.5" />
          {label}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-[160px]">
        {formats.map((format) => {
          const meta = FORMAT_META[format];
          const Icon = meta.icon;
          return (
            <DropdownMenuItem key={format} onClick={() => onExport(format)} className="text-xs gap-2 cursor-pointer">
              <Icon className="w-3.5 h-3.5" />
              {meta.label}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
