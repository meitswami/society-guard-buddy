import { describe, expect, it } from 'vitest';
import {
  currentCommitteeMembers,
  dedupeCommitteeByPosition,
  splitCommitteeTerms,
} from '@/lib/committeeMember';

const row = (partial: {
  name: string;
  position: string;
  term_from?: string | null;
  term_to?: string | null;
  sort_order?: number;
  is_active?: boolean;
}) => ({
  id: partial.name,
  society_id: 's',
  phone: null,
  gender: null,
  photo: null,
  show_representative: false,
  rep_name: null,
  rep_phone: null,
  rep_photo: null,
  sort_order: partial.sort_order ?? 0,
  is_active: partial.is_active ?? true,
  flat_id: null,
  flat_number: null,
  flat_owner_name: null,
  selection_type: 'elected' as const,
  name: partial.name,
  position: partial.position,
  term_from: partial.term_from ?? null,
  term_to: partial.term_to ?? null,
});

describe('splitCommitteeTerms', () => {
  const previous = [
    row({ name: 'Abhishek sharma', position: 'President', term_from: '2026-03-01', term_to: '2026-08-13', sort_order: 1 }),
    row({ name: 'Harish Swami', position: 'Committee Member', term_from: null, term_to: '2026-08-13', sort_order: 6 }),
  ];
  const current = [
    row({ name: 'Suresh Pareek', position: 'President', term_from: '2026-08-14', term_to: '2028-08-13', sort_order: 0 }),
    row({ name: 'Jaya Sharma', position: 'Vice-President', term_from: '2026-08-14', term_to: '2028-08-13', sort_order: 1 }),
  ];

  it('shows the latest term as current even before term_from calendar date', () => {
    const split = splitCommitteeTerms([...previous, ...current]);
    expect(split.currentTermFrom).toBe('2026-08-14');
    expect(split.current.map((r) => r.name)).toEqual(['Suresh Pareek', 'Jaya Sharma']);
    expect(split.previous.map((r) => r.name)).toEqual(['Abhishek sharma', 'Harish Swami']);
  });

  it('currentCommitteeMembers ignores the previous term', () => {
    const names = currentCommitteeMembers([...previous, ...current]).map((r) => r.name);
    expect(names).toEqual(['Suresh Pareek', 'Jaya Sharma']);
  });
});

describe('dedupeCommitteeByPosition', () => {
  it('keeps one office-bearer per unique post, preferring a closed tenure', () => {
    const rows = [
      row({ name: 'Jaya', position: 'Vice-President', term_from: '2026-08-14', term_to: null, sort_order: 1 }),
      row({ name: 'Jaya Sharma', position: 'Vice-President', term_from: '2026-08-14', term_to: '2028-08-13', sort_order: 10 }),
      row({ name: 'Sunil Sharma', position: 'Committee Member', term_from: '2026-08-14', sort_order: 5 }),
      row({ name: 'Abhishek Sharma', position: 'Committee Member', term_from: '2026-08-14', sort_order: 6 }),
    ];
    const names = dedupeCommitteeByPosition(rows).map((r) => r.name);
    expect(names).toEqual(['Jaya Sharma', 'Sunil Sharma', 'Abhishek Sharma']);
  });
});
