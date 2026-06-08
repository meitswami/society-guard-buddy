export type EventFoodAdjustKind = 'shortfall_cover' | 'surplus_to_pool';

export type EventFoodAdjustSource = 'member_advance' | 'maintenance_pool' | 'corpus' | 'society_pool';

export const EVENT_FOOD_ADJUST_KIND_LABELS: Record<EventFoodAdjustKind, string> = {
  shortfall_cover: 'Cover shortfall',
  surplus_to_pool: 'Transfer surplus to society pool',
};

/** Source for shortfall cover (funds drawn in). Surplus to pool always uses society_pool. */
export const EVENT_FOOD_SHORTFALL_SOURCE_LABELS: Record<
  Exclude<EventFoodAdjustSource, 'society_pool'> | 'society_pool',
  string
> = {
  member_advance: 'Member advance / flat top-up',
  maintenance_pool: 'Society maintenance collections (pool)',
  corpus: 'Corpus fund',
  society_pool: 'Society pool account',
};

export type EventFoodAdjustmentRow = {
  id: string;
  society_id: string;
  event_id: string | null;
  adjustment_kind: EventFoodAdjustKind;
  amount: number;
  source_type: EventFoodAdjustSource;
  flat_number: string | null;
  payment_method: string;
  notes: string | null;
  created_by: string | null;
  created_at: string;
};

export function eventFoodBalance(params: {
  contribIn: number;
  foodOut: number;
  shortfallCovers: number;
  surplusTransfers: number;
}) {
  const { contribIn, foodOut, shortfallCovers, surplusTransfers } = params;
  const rawNet = contribIn - foodOut;
  const remainingShortfall = Math.max(0, foodOut - contribIn - shortfallCovers);
  const remainingSurplus = Math.max(0, contribIn - foodOut - surplusTransfers);
  const adjustedNet = contribIn + shortfallCovers - foodOut - surplusTransfers;
  return { rawNet, remainingShortfall, remainingSurplus, adjustedNet, shortfallCovers, surplusTransfers };
}
