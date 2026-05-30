import { X } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';

export interface ReportDetailRow {
  id: string;
  label: string;
  sublabel?: string;
  amount?: number;
  date?: string;
  status?: string;
  extra?: string;
}

interface Props {
  open: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  totalAmount?: number;
  rows: ReportDetailRow[];
}

const ReportDetailModal = ({ open, onClose, title, subtitle, totalAmount, rows }: Props) => {
  const { t } = useLanguage();
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-lg max-h-[80vh] bg-background rounded-t-2xl sm:rounded-2xl shadow-xl flex flex-col overflow-hidden animate-in slide-in-from-bottom-4">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-border">
          <div>
            <h3 className="text-sm font-semibold">{title}</h3>
            {subtitle && <p className="text-[10px] text-muted-foreground">{subtitle}</p>}
          </div>
          <div className="flex items-center gap-3">
            {totalAmount !== undefined && (
              <span className="text-sm font-mono font-semibold text-primary">
                ₹{totalAmount.toLocaleString('en-IN')}
              </span>
            )}
            <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-muted transition-colors">
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-4">
          {rows.length === 0 ? (
            <p className="text-xs text-muted-foreground text-center py-8">No data available</p>
          ) : (
            <div className="flex flex-col gap-2">
              {rows.map((row) => (
                <div key={row.id} className="flex items-center justify-between gap-2 p-2.5 rounded-lg border border-border/60 bg-card/50">
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium truncate">{row.label}</p>
                    {row.sublabel && <p className="text-[10px] text-muted-foreground truncate">{row.sublabel}</p>}
                    {row.date && <p className="text-[10px] text-muted-foreground">{row.date}</p>}
                  </div>
                  <div className="text-right shrink-0">
                    {row.amount !== undefined && (
                      <p className="text-xs font-mono font-semibold">₹{row.amount.toLocaleString('en-IN')}</p>
                    )}
                    {row.status && (
                      <span className={`text-[10px] capitalize px-1.5 py-0.5 rounded-full ${
                        row.status === 'verified' || row.status === 'paid' || row.status === 'settled'
                          ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                          : row.status === 'pending'
                          ? 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400'
                          : 'bg-muted text-muted-foreground'
                      }`}>
                        {row.status}
                      </span>
                    )}
                    {row.extra && <p className="text-[10px] text-muted-foreground">{row.extra}</p>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-border text-center">
          <p className="text-[10px] text-muted-foreground">{rows.length} record{rows.length !== 1 ? 's' : ''}</p>
        </div>
      </div>
    </div>
  );
};

export default ReportDetailModal;
