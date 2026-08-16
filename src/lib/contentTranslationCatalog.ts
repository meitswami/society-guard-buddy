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
