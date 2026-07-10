import type { Flat360TimelineItem, Flat360TimelineKind } from '@/lib/flat360Types';

export function mergeFlat360Timeline(
  items: Flat360TimelineItem[],
  limit: number,
): { timeline: Flat360TimelineItem[]; hasMore: boolean } {
  const sorted = [...items].sort(
    (a, b) => new Date(b.at).getTime() - new Date(a.at).getTime(),
  );
  return {
    timeline: sorted.slice(0, limit),
    hasMore: sorted.length > limit,
  };
}

export function timelineKindLabel(kind: Flat360TimelineKind): string {
  switch (kind) {
    case 'payment':
      return 'Payment';
    case 'notification':
      return 'Notice';
    case 'ticket':
      return 'Feedback';
    case 'meeting':
      return 'Meeting';
    case 'event_contribution':
      return 'Event';
    case 'visitor':
      return 'Visitor';
    default:
      return 'Activity';
  }
}
