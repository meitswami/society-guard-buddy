import { subMonths } from 'date-fns';
import { supabase } from '@/integrations/supabase/client';
import { mergeFlat360Timeline } from '@/lib/flat360Timeline';
import type {
  Flat360FetchParams,
  Flat360Member,
  Flat360ParkingSlot,
  Flat360Profile,
  Flat360Summary,
  Flat360TimelineItem,
} from '@/lib/flat360Types';
import { notificationVisibleToResident } from '@/lib/notificationAudience';

const DEFAULT_MONTHS_BACK = 12;
const MAX_TIMELINE_ITEMS = 500;

function cutoffIso(monthsBack: number): string {
  return subMonths(new Date(), monthsBack).toISOString();
}

function paymentStatusLabel(status: string): string {
  const s = String(status || '').toLowerCase();
  if (s === 'verified') return 'Verified';
  if (s === 'pending') return 'Pending';
  if (s === 'rejected') return 'Rejected';
  return status;
}

export async function fetchFlat360Profile(params: Flat360FetchParams): Promise<Flat360Profile> {
  const {
    societyId,
    flatId,
    flatNumber,
    monthsBack = DEFAULT_MONTHS_BACK,
    residentContext,
    includeVisitors = false,
  } = params;

  const cutoff = cutoffIso(monthsBack);

  const [
    flatRes,
    membersRes,
    paymentsRes,
    chargesRes,
    ticketsRes,
    parkingRes,
    attendeesRes,
    notificationsRes,
    contributionsRes,
    visitorsRes,
  ] = await Promise.all([
    supabase
      .from('flats')
      .select('id, flat_number, owner_name, floor, wing, is_occupied')
      .eq('id', flatId)
      .maybeSingle(),
    supabase
      .from('members')
      .select('id, name, phone, relation, is_primary')
      .eq('flat_id', flatId)
      .order('is_primary', { ascending: false })
      .order('name'),
    supabase
      .from('maintenance_payments')
      .select('id, amount, payment_status, payment_method, payment_date, created_at, due_date, transaction_id, notes, charge_id')
      .or(`flat_id.eq.${flatId},flat_number.eq.${flatNumber}`)
      .gte('created_at', cutoff)
      .order('created_at', { ascending: false })
      .limit(100),
    supabase
      .from('maintenance_charges')
      .select('id, title')
      .eq('society_id', societyId),
    supabase
      .from('support_tickets')
      .select('id, ticket_number, message, status, created_at')
      .eq('society_id', societyId)
      .eq('flat_number', flatNumber)
      .gte('created_at', cutoff)
      .order('created_at', { ascending: false })
      .limit(30),
    supabase
      .from('parking_spaces')
      .select('id, space_number, space_type, floor_level, allocated_vehicle_number')
      .eq('society_id', societyId)
      .or(`allocated_flat_id.eq.${flatId},allocated_flat_number.eq.${flatNumber}`),
    supabase
      .from('meeting_attendees')
      .select('id, meeting_id, is_present, display_name, created_at, meetings!inner(id, title, meeting_at, published, society_id, meeting_kind)')
      .eq('flat_number', flatNumber)
      .eq('meetings.society_id', societyId)
      .gte('meetings.meeting_at', cutoff)
      .order('created_at', { ascending: false })
      .limit(40),
    supabase
      .from('notifications')
      .select('id, title, message, type, target_type, target_id, created_at')
      .eq('society_id', societyId)
      .gte('created_at', cutoff)
      .order('created_at', { ascending: false })
      .limit(80),
    supabase
      .from('event_contributions')
      .select('id, amount, payment_method, created_at, verified_at, events!inner(id, title, society_id)')
      .eq('events.society_id', societyId)
      .or(`flat_id.eq.${flatId},flat_number.eq.${flatNumber}`)
      .gte('created_at', cutoff)
      .order('created_at', { ascending: false })
      .limit(30),
    includeVisitors
      ? supabase
          .from('visitors')
          .select('id, name, purpose, category, entry_time, created_at')
          .eq('society_id', societyId)
          .eq('flat_number', flatNumber)
          .gte('created_at', cutoff)
          .order('created_at', { ascending: false })
          .limit(20)
      : Promise.resolve({ data: [], error: null }),
  ]);

  if (flatRes.error) throw flatRes.error;

  const chargeTitleById = new Map(
    (chargesRes.data ?? []).map((c) => [String(c.id), String(c.title ?? 'Maintenance')]),
  );

  const members: Flat360Member[] = (membersRes.data ?? []).map((m) => ({
    id: String(m.id),
    name: String(m.name),
    phone: m.phone ? String(m.phone) : undefined,
    relation: String(m.relation ?? 'member'),
    isPrimary: !!m.is_primary,
  }));

  const parking: Flat360ParkingSlot[] = (parkingRes.data ?? []).map((p) => ({
    id: String(p.id),
    spaceNumber: String(p.space_number),
    spaceType: String(p.space_type ?? 'car'),
    floorLevel: p.floor_level ? String(p.floor_level) : undefined,
    vehicleNumber: p.allocated_vehicle_number ? String(p.allocated_vehicle_number) : undefined,
  }));

  const payments = paymentsRes.data ?? [];
  let verifiedPaid12m = 0;
  let pendingCount = 0;
  let pendingAmount = 0;
  for (const p of payments) {
    const amt = Number(p.amount || 0);
    const status = String(p.payment_status || '').toLowerCase();
    if (status === 'verified') verifiedPaid12m += amt;
    if (status === 'pending') {
      pendingCount += 1;
      pendingAmount += amt;
    }
  }

  const openTickets = (ticketsRes.data ?? []).filter(
    (t) => String(t.status).toLowerCase() === 'pending',
  ).length;

  const attendeeRows = attendeesRes.data ?? [];
  const meetingsAttended = attendeeRows.filter((a) => a.is_present).length;
  const meetingsTotal = new Set(attendeeRows.map((a) => String(a.meeting_id))).size;
  const attendancePct =
    meetingsTotal > 0 ? Math.round((meetingsAttended / meetingsTotal) * 100) : 0;

  const summary: Flat360Summary = {
    verifiedPaid12m,
    pendingCount,
    pendingAmount,
    openTickets,
    parkingSlots: parking.length,
    meetingsAttended,
    meetingsTotal,
    attendancePct,
  };

  const timelineItems: Flat360TimelineItem[] = [];

  for (const p of payments) {
    const chargeTitle = chargeTitleById.get(String(p.charge_id)) ?? 'Maintenance';
    timelineItems.push({
      id: `pay-${p.id}`,
      kind: 'payment',
      at: String(p.payment_date || p.created_at),
      title: chargeTitle,
      detail: `${paymentStatusLabel(String(p.payment_status))} · ${String(p.payment_method || 'cash').replace(/_/g, ' ')}`,
      status: String(p.payment_status),
      amount: Number(p.amount || 0),
    });
  }

  for (const row of notificationsRes.data ?? []) {
    if (residentContext) {
      const visible = notificationVisibleToResident(
        { target_type: row.target_type, target_id: row.target_id },
        residentContext,
        flatNumber,
      );
      if (!visible) continue;
    } else if (String(row.target_type) === 'flat') {
      const target = String(row.target_id ?? '').trim();
      const targets = target.includes(',')
        ? target.split(',').map((s) => s.trim())
        : [target];
      if (target && !targets.includes(flatNumber)) continue;
    }
    timelineItems.push({
      id: `notif-${row.id}`,
      kind: 'notification',
      at: String(row.created_at),
      title: String(row.title),
      detail: String(row.message ?? '').slice(0, 120),
      status: String(row.type ?? 'general'),
    });
  }

  for (const t of ticketsRes.data ?? []) {
    timelineItems.push({
      id: `ticket-${t.id}`,
      kind: 'ticket',
      at: String(t.created_at),
      title: `Ticket #${t.ticket_number}`,
      detail: String(t.message ?? '').slice(0, 120),
      status: String(t.status),
    });
  }

  for (const a of attendeeRows) {
    const meeting = a.meetings as {
      id?: string;
      title?: string;
      meeting_at?: string;
      meeting_kind?: string;
    } | null;
    if (!meeting?.id) continue;
    timelineItems.push({
      id: `meet-${a.id}`,
      kind: 'meeting',
      at: String(meeting.meeting_at || a.created_at),
      title: String(meeting.title ?? 'Society meeting'),
      detail: a.is_present ? 'Present' : 'Absent',
      status: String(meeting.meeting_kind ?? 'other'),
    });
  }

  for (const c of contributionsRes.data ?? []) {
    const event = c.events as { title?: string } | null;
    timelineItems.push({
      id: `evc-${c.id}`,
      kind: 'event_contribution',
      at: String(c.created_at),
      title: event?.title ? `Contribution: ${event.title}` : 'Event contribution',
      detail: c.verified_at ? 'Verified' : 'Recorded',
      amount: Number(c.amount || 0),
    });
  }

  for (const v of visitorsRes.data ?? []) {
    timelineItems.push({
      id: `vis-${v.id}`,
      kind: 'visitor',
      at: String(v.entry_time || v.created_at),
      title: String(v.name ?? 'Visitor'),
      detail: [v.category, v.purpose].filter(Boolean).join(' · '),
    });
  }

  const { timeline } = mergeFlat360Timeline(timelineItems, MAX_TIMELINE_ITEMS);

  const flat = flatRes.data;

  return {
    flatId,
    flatNumber: flat?.flat_number ?? flatNumber,
    ownerName: flat?.owner_name ?? undefined,
    floor: flat?.floor ?? undefined,
    wing: flat?.wing ?? undefined,
    isOccupied: flat?.is_occupied !== false,
    members,
    parking,
    summary,
    timeline,
  };
}
