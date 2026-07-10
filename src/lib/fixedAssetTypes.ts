/** Fixed assets register — types and standard residential-society asset templates. */

export type FixedAssetSourceType = 'builder_handover' | 'finance_transaction' | 'manual';

export type FixedAssetStatus = 'active' | 'under_repair' | 'disposed' | 'written_off' | 'placeholder';

export type FixedAsset = {
  id: string;
  society_id: string;
  asset_name: string;
  description: string | null;
  major_head: string;
  sub_head: string | null;
  expense_group_id: string | null;
  source_type: FixedAssetSourceType;
  finance_entry_id: string | null;
  expense_id: string | null;
  acquisition_date: string | null;
  bill_value: number | null;
  vendor_name: string | null;
  vendor_contact: string | null;
  asset_tag: string | null;
  serial_number: string | null;
  location: string | null;
  warranty_start_date: string | null;
  warranty_end_date: string | null;
  warranty_period_months: number | null;
  amc_start_date: string | null;
  amc_end_date: string | null;
  amc_period_months: number | null;
  amc_vendor: string | null;
  status: FixedAssetStatus;
  disposal_date: string | null;
  disposal_value: number | null;
  disposal_notes: string | null;
  bill_attachment_url: string | null;
  template_key: string | null;
  notes: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

export type FixedAssetInput = {
  asset_name: string;
  description?: string | null;
  major_head?: string;
  sub_head?: string | null;
  expense_group_id?: string | null;
  source_type?: FixedAssetSourceType;
  acquisition_date?: string | null;
  bill_value?: number | null;
  vendor_name?: string | null;
  vendor_contact?: string | null;
  asset_tag?: string | null;
  serial_number?: string | null;
  location?: string | null;
  warranty_start_date?: string | null;
  warranty_end_date?: string | null;
  warranty_period_months?: number | null;
  amc_start_date?: string | null;
  amc_end_date?: string | null;
  amc_period_months?: number | null;
  amc_vendor?: string | null;
  status?: FixedAssetStatus;
  disposal_date?: string | null;
  disposal_value?: number | null;
  disposal_notes?: string | null;
  bill_attachment_url?: string | null;
  template_key?: string | null;
  notes?: string | null;
};

export type StandardAssetTemplate = {
  template_key: string;
  asset_name: string;
  sub_head: string;
  description: string;
  location_hint: string;
  default_warranty_months?: number;
  default_amc_months?: number;
};

/** Standard assets commonly found in Indian residential societies. */
export const STANDARD_SOCIETY_ASSET_TEMPLATES: StandardAssetTemplate[] = [
  {
    template_key: 'garden_landscaping',
    asset_name: 'Garden & Landscaping',
    sub_head: 'Garden & Landscaping',
    description: 'Lawn, plants, irrigation, garden furniture and landscaping from builder handover.',
    location_hint: 'Common garden / podium',
    default_warranty_months: 12,
  },
  {
    template_key: 'gym_equipment',
    asset_name: 'Gymnasium Equipment',
    sub_head: 'Gym Equipment',
    description: 'Treadmills, weights, cycles and other fitness equipment in society gym.',
    location_hint: 'Society gym / clubhouse',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'children_play_area',
    asset_name: "Children's Play Area",
    sub_head: 'Play Area Equipment',
    description: 'Swings, slides, see-saw and safety flooring in children play zone.',
    location_hint: 'Kids play area',
    default_warranty_months: 24,
  },
  {
    template_key: 'dg_set',
    asset_name: 'Diesel Generator (DG Set)',
    sub_head: 'DG Set',
    description: 'Backup power generator with AMF panel and fuel tank.',
    location_hint: 'DG room / basement',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'elevator_lift',
    asset_name: 'Elevator / Lift',
    sub_head: 'Lift',
    description: 'Passenger lifts with machine room / MRL equipment.',
    location_hint: 'Lift lobby / shaft',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'fire_fighting',
    asset_name: 'Fire Fighting Equipment',
    sub_head: 'Fire Fighting',
    description: 'Hydrants, extinguishers, hose reels, sprinkler and alarm panel.',
    location_hint: 'All floors / pump room',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'borewell',
    asset_name: 'Borewell / Water Boring',
    sub_head: 'Borewell',
    description: 'Borewell, submersible pump and related piping.',
    location_hint: 'Pump room / underground',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'water_softener',
    asset_name: 'Water Softener',
    sub_head: 'Water Softener',
    description: 'Water softening plant / RO pre-treatment for society supply.',
    location_hint: 'Pump room / STP area',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'swimming_pool',
    asset_name: 'Swimming Pool Equipment',
    sub_head: 'Swimming Pool',
    description: 'Filtration plant, pumps and pool accessories.',
    location_hint: 'Swimming pool plant room',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'cctv_security',
    asset_name: 'CCTV & Security Systems',
    sub_head: 'CCTV',
    description: 'Cameras, NVR/DVR, access control and monitoring equipment.',
    location_hint: 'Gate, lobby, parking, perimeter',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'solar_panel',
    asset_name: 'Solar Panel System',
    sub_head: 'Solar',
    description: 'Rooftop solar PV panels, inverters and net-metering setup.',
    location_hint: 'Terrace / rooftop',
    default_warranty_months: 60,
    default_amc_months: 12,
  },
  {
    template_key: 'stp_wtp',
    asset_name: 'STP / WTP Plant',
    sub_head: 'STP / WTP',
    description: 'Sewage treatment or water treatment plant machinery.',
    location_hint: 'STP / WTP room',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'common_lighting',
    asset_name: 'Common Area Lighting',
    sub_head: 'Common Lighting',
    description: 'LED fixtures, poles and drivers for lobbies, parking and pathways.',
    location_hint: 'Common areas',
    default_warranty_months: 24,
  },
  {
    template_key: 'intercom_pa',
    asset_name: 'Intercom / PA System',
    sub_head: 'Intercom',
    description: 'Flat intercom, lobby panel and public address system.',
    location_hint: 'Lobby / guard room',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'boom_barrier',
    asset_name: 'Parking Boom Barrier',
    sub_head: 'Boom Barrier',
    description: 'Vehicle entry/exit boom barrier with RFID or manual control.',
    location_hint: 'Main gate / parking entry',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
  {
    template_key: 'rainwater_harvesting',
    asset_name: 'Rainwater Harvesting System',
    sub_head: 'Rainwater Harvesting',
    description: 'Collection pits, filters and recharge structures.',
    location_hint: 'Terrace / recharge pits',
    default_warranty_months: 24,
  },
  {
    template_key: 'compound_gate',
    asset_name: 'Compound Wall & Main Gate',
    sub_head: 'Compound & Gate',
    description: 'Perimeter wall, main gate structure and automation.',
    location_hint: 'Society perimeter',
    default_warranty_months: 24,
  },
  {
    template_key: 'electrical_panel',
    asset_name: 'HT/LT Electrical Panel',
    sub_head: 'Electrical Panel',
    description: 'Main LT panel, transformers and distribution boards.',
    location_hint: 'Electrical room',
    default_warranty_months: 12,
    default_amc_months: 12,
  },
];

export const FIXED_ASSET_STATUS_LABELS: Record<FixedAssetStatus, string> = {
  active: 'Active',
  under_repair: 'Under repair',
  disposed: 'Disposed',
  written_off: 'Written off',
  placeholder: 'Not yet acquired',
};

export const FIXED_ASSET_SOURCE_LABELS: Record<FixedAssetSourceType, string> = {
  builder_handover: 'Builder handover',
  finance_transaction: 'Finance payment',
  manual: 'Manual entry',
};

export function computeEndDateFromMonths(startIso: string | null | undefined, months: number | null | undefined): string | null {
  if (!startIso || !months || months <= 0) return null;
  const d = new Date(`${startIso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  d.setMonth(d.getMonth() + months);
  return d.toISOString().slice(0, 10);
}

export function daysUntilDate(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const target = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(target.getTime())) return null;
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  return Math.ceil((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
}

export function isWarrantyExpiringSoon(asset: FixedAsset, withinDays = 60): boolean {
  const days = daysUntilDate(asset.warranty_end_date);
  return days != null && days >= 0 && days <= withinDays;
}

export function isAmcExpiringSoon(asset: FixedAsset, withinDays = 60): boolean {
  const days = daysUntilDate(asset.amc_end_date);
  return days != null && days >= 0 && days <= withinDays;
}

export function isWarrantyExpired(asset: FixedAsset): boolean {
  const days = daysUntilDate(asset.warranty_end_date);
  return days != null && days < 0;
}

export function isAmcExpired(asset: FixedAsset): boolean {
  const days = daysUntilDate(asset.amc_end_date);
  return days != null && days < 0;
}
