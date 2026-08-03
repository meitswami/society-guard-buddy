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
    description: 'Shown to members at the top of Polls & Elections. Edit Hindi/English for your society.',
    fields: [
      { key: 'votingCharter.title', label: 'Title' },
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
      { key: 'votingCharter.docs.heading', label: 'Documents & results — heading' },
      { key: 'votingCharter.docs.p1', label: 'Documents & results — point 1', multiline: true },
      { key: 'votingCharter.docs.p2', label: 'Documents & results — point 2', multiline: true },
      { key: 'votingCharter.docs.p3', label: 'Documents & results — point 3', multiline: true },
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
