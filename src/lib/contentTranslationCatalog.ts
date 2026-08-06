import type { Lang } from '@/i18n/translations';

/** Keys admins may customize per society for member-facing display. */
export type ContentTranslationField = {
  key: string;
  label: string;
  multiline?: boolean;
};

export type ContentTranslationGroup = {
  id: string;
  title: string;
  description: string;
  fields: ContentTranslationField[];
};

export const CONTENT_TRANSLATION_GROUPS: ContentTranslationGroup[] = [
  {
    id: 'voting_charter',
    title: 'Voting Charter & Bye-laws',
    description:
      'Merged step-by-step election guide (charter + registered bye-laws) for the 7-member Management Committee. Editable in Hindi/English; downloadable as PDF.',
    fields: [
      { key: 'votingCharter.title', label: 'Title' },
      { key: 'votingCharter.summary.title', label: 'Summary — title' },
      { key: 'votingCharter.summary.posts', label: 'Summary — posts' },
      { key: 'votingCharter.summary.voteRight', label: 'Summary — voting right', multiline: true },
      { key: 'votingCharter.summary.proxy', label: 'Summary — proxy', multiline: true },
      { key: 'votingCharter.summary.quorum', label: 'Summary — quorum', multiline: true },
      { key: 'votingCharter.program.heading', label: 'Guide — heading' },
      { key: 'votingCharter.program.intro', label: 'Guide — intro', multiline: true },
      { key: 'votingCharter.program.s1.title', label: 'Step 1 — seats (title)' },
      { key: 'votingCharter.program.s1.detail', label: 'Step 1 — seats (detail)', multiline: true },
      { key: 'votingCharter.committee.p1', label: 'Step 1 — bye-law: committee size', multiline: true },
      { key: 'votingCharter.committee.p2', label: 'Step 1 — bye-law: no auto 2nd/3rd', multiline: true },
      { key: 'votingCharter.program.s2.title', label: 'Step 2 — eligibility (title)' },
      { key: 'votingCharter.program.s2.detail', label: 'Step 2 — eligibility (detail)', multiline: true },
      { key: 'votingCharter.eligibility.p1', label: 'Step 2 — one vote', multiline: true },
      { key: 'votingCharter.eligibility.p2', label: 'Step 2 — joint owners', multiline: true },
      { key: 'votingCharter.eligibility.p3', label: 'Step 2 — arrears >60 days', multiline: true },
      { key: 'votingCharter.eligibility.p4', label: 'Step 2 — proxy', multiline: true },
      { key: 'votingCharter.program.s3.title', label: 'Step 3 — nomination (title)' },
      { key: 'votingCharter.program.s3.detail', label: 'Step 3 — nomination (detail)', multiline: true },
      { key: 'votingCharter.nomination.p1', label: 'Step 3 — self-nominate', multiline: true },
      { key: 'votingCharter.nomination.p2', label: 'Step 3 — statement / re-election', multiline: true },
      { key: 'votingCharter.nomination.p3', label: 'Step 3 — nomination window', multiline: true },
      { key: 'votingCharter.program.s4.title', label: 'Step 4 — quorum & vote (title)' },
      { key: 'votingCharter.program.s4.detail', label: 'Step 4 — quorum & vote (detail)', multiline: true },
      { key: 'votingCharter.method.p1', label: 'Step 4 — ballot method', multiline: true },
      { key: 'votingCharter.method.p2', label: 'Step 4 — one vote / per-office', multiline: true },
      { key: 'votingCharter.method.p3', label: 'Step 4 — immutable votes', multiline: true },
      { key: 'votingCharter.method.p4', label: 'Step 4 — voting window + quorum', multiline: true },
      { key: 'votingCharter.program.s5.title', label: 'Step 5 — results (title)' },
      { key: 'votingCharter.program.s5.detail', label: 'Step 5 — results (detail)', multiline: true },
      { key: 'votingCharter.docs.p2', label: 'Step 5 — report & minutes', multiline: true },
      { key: 'votingCharter.committee.p3', label: 'Step 5 — vacancy / removal', multiline: true },
      { key: 'votingCharter.program.s6.title', label: 'Step 6 — publish & first meeting (title)' },
      { key: 'votingCharter.program.s6.detail', label: 'Step 6 — publish & first meeting (detail)', multiline: true },
      { key: 'votingCharter.docs.p1', label: 'Step 6 — attached documents', multiline: true },
      { key: 'votingCharter.docs.p3', label: 'Step 6 — publish roster', multiline: true },
      { key: 'votingCharter.committee.p4', label: 'Step 6 — first meeting / MC quorum', multiline: true },
      { key: 'votingCharter.docs.p4', label: 'Step 6 — share charter PDF', multiline: true },
      { key: 'votingCharter.download', label: 'Download button label' },
      { key: 'votingCharter.shareWhatsApp', label: 'WhatsApp share button label' },
      { key: 'votingCharter.shareMessage', label: 'WhatsApp share message', multiline: true },
    ],
  },
  {
    id: 'finance_member',
    title: 'Finance (member-facing notices)',
    description: 'Receipt / duplicate messages members and admins see in Finance and Audit.',
    fields: [
      { key: 'finance.receiptHead', label: 'Receipt head (generic label)' },
      { key: 'finance.allReceiptHeads', label: 'All receipt heads' },
      { key: 'finance.noDuplicateTitle', label: 'No duplicate receipt-head — title' },
      { key: 'finance.noDuplicateBody', label: 'No duplicate receipt-head — body', multiline: true },
      { key: 'finance.duplicateDetectedTitle', label: 'Duplicates detected — title' },
      { key: 'finance.duplicateDetectedBody', label: 'Duplicates detected — body', multiline: true },
      { key: 'finance.findReceiptHeadTitle', label: 'Find recorded receipt head — title' },
      { key: 'finance.findReceiptHeadHint', label: 'Find recorded receipt head — hint', multiline: true },
      { key: 'finance.receiptAlreadyRecorded', label: 'Receipt already recorded (short)', multiline: true },
      {
        key: 'finance.receiptAlreadyRecordedDetail',
        label: 'Receipt already recorded (detail; use {flat}, {month}, {head})',
        multiline: true,
      },
    ],
  },
];

export const ALL_EDITABLE_CONTENT_KEYS: string[] = CONTENT_TRANSLATION_GROUPS.flatMap((g) =>
  g.fields.map((f) => f.key),
);

export type ContentOverrideMap = Record<string, Record<Lang, string>>;

export function applyVars(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (_, name: string) =>
    vars[name] !== undefined && vars[name] !== null ? String(vars[name]) : `{${name}}`,
  );
}
