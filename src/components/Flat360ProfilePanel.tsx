import { useMemo, useState } from 'react';
import {
  Bell,
  Calendar,
  IndianRupee,
  MessageSquare,
  ParkingSquare,
  RefreshCw,
  ScrollText,
  UserCheck,
  Users,
  UserRound,
} from 'lucide-react';
import { fmtDate, fmtDateTime } from '@/lib/dateFormat';
import type { Flat360FetchParams, Flat360TimelineKind } from '@/lib/flat360Types';
import { timelineKindLabel } from '@/lib/flat360Timeline';
import { useFlat360Profile } from '@/hooks/useFlat360Profile';
import { cn } from '@/lib/utils';

type Flat360ProfilePanelProps = {
  params: Flat360FetchParams;
  className?: string;
  compact?: boolean;
};

const KIND_ICONS: Record<Flat360TimelineKind, typeof Bell> = {
  payment: IndianRupee,
  notification: Bell,
  ticket: MessageSquare,
  meeting: ScrollText,
  event_contribution: Calendar,
  visitor: UserRound,
};

function formatInr(amount: number): string {
  return `₹${amount.toLocaleString('en-IN')}`;
}

function SummaryCard({
  label,
  value,
  sub,
  className,
}: {
  label: string;
  value: string;
  sub?: string;
  className?: string;
}) {
  return (
    <div className={cn('rounded-lg border border-border bg-secondary/30 p-2.5', className)}>
      <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium">{label}</p>
      <p className="text-sm font-semibold text-foreground mt-0.5">{value}</p>
      {sub ? <p className="text-[10px] text-muted-foreground mt-0.5">{sub}</p> : null}
    </div>
  );
}

const Flat360ProfilePanel = ({ params, className, compact = false }: Flat360ProfilePanelProps) => {
  const [timelineLimit, setTimelineLimit] = useState(params.timelineLimit ?? 50);
  const fetchParams = useMemo(
    () => ({ ...params, timelineLimit }),
    [params, timelineLimit],
  );
  const { profile, loading, error, reload } = useFlat360Profile(fetchParams);

  if (loading && !profile) {
    return (
      <div className={cn('rounded-lg border border-border bg-muted/20 p-4 text-center', className)}>
        <p className="text-xs text-muted-foreground">Loading 360° profile…</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className={cn('rounded-lg border border-destructive/30 bg-destructive/5 p-4', className)}>
        <p className="text-xs text-destructive">{error}</p>
        <button type="button" onClick={() => void reload()} className="text-[10px] text-primary mt-2 font-medium">
          Retry
        </button>
      </div>
    );
  }

  if (!profile) return null;

  const { summary } = profile;

  return (
    <div className={cn('space-y-3', className)}>
      <div className="flex items-center justify-between gap-2">
        <div>
          <p className="text-xs font-semibold text-foreground">Member 360°</p>
          <p className="text-[10px] text-muted-foreground">
            Flat {profile.flatNumber}
            {profile.wing ? ` · Wing ${profile.wing}` : ''}
            {profile.floor ? ` · ${profile.floor}` : ''}
          </p>
        </div>
        <button
          type="button"
          onClick={() => void reload()}
          className="p-1.5 rounded-md text-muted-foreground hover:text-primary hover:bg-primary/10"
          title="Refresh"
        >
          <RefreshCw className={cn('w-3.5 h-3.5', loading && 'animate-spin')} />
        </button>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <SummaryCard
          label="Paid (12 mo)"
          value={formatInr(summary.verifiedPaid12m)}
          sub={summary.pendingCount > 0 ? `${summary.pendingCount} pending · ${formatInr(summary.pendingAmount)}` : 'No pending dues'}
        />
        <SummaryCard
          label="Meetings"
          value={`${summary.meetingsAttended}/${summary.meetingsTotal}`}
          sub={summary.meetingsTotal > 0 ? `${summary.attendancePct}% attendance` : 'No meetings in period'}
        />
        <SummaryCard
          label="Parking"
          value={String(summary.parkingSlots)}
          sub={summary.parkingSlots === 1 ? 'slot allocated' : 'slots allocated'}
        />
        <SummaryCard
          label="Open feedback"
          value={String(summary.openTickets)}
          sub={summary.openTickets === 0 ? 'No open tickets' : 'pending resolution'}
        />
      </div>

      {!compact && profile.parking.length > 0 && (
        <div className="rounded-lg border border-border p-2.5 space-y-1.5">
          <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-wider text-muted-foreground font-medium">
            <ParkingSquare className="w-3 h-3" />
            Parking
          </div>
          {profile.parking.map((slot) => (
            <p key={slot.id} className="text-xs text-foreground">
              <span className="font-mono font-medium">{slot.spaceNumber}</span>
              <span className="text-muted-foreground"> · {slot.spaceType}</span>
              {slot.vehicleNumber ? (
                <span className="text-muted-foreground"> · {slot.vehicleNumber}</span>
              ) : null}
            </p>
          ))}
        </div>
      )}

      {!compact && profile.members.length > 0 && (
        <div className="rounded-lg border border-border p-2.5 space-y-1.5">
          <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-wider text-muted-foreground font-medium">
            <Users className="w-3 h-3" />
            Household ({profile.members.length})
          </div>
          {profile.members.map((m) => (
            <p key={m.id} className="text-xs text-foreground truncate">
              {m.name}
              {m.isPrimary ? <span className="text-primary ml-1">★</span> : null}
              <span className="text-muted-foreground capitalize"> · {m.relation}</span>
              {m.phone ? <span className="text-muted-foreground font-mono"> · {m.phone}</span> : null}
            </p>
          ))}
        </div>
      )}

      <div className="space-y-2">
        <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-wider text-muted-foreground font-medium">
          <UserCheck className="w-3 h-3" />
          Activity timeline
        </div>
        {profile.timeline.length === 0 ? (
          <p className="text-xs text-muted-foreground text-center py-4">No activity in the last 12 months</p>
        ) : (
          <div className="space-y-1.5">
            {profile.timeline.map((item) => {
              const Icon = KIND_ICONS[item.kind];
              return (
                <div
                  key={item.id}
                  className="flex gap-2.5 rounded-lg border border-border bg-background p-2.5"
                >
                  <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Icon className="w-4 h-4 text-primary" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="text-xs font-medium text-foreground truncate">{item.title}</p>
                        <p className="text-[10px] text-muted-foreground">
                          {timelineKindLabel(item.kind)}
                          {item.status ? ` · ${item.status}` : ''}
                        </p>
                      </div>
                      <div className="text-right flex-shrink-0">
                        {item.amount != null && item.amount > 0 ? (
                          <p className="text-xs font-semibold text-foreground">{formatInr(item.amount)}</p>
                        ) : null}
                        <p className="text-[10px] text-muted-foreground whitespace-nowrap">
                          {fmtDate(item.at) || fmtDateTime(item.at)}
                        </p>
                      </div>
                    </div>
                    {item.detail ? (
                      <p className="text-[10px] text-muted-foreground mt-1 line-clamp-2">{item.detail}</p>
                    ) : null}
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {profile.hasMoreTimeline && (
          <button
            type="button"
            onClick={() => setTimelineLimit((n) => n + 30)}
            className="w-full text-xs text-primary font-medium py-2 hover:underline"
          >
            Load more activity
          </button>
        )}
      </div>
    </div>
  );
};

export default Flat360ProfilePanel;
