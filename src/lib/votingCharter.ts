/** Society election & voting charter — keys resolve via useLanguage().t() (static + society overrides). */

export const VOTING_CHARTER_TITLE_KEY = 'votingCharter.title';

export const VOTING_CHARTER_SECTIONS = [
  {
    headingKey: 'votingCharter.eligibility.heading',
    pointKeys: [
      'votingCharter.eligibility.p1',
      'votingCharter.eligibility.p2',
      'votingCharter.eligibility.p3',
    ],
  },
  {
    headingKey: 'votingCharter.nomination.heading',
    pointKeys: [
      'votingCharter.nomination.p1',
      'votingCharter.nomination.p2',
      'votingCharter.nomination.p3',
    ],
  },
  {
    headingKey: 'votingCharter.method.heading',
    pointKeys: [
      'votingCharter.method.p1',
      'votingCharter.method.p2',
      'votingCharter.method.p3',
      'votingCharter.method.p4',
      'votingCharter.method.p5',
    ],
  },
  {
    headingKey: 'votingCharter.docs.heading',
    pointKeys: [
      'votingCharter.docs.p1',
      'votingCharter.docs.p2',
      'votingCharter.docs.p3',
    ],
  },
] as const;
