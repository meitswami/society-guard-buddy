/// Port of `src/lib/contentTranslationCatalog.ts` + the draft / save rules of
/// `SocietyContentEditor.tsx`. Pure Dart (unit-tested).
library;

/// One editable translation key (web `ContentTranslationField`). The web labels are English
/// only; [labelHi] is the Hindi label shown when the app language is Hindi.
class ContentTranslationField {
  const ContentTranslationField(this.key, this.labelEn, this.labelHi,
      {this.multiline = false});

  final String key;
  final String labelEn;
  final String labelHi;
  final bool multiline;
}

class ContentTranslationGroup {
  const ContentTranslationGroup({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.fields,
  });

  final String id;
  final String titleEn;
  final String titleHi;
  final String descriptionEn;
  final String descriptionHi;
  final List<ContentTranslationField> fields;
}

/// Keys admins may customise per society for member-facing display.
const List<ContentTranslationGroup> kContentTranslationGroups = [
  ContentTranslationGroup(
    id: 'finance_member',
    titleEn: 'Finance (member-facing notices)',
    titleHi: 'वित्त (सदस्यों को दिखने वाली सूचनाएँ)',
    descriptionEn:
        'Receipt / duplicate messages members and admins see in Finance and Audit.',
    descriptionHi:
        'रसीद / डुप्लिकेट संदेश जो सदस्य और प्रशासक वित्त तथा लेखा-परीक्षा में देखते हैं।',
    fields: [
      ContentTranslationField('finance.receiptHead',
          'Receipt head (generic label)', 'रसीद शीर्ष (सामान्य नाम)'),
      ContentTranslationField(
          'finance.allReceiptHeads', 'All receipt heads', 'सभी रसीद शीर्ष'),
      ContentTranslationField(
          'finance.noDuplicateTitle',
          'No duplicate receipt-head — title',
          'कोई डुप्लिकेट रसीद-शीर्ष नहीं — शीर्षक'),
      ContentTranslationField(
          'finance.noDuplicateBody',
          'No duplicate receipt-head — body',
          'कोई डुप्लिकेट रसीद-शीर्ष नहीं — विवरण',
          multiline: true),
      ContentTranslationField('finance.duplicateDetectedTitle',
          'Duplicates detected — title', 'डुप्लिकेट मिले — शीर्षक'),
      ContentTranslationField('finance.duplicateDetectedBody',
          'Duplicates detected — body', 'डुप्लिकेट मिले — विवरण',
          multiline: true),
      ContentTranslationField(
          'finance.findReceiptHeadTitle',
          'Find recorded receipt head — title',
          'दर्ज रसीद शीर्ष खोजें — शीर्षक'),
      ContentTranslationField('finance.findReceiptHeadHint',
          'Find recorded receipt head — hint', 'दर्ज रसीद शीर्ष खोजें — संकेत',
          multiline: true),
      ContentTranslationField('finance.receiptAlreadyRecorded',
          'Receipt already recorded (short)', 'रसीद पहले से दर्ज (संक्षिप्त)',
          multiline: true),
      ContentTranslationField(
        'finance.receiptAlreadyRecordedDetail',
        'Receipt already recorded (detail; use {flat}, {month}, {head})',
        'रसीद पहले से दर्ज (विस्तार; {flat}, {month}, {head} का उपयोग करें)',
        multiline: true,
      ),
    ],
  ),
];

/// Web `ALL_EDITABLE_CONTENT_KEYS`.
final List<String> kAllEditableContentKeys = [
  for (final g in kContentTranslationGroups)
    for (final f in g.fields) f.key,
];

/// Web `applyVars` in the catalog: `{name}` → value; unknown / null vars stay as `{name}`.
String applyContentVars(String template, [Map<String, Object?>? vars]) {
  if (vars == null) return template;
  return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final v = vars[m.group(1)];
    return v == null ? '{${m.group(1)}}' : '$v';
  });
}

/// English / Hindi pair being edited.
class ContentDraft {
  const ContentDraft({required this.en, required this.hi});

  final String en;
  final String hi;

  ContentDraft copyWith({String? en, String? hi}) =>
      ContentDraft(en: en ?? this.en, hi: hi ?? this.hi);

  @override
  bool operator ==(Object other) =>
      other is ContentDraft && other.en == en && other.hi == hi;

  @override
  int get hashCode => Object.hash(en, hi);

  @override
  String toString() => 'ContentDraft(en: $en, hi: $hi)';
}

/// Web `load()`: every editable key starts from the app default, then saved society rows
/// (only for editable keys) replace it.
Map<String, ContentDraft> mergeContentDrafts({
  required List<String> keys,
  required ContentDraft Function(String key) defaultsFor,
  required List<Map<String, dynamic>> savedRows,
}) {
  final map = <String, ContentDraft>{for (final k in keys) k: defaultsFor(k)};
  for (final row in savedRows) {
    final key = row['content_key']?.toString() ?? '';
    if (!keys.contains(key)) continue;
    map[key] = ContentDraft(
        en: row['text_en']?.toString() ?? '',
        hi: row['text_hi']?.toString() ?? '');
  }
  return map;
}

/// Web `save()`: one upsert row per editable key, trimmed, `updated_by: 'admin'`.
List<Map<String, dynamic>> buildContentUpsertRows({
  required String societyId,
  required List<String> keys,
  required Map<String, ContentDraft> drafts,
  required ContentDraft Function(String key) defaultsFor,
}) {
  return [
    for (final key in keys)
      () {
        final d = drafts[key] ?? defaultsFor(key);
        return <String, dynamic>{
          'society_id': societyId,
          'content_key': key,
          'text_en': d.en.trim(),
          'text_hi': d.hi.trim(),
          'updated_by': 'admin',
        };
      }(),
  ];
}

/// "App default" hint: default in the current language, else English (web `defaultsFor(k)[lang] || .en`).
String contentDefaultHint(ContentDraft defaults, {required bool hindi}) {
  final v = hindi ? defaults.hi : defaults.en;
  return v.isNotEmpty ? v : defaults.en;
}
