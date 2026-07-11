import { useState } from 'react';
import { X, Download, Share2 } from 'lucide-react';
import { toast } from 'sonner';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { triggerDownload } from '@/lib/reportExportUtils';
import { sharePdfOnWhatsApp } from '@/lib/sharePdfWhatsApp';

type WhatsAppFormat = 'detailed' | 'summary';

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  pdfBlob: Blob;
  filename: string;
  getDetailedBlob: () => Promise<Blob>;
  getSummaryBlob: () => Promise<Blob>;
}

export default function DatewisePdfPreviewModal({
  open,
  onOpenChange,
  pdfBlob,
  filename,
  getDetailedBlob,
  getSummaryBlob,
}: Props) {
  const [pdfUrl, setPdfUrl] = useState<string>('');
  const [sharing, setSharing] = useState(false);
  const [whatsAppFormat, setWhatsAppFormat] = useState<WhatsAppFormat>('summary');

  // Generate PDF URL for preview when modal opens
  const handleOpenChange = (isOpen: boolean) => {
    if (isOpen && !pdfUrl) {
      const url = URL.createObjectURL(pdfBlob);
      setPdfUrl(url);
    } else if (!isOpen && pdfUrl) {
      URL.revokeObjectURL(pdfUrl);
      setPdfUrl('');
    }
    onOpenChange(isOpen);
  };

  const handleDownload = async () => {
    try {
      triggerDownload(pdfBlob, `${filename}.pdf`);
      toast.success('PDF downloaded');
    } catch (error) {
      console.error('Download error:', error);
      toast.error('Failed to download PDF');
    }
  };

  const handleWhatsAppShare = async () => {
    if (sharing) return;
    setSharing(true);

    try {
      let blob = pdfBlob;

      // Get the appropriate blob based on selected format
      if (whatsAppFormat === 'detailed') {
        blob = await getDetailedBlob();
      } else {
        blob = await getSummaryBlob();
      }

      const result = await sharePdfOnWhatsApp({
        blob,
        filename: `${filename}_${whatsAppFormat}.pdf`,
        message: `Transaction Report (${whatsAppFormat === 'detailed' ? 'Detailed' : 'Summary'} - Headwise)`,
      });

      if (result === 'shared') {
        toast.success('Shared via WhatsApp');
      } else if (result === 'downloaded') {
        toast.success('PDF downloaded — attach it in WhatsApp');
      }
    } catch (error) {
      console.error('WhatsApp share error:', error);
      toast.error('Could not share via WhatsApp');
    } finally {
      setSharing(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-w-4xl max-h-[90vh] p-0 flex flex-col">
        <DialogHeader className="px-6 py-4 border-b sticky top-0 bg-background">
          <DialogTitle className="flex items-center justify-between">
            <span>Transaction Report Preview</span>
            <button
              onClick={() => onOpenChange(false)}
              className="text-muted-foreground hover:text-foreground"
            >
              <X className="w-5 h-5" />
            </button>
          </DialogTitle>
        </DialogHeader>

        {/* PDF Preview */}
        {pdfUrl && (
          <div className="flex-1 overflow-hidden bg-gray-100">
            <iframe
              src={pdfUrl}
              title="PDF Preview"
              className="w-full h-full border-0"
              style={{ minHeight: '500px' }}
            />
          </div>
        )}

        {/* Action Footer */}
        <div className="px-6 py-4 border-t bg-secondary/50 space-y-3">
          {/* WhatsApp Format Selection */}
          <div className="flex items-center gap-3">
            <label className="text-xs font-medium text-muted-foreground whitespace-nowrap">
              Share format:
            </label>
            <Select value={whatsAppFormat} onValueChange={(v) => setWhatsAppFormat(v as WhatsAppFormat)}>
              <SelectTrigger className="h-8 w-40 text-xs">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="summary">Summary (Headwise Only)</SelectItem>
                <SelectItem value="detailed">Detailed (All Transactions)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Action Buttons */}
          <div className="flex gap-2 justify-end">
            <Button
              onClick={handleDownload}
              variant="outline"
              size="sm"
              className="gap-2"
            >
              <Download className="w-4 h-4" />
              Download PDF
            </Button>

            <Button
              onClick={() => void handleWhatsAppShare()}
              disabled={sharing}
              size="sm"
              className="gap-2 bg-[#25D366] hover:bg-[#20BA5E] text-white"
            >
              <Share2 className="w-4 h-4" />
              {sharing ? 'Sharing…' : 'Share WhatsApp'}
            </Button>

            <Button
              onClick={() => onOpenChange(false)}
              variant="outline"
              size="sm"
            >
              Close
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
