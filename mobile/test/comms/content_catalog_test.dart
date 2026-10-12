import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/data/content_translation_catalog.dart';

void main() {
  ContentDraft defaults(String key) => ContentDraft(
      en: 'EN:$key', hi: key == 'finance.receiptHead' ? '' : 'HI:$key');

  group('catalog (web contentTranslationCatalog.ts)', () {
    test('one finance group with the 10 member-facing keys in order', () {
      expect(kContentTranslationGroups.map((g) => g.id), ['finance_member']);
      expect(kAllEditableContentKeys, [
        'finance.receiptHead',
        'finance.allReceiptHeads',
        'finance.noDuplicateTitle',
        'finance.noDuplicateBody',
        'finance.duplicateDetectedTitle',
        'finance.duplicateDetectedBody',
        'finance.findReceiptHeadTitle',
        'finance.findReceiptHeadHint',
        'finance.receiptAlreadyRecorded',
        'finance.receiptAlreadyRecordedDetail',
      ]);
    });

    test('multiline flags match the web', () {
      final multi = {
        for (final f in kContentTranslationGroups.single.fields)
          if (f.multiline) f.key,
      };
      expect(multi, {
        'finance.noDuplicateBody',
        'finance.duplicateDetectedBody',
        'finance.findReceiptHeadHint',
        'finance.receiptAlreadyRecorded',
        'finance.receiptAlreadyRecordedDetail',
      });
    });

    test('every field has an English and a Hindi label', () {
      for (final f in kContentTranslationGroups.single.fields) {
        expect(f.labelEn, isNotEmpty);
        expect(f.labelHi, isNotEmpty);
      }
    });
  });

  group('applyContentVars', () {
    test('replaces known vars and keeps unknown placeholders', () {
      expect(
        applyContentVars('Flat {flat} in {month} ({head})',
            {'flat': '101', 'month': 'Mar 2026'}),
        'Flat 101 in Mar 2026 ({head})',
      );
      expect(applyContentVars('{n} items', {'n': 0}), '0 items');
      expect(applyContentVars('{n} items', {'n': null}), '{n} items');
      expect(applyContentVars('no vars'), 'no vars');
    });
  });

  group('drafts (web SocietyContentEditor)', () {
    test('defaults first, saved rows for editable keys override', () {
      final drafts = mergeContentDrafts(
        keys: const ['finance.receiptHead', 'finance.allReceiptHeads'],
        defaultsFor: defaults,
        savedRows: const [
          {
            'content_key': 'finance.allReceiptHeads',
            'text_en': 'All heads',
            'text_hi': 'सभी शीर्ष'
          },
          {'content_key': 'not.editable', 'text_en': 'x', 'text_hi': 'y'},
        ],
      );
      expect(drafts.keys, ['finance.receiptHead', 'finance.allReceiptHeads']);
      expect(drafts['finance.receiptHead'],
          const ContentDraft(en: 'EN:finance.receiptHead', hi: ''));
      expect(drafts['finance.allReceiptHeads'],
          const ContentDraft(en: 'All heads', hi: 'सभी शीर्ष'));
    });

    test('saved rows with null text become empty strings', () {
      final drafts = mergeContentDrafts(
        keys: const ['finance.receiptHead'],
        defaultsFor: defaults,
        savedRows: const [
          {
            'content_key': 'finance.receiptHead',
            'text_en': null,
            'text_hi': null
          },
        ],
      );
      expect(drafts['finance.receiptHead'], const ContentDraft(en: '', hi: ''));
    });

    test('upsert rows: every key, trimmed, updated_by admin', () {
      final rows = buildContentUpsertRows(
        societyId: 's1',
        keys: const ['finance.receiptHead', 'finance.allReceiptHeads'],
        drafts: const {
          'finance.receiptHead': ContentDraft(en: '  Head  ', hi: ' शीर्ष ')
        },
        defaultsFor: defaults,
      );
      expect(rows, [
        {
          'society_id': 's1',
          'content_key': 'finance.receiptHead',
          'text_en': 'Head',
          'text_hi': 'शीर्ष',
          'updated_by': 'admin',
        },
        {
          'society_id': 's1',
          'content_key': 'finance.allReceiptHeads',
          'text_en': 'EN:finance.allReceiptHeads',
          'text_hi': 'HI:finance.allReceiptHeads',
          'updated_by': 'admin',
        },
      ]);
    });

    test('default hint uses the current language, else English', () {
      expect(
          contentDefaultHint(const ContentDraft(en: 'E', hi: 'H'), hindi: true),
          'H');
      expect(
          contentDefaultHint(const ContentDraft(en: 'E', hi: ''), hindi: true),
          'E');
      expect(
          contentDefaultHint(const ContentDraft(en: 'E', hi: 'H'),
              hindi: false),
          'E');
    });
  });
}
