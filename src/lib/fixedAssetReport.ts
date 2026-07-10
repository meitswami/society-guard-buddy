import {
  type FixedAsset,
  FIXED_ASSET_SOURCE_LABELS,
  FIXED_ASSET_STATUS_LABELS,
  isAmcExpired,
  isAmcExpiringSoon,
  isWarrantyExpired,
  isWarrantyExpiringSoon,
} from '@/lib/fixedAssetTypes';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';

export type FixedAssetReportSummary = {
  totalAssets: number;
  activeCount: number;
  placeholderCount: number;
  totalBillValue: number;
  warrantyExpiringSoon: number;
  amcExpiringSoon: number;
  warrantyExpired: number;
  amcExpired: number;
  bySubHead: { subHead: string; count: number; value: number }[];
  bySource: { source: string; count: number; value: number }[];
};

export function computeFixedAssetReport(assets: FixedAsset[]): FixedAssetReportSummary {
  const active = assets.filter((a) => a.status !== 'disposed' && a.status !== 'written_off');
  const bySubHeadMap = new Map<string, { count: number; value: number }>();
  const bySourceMap = new Map<string, { count: number; value: number }>();

  let totalBillValue = 0;
  let warrantyExpiringSoon = 0;
  let amcExpiringSoon = 0;
  let warrantyExpired = 0;
  let amcExpired = 0;

  for (const a of active) {
    const val = Number(a.bill_value ?? 0);
    totalBillValue += val;

    const sub = a.sub_head?.trim() || 'Uncategorized';
    const subRow = bySubHeadMap.get(sub) ?? { count: 0, value: 0 };
    subRow.count += 1;
    subRow.value += val;
    bySubHeadMap.set(sub, subRow);

    const src = FIXED_ASSET_SOURCE_LABELS[a.source_type] ?? a.source_type;
    const srcRow = bySourceMap.get(src) ?? { count: 0, value: 0 };
    srcRow.count += 1;
    srcRow.value += val;
    bySourceMap.set(src, srcRow);

    if (isWarrantyExpiringSoon(a)) warrantyExpiringSoon += 1;
    if (isAmcExpiringSoon(a)) amcExpiringSoon += 1;
    if (isWarrantyExpired(a)) warrantyExpired += 1;
    if (isAmcExpired(a)) amcExpired += 1;
  }

  return {
    totalAssets: assets.length,
    activeCount: assets.filter((a) => a.status === 'active' || a.status === 'under_repair').length,
    placeholderCount: assets.filter((a) => a.status === 'placeholder').length,
    totalBillValue,
    warrantyExpiringSoon,
    amcExpiringSoon,
    warrantyExpired,
    amcExpired,
    bySubHead: [...bySubHeadMap.entries()]
      .map(([subHead, v]) => ({ subHead, ...v }))
      .sort((a, b) => b.value - a.value || a.subHead.localeCompare(b.subHead)),
    bySource: [...bySourceMap.entries()]
      .map(([source, v]) => ({ source, ...v }))
      .sort((a, b) => b.value - a.value),
  };
}

export function fixedAssetRegisterRows(assets: FixedAsset[]): string[][] {
  return assets.map((a) => [
    a.asset_name,
    a.sub_head ?? '',
    FIXED_ASSET_STATUS_LABELS[a.status],
    FIXED_ASSET_SOURCE_LABELS[a.source_type],
    a.acquisition_date ? fmtIsoDateToDisplay(a.acquisition_date) : '',
    a.bill_value != null ? String(a.bill_value) : '',
    a.vendor_name ?? '',
    a.location ?? '',
    a.warranty_end_date ? fmtIsoDateToDisplay(a.warranty_end_date) : '',
    a.amc_end_date ? fmtIsoDateToDisplay(a.amc_end_date) : '',
    a.amc_vendor ?? '',
    a.description ?? '',
  ]);
}

export const FIXED_ASSET_REGISTER_HEADERS = [
  'Asset name',
  'Sub-head',
  'Status',
  'Source',
  'Acquisition date',
  'Bill value (₹)',
  'Vendor',
  'Location',
  'Warranty end',
  'AMC end',
  'AMC vendor',
  'Description',
];
