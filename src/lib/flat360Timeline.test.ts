import { describe, expect, it } from 'vitest';
import { mergeFlat360Timeline } from '@/lib/flat360Timeline';
import type { Flat360TimelineItem } from '@/lib/flat360Types';

describe('mergeFlat360Timeline', () => {
  const items: Flat360TimelineItem[] = [
    { id: 'a', kind: 'payment', at: '2026-01-01T00:00:00Z', title: 'Older' },
    { id: 'b', kind: 'notification', at: '2026-06-01T00:00:00Z', title: 'Newer' },
    { id: 'c', kind: 'ticket', at: '2026-03-01T00:00:00Z', title: 'Middle' },
  ];

  it('sorts newest first and respects limit', () => {
    const { timeline, hasMore } = mergeFlat360Timeline(items, 2);
    expect(timeline.map((t) => t.id)).toEqual(['b', 'c']);
    expect(hasMore).toBe(true);
  });

  it('reports no more when within limit', () => {
    const { timeline, hasMore } = mergeFlat360Timeline(items, 5);
    expect(timeline).toHaveLength(3);
    expect(hasMore).toBe(false);
  });
});
