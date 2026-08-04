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
    title: 'Voting Charter',
    description:
      'Step-by-step election program and rules shown to members on Polls & Elections. Includes committee formation (2nd/3rd place, min 15). Editable in Hindi/English; downloadable as PDF.',
    fields: [
      { key: 'votingCharter.title', label: 'Title' },
      { key: 'votingCharter.program.heading', label: 'Program — heading' },
      { key: 'votingCharter.program.intro', label: 'Program — intro', multiline: true },
      { key: 'votingCharter.program.s1.title', label: 'Program step 1 — title' },
      { key: 'votingCharter.program.s1.detail', label: 'Program step 1 — detail', multiline: true },
      { key: 'votingCharter.program.s2.title', label: 'Program step 2 — title' },
      { key: 'votingCharter.program.s2.detail', label: 'Program step 2 — detail', multiline: true },
      { key: 'votingCharter.program.s3.title', label: 'Program step 3 — title' },
      { key: 'votingCharter.program.s3.detail', label: 'Program step 3 — detail', multiline: true },
      { key: 'votingCharter.program.s4.title', label: 'Program step 4 — title' },
      { key: 'votingCharter.program.s4.detail', label: 'Program step 4 — detail', multiline: true },
      { key: 'votingCharter.program.s5.title', label: 'Program step 5 — title' },
      { key: 'votingCharter.program.s5.detail', label: 'Program step 5 — detail', multiline: true },
      { key: 'votingCharter.program.s6.title', label: 'Program step 6 — title' },
      { key: 'votingCharter.program.s6.detail', label: 'Program step 6 — detail', multiline: true },
      { key: 'votingCharter.program.s7.title', label: 'Program step 7 — title' },
      { key: 'votingCharter.program.s7.detail', label: 'Program step 7 — detail', multiline: true },
      { key: 'votingCharter.program.s8.title', label: 'Program step 8 — title' },
      { key: 'votingCharter.program.s8.detail', label: 'Program step 8 — detail', multiline: true },
      { key: 'votingCharter.eligibility.heading', label: 'Eligibility — heading' },
      { key: 'votingCharter.eligibility.p1', label: 'Eligibility — point 1', multiline: true },
      { key: 'votingCharter.eligibility.p2', label: 'Eligibility — point 2', multiline: true },
      { key: 'votingCharter.eligibility.p3', label: 'Eligibility — point 3', multiline: true },
      { key: 'votingCharter.nomination.heading', label: 'Nomination — heading' },
      { key: 'votingCharter.nomination.p1', label: 'Nomination — point 1', multiline: true },
      { key: 'votingCharter.nomination.p2', label: 'Nomination — point 2', multiline: true },
      { key: 'votingCharter.nomination.p3', label: 'Nomination — point 3', multiline: true },
      { key: 'votingCharter.method.heading', label: 'Voting method — heading' },
      { key: 'votingCharter.method.p1', label: 'Voting method — point 1', multiline: true },
      { key: 'votingCharter.method.p2', label: 'Voting method — point 2', multiline: true },
      { key: 'votingCharter.method.p3', label: 'Voting method — point 3', multiline: true },
      { key: 'votingCharter.method.p4', label: 'Voting method — point 4', multiline: true },
      { key: 'votingCharter.method.p5', label: 'Voting method — point 5', multiline: true },
      { key: 'votingCharter.committee.heading', label: 'Committee formation — heading' },
      { key: 'votingCharter.committee.p1', label: 'Committee formation — point 1', multiline: true },
      { key: 'votingCharter.committee.p2', label: 'Committee formation — point 2', multiline: true },
      { key: 'votingCharter.committee.p3', label: 'Committee formation — point 3', multiline: true },
      { key: 'votingCharter.committee.p4', label: 'Committee formation — point 4', multiline: true },
      { key: 'votingCharter.committee.p5', label: 'Committee formation — point 5', multiline: true },
      { key: 'votingCharter.docs.heading', label: 'Documents & results — heading' },
      { key: 'votingCharter.docs.p1', label: 'Documents & results — point 1', multiline: true },
      { key: 'votingCharter.docs.p2', label: 'Documents & results — point 2', multiline: true },
      { key: 'votingCharter.docs.p3', label: 'Documents & results — point 3', multiline: true },
      { key: 'votingCharter.docs.p4', label: 'Documents & results — point 4', multiline: true },
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
