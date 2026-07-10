export type Flat360TimelineKind =
  | 'payment'
  | 'notification'
  | 'ticket'
  | 'meeting'
  | 'event_contribution'
  | 'visitor';

export type Flat360TimelineItem = {
  id: string;
  kind: Flat360TimelineKind;
  at: string;
  title: string;
  detail?: string;
  status?: string;
  amount?: number;
};

export type Flat360ParkingSlot = {
  id: string;
  spaceNumber: string;
  spaceType: string;
  floorLevel?: string;
  vehicleNumber?: string;
};

export type Flat360Member = {
  id: string;
  name: string;
  phone?: string;
  relation: string;
  isPrimary: boolean;
};

export type Flat360Summary = {
  verifiedPaid12m: number;
  pendingCount: number;
  pendingAmount: number;
  openTickets: number;
  parkingSlots: number;
  meetingsAttended: number;
  meetingsTotal: number;
  attendancePct: number;
};

export type Flat360Profile = {
  flatId: string;
  flatNumber: string;
  ownerName?: string;
  floor?: string;
  wing?: string;
  isOccupied: boolean;
  members: Flat360Member[];
  parking: Flat360ParkingSlot[];
  summary: Flat360Summary;
  timeline: Flat360TimelineItem[];
  hasMoreTimeline: boolean;
};

export type Flat360FetchParams = {
  societyId: string;
  flatId: string;
  flatNumber: string;
  monthsBack?: number;
  timelineLimit?: number;
  /** When set, notifications are filtered for resident visibility. */
  residentContext?: { id: string; name: string };
  /** Admin-only: include recent gate visitors in timeline. */
  includeVisitors?: boolean;
};
