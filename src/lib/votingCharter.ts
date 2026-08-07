/** Society election charter — keys resolve via useLanguage().t() (static + society overrides).
 * Controlling source: registered Society bye-laws (7-member Management Committee).
 * Charter + bye-laws are merged into one descriptive step-by-step member program.
 */

export const VOTING_CHARTER_TITLE_KEY = 'votingCharter.title';

/** Prominent resident summary (bye-law composition + voting rights). */
export const VOTING_CHARTER_SUMMARY = {
  titleKey: 'votingCharter.summary.title',
  postsKey: 'votingCharter.summary.posts',
  voteRightKey: 'votingCharter.summary.voteRight',
  proxyKey: 'votingCharter.summary.proxy',
  quorumKey: 'votingCharter.summary.quorum',
} as const;

export type ElectionProgramStep = {
  stepKey: string;
  detailKey: string;
  /** Bye-law points shown under this step (merged charter). */
  pointKeys: readonly string[];
};

/**
 * Numbered member program — charter narrative + bye-law rules in member journey order.
 * (No ranked ballot / no auto 2nd–3rd as committee seats.)
 */
export const ELECTION_PROGRAM_STEPS: readonly ElectionProgramStep[] = [
  {
    stepKey: 'votingCharter.program.s1.title',
    detailKey: 'votingCharter.program.s1.detail',
    pointKeys: [
      'votingCharter.committee.p1',
      'votingCharter.committee.p2',
    ],
  },
  {
    stepKey: 'votingCharter.program.s2.title',
    detailKey: 'votingCharter.program.s2.detail',
    pointKeys: [
      'votingCharter.eligibility.p1',
      'votingCharter.eligibility.p2',
      'votingCharter.eligibility.p3',
      'votingCharter.eligibility.p4',
    ],
  },
  {
    stepKey: 'votingCharter.program.s3.title',
    detailKey: 'votingCharter.program.s3.detail',
    pointKeys: [
      'votingCharter.nomination.p1',
      'votingCharter.nomination.p2',
      'votingCharter.nomination.p3',
    ],
  },
  {
    stepKey: 'votingCharter.program.s4.title',
    detailKey: 'votingCharter.program.s4.detail',
    pointKeys: [
      'votingCharter.method.p1',
      'votingCharter.method.p2',
      'votingCharter.method.p3',
      'votingCharter.method.p4',
    ],
  },
  {
    stepKey: 'votingCharter.program.s5.title',
    detailKey: 'votingCharter.program.s5.detail',
    pointKeys: [
      'votingCharter.docs.p2',
      'votingCharter.committee.p3',
    ],
  },
  {
    stepKey: 'votingCharter.program.s6.title',
    detailKey: 'votingCharter.program.s6.detail',
    pointKeys: [
      'votingCharter.docs.p1',
      'votingCharter.docs.p3',
      'votingCharter.committee.p4',
    ],
  },
] as const;

/** @deprecated Separate rules list removed — points live under ELECTION_PROGRAM_STEPS. Kept for any legacy imports. */
export const VOTING_CHARTER_SECTIONS = [
  {
    headingKey: 'votingCharter.eligibility.heading',
    pointKeys: [
      'votingCharter.eligibility.p1',
      'votingCharter.eligibility.p2',
      'votingCharter.eligibility.p3',
      'votingCharter.eligibility.p4',
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
    ],
  },
  {
    headingKey: 'votingCharter.committee.heading',
    pointKeys: [
      'votingCharter.committee.p1',
      'votingCharter.committee.p2',
      'votingCharter.committee.p3',
      'votingCharter.committee.p4',
    ],
  },
  {
    headingKey: 'votingCharter.docs.heading',
    pointKeys: [
      'votingCharter.docs.p1',
      'votingCharter.docs.p2',
      'votingCharter.docs.p3',
      'votingCharter.docs.p4',
    ],
  },
] as const;
