import { useMemo } from 'react';
import { BarChart3 } from 'lucide-react';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { computeFixedAssetReport } from '@/lib/fixedAssetReport';
import { exportFixedAssetReport } from '@/lib/fixedAssetReportExport';
import { moneyInr } from '@/lib/reportExportUtils';
import type { FixedAsset } from '@/lib/fixedAssetTypes';

type Props = {
  societyName: string;
  assets: FixedAsset[];
};

export default function FixedAssetReports({ societyName, assets }: Props) {
  const summary = useMemo(() => computeFixedAssetReport(assets), [assets]);

  return (
    <div>
      <div className="flex items-center justify-between gap-2 mb-3">
        <h2 className="text-sm font-semibold flex items-center gap-2">
          <BarChart3 className="w-4 h-4 text-primary" />
          Fixed assets report
        </h2>
        <ExportFormatMenu
          onExport={(format) => exportFixedAssetReport({ societyName, assets, format })}
          disabled={assets.length === 0}
        />
      </div>

      <div className="grid grid-cols-2 gap-2 mb-4">
        <DescriptiveStatCard title="Total assets" value={String(summary.totalAssets)} description="All items in the fixed assets register." caption="All registered items" />
        <DescriptiveStatCard title="Active" value={String(summary.activeCount)} description="Assets currently in use or under repair." caption="In use or under repair" />
        <DescriptiveStatCard title="Total value" value={moneyInr(summary.totalBillValue)} description="Sum of bill values for non-disposed assets." caption="Bill value of active assets" />
        <DescriptiveStatCard title="Not acquired" value={String(summary.placeholderCount)} description="Standard templates awaiting builder handover details." caption="Builder templates pending" />
        <DescriptiveStatCard title="Warranty alert" value={String(summary.warrantyExpiringSoon)} description="Assets whose warranty ends within the next 60 days." caption="Expiring within 60 days" />
        <DescriptiveStatCard title="AMC alert" value={String(summary.amcExpiringSoon)} description="Assets whose AMC contract ends within the next 60 days." caption="Expiring within 60 days" />
      </div>

      {summary.bySubHead.length > 0 && (
        <section className="mb-4">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">By sub-head</p>
          <div className="overflow-x-auto rounded-lg border border-border">
            <table className="w-full text-xs">
              <thead>
                <tr className="bg-muted/50 border-b border-border">
                  <th className="text-left p-2 font-medium">Sub-head</th>
                  <th className="text-right p-2 font-medium">Count</th>
                  <th className="text-right p-2 font-medium">Value</th>
                </tr>
              </thead>
              <tbody>
                {summary.bySubHead.map((r) => (
                  <tr key={r.subHead} className="border-b border-border/60 last:border-0">
                    <td className="p-2">{r.subHead}</td>
                    <td className="p-2 text-right">{r.count}</td>
                    <td className="p-2 text-right font-mono">{moneyInr(r.value)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {summary.bySource.length > 0 && (
        <section>
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">By source</p>
          <div className="overflow-x-auto rounded-lg border border-border">
            <table className="w-full text-xs">
              <thead>
                <tr className="bg-muted/50 border-b border-border">
                  <th className="text-left p-2 font-medium">Source</th>
                  <th className="text-right p-2 font-medium">Count</th>
                  <th className="text-right p-2 font-medium">Value</th>
                </tr>
              </thead>
              <tbody>
                {summary.bySource.map((r) => (
                  <tr key={r.source} className="border-b border-border/60 last:border-0">
                    <td className="p-2">{r.source}</td>
                    <td className="p-2 text-right">{r.count}</td>
                    <td className="p-2 text-right font-mono">{moneyInr(r.value)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
