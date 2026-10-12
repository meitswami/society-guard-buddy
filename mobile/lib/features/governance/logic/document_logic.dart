/// Pure helpers ported from web `SocietyDocumentsManager.tsx` and `src/lib/pollDocuments.ts`.
library;

/// `society_documents.category`.
enum SocietyDocCategory {
  bylaws('bylaws', 'Bylaws & rules', 'उपविधि एवं नियम'),
  minutes('minutes', 'Meeting minutes', 'बैठक कार्यवृत्त'),
  notices('notices', 'Notices & circulars', 'सूचनाएँ एवं परिपत्र'),
  reports('reports', 'Reports', 'प्रतिवेदन'),
  forms('forms', 'Forms', 'प्रपत्र'),
  other('other', 'Other', 'अन्य');

  const SocietyDocCategory(this.value, this.labelEn, this.labelHi);

  final String value;
  final String labelEn;
  final String labelHi;

  String label(bool hi) => hi ? labelHi : labelEn;

  static SocietyDocCategory parse(Object? raw) {
    for (final c in values) {
      if (c.value == raw) return c;
    }
    return SocietyDocCategory.other;
  }
}

/// Member clear-view windows the office can enable.
const List<({int seconds, String labelEn, String labelHi})> revealDurations = [
  (seconds: 15, labelEn: '15 sec', labelHi: '15 सेकंड'),
  (seconds: 30, labelEn: '30 sec', labelHi: '30 सेकंड'),
  (seconds: 60, labelEn: '1 min', labelHi: '1 मिनट'),
];

const List<String> societyDocAcceptedTypes = ['application/pdf', 'image/png', 'image/jpeg', 'image/webp'];

const List<String> societyDocExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

const int societyDocMaxBytes = 15 * 1024 * 1024;

bool isRevealActive(String? memberRevealUntil, DateTime now) {
  if (memberRevealUntil == null || memberRevealUntil.isEmpty) return false;
  final until = DateTime.tryParse(memberRevealUntil);
  if (until == null) return false;
  return until.millisecondsSinceEpoch > now.millisecondsSinceEpoch;
}

int revealSecondsLeft(String? memberRevealUntil, DateTime now) {
  if (memberRevealUntil == null || memberRevealUntil.isEmpty) return 0;
  final until = DateTime.tryParse(memberRevealUntil);
  if (until == null) return 0;
  final left = ((until.millisecondsSinceEpoch - now.millisecondsSinceEpoch) / 1000).ceil();
  return left < 0 ? 0 : left;
}

bool isImageDoc({String? mimeType, required String fileName}) {
  if (mimeType != null && mimeType.startsWith('image/')) return true;
  return RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(fileName);
}

/// Protected viewer content type detection (web `ProtectedDocumentViewer`).
bool viewerIsPdf({String? mimeType, required String url}) =>
    mimeType == 'application/pdf' || url.toLowerCase().contains('.pdf');

bool viewerIsImage({String? mimeType, required String url}) {
  if (mimeType != null) return mimeType.startsWith('image/');
  return RegExp(r'\.(png|jpe?g|webp|gif)(\?|$)', caseSensitive: false).hasMatch(url);
}

/// Upload validation (web `handleUpload`); returns (en, hi) or null.
(String, String)? validateSocietyDocUpload({required String title, required String? mimeType, required int size}) {
  if (title.trim().isEmpty) return ('Enter a document title', 'दस्तावेज़ का शीर्षक दर्ज करें');
  if (mimeType == null || !societyDocAcceptedTypes.contains(mimeType)) {
    return (
      'Only PDF and image files (PNG, JPEG, WebP) are allowed',
      'केवल PDF और चित्र फ़ाइलें (PNG, JPEG, WebP) अनुमत हैं',
    );
  }
  if (size > societyDocMaxBytes) return ('File must be 15 MB or smaller', 'फ़ाइल 15 MB या उससे छोटी होनी चाहिए');
  return null;
}

/// Storage key inside the private `society-documents` bucket.
String societyDocStoragePath(String societyId, String docId, String fileName) =>
    '$societyId/$docId/${fileName.replaceAll(RegExp(r'[^\w.-]'), '_')}';

/// `poll_documents.doc_kind` (web `POLL_DOC_KIND_LABELS`).
enum PollDocKind {
  circular('circular', 'Circular', 'परिपत्र'),
  letter('letter', 'Letter', 'पत्र'),
  personal('personal', 'Personal letter', 'व्यक्तिगत पत्र'),
  society('society', 'Society letter', 'सोसायटी पत्र'),
  other('other', 'Other', 'अन्य');

  const PollDocKind(this.value, this.labelEn, this.labelHi);

  final String value;
  final String labelEn;
  final String labelHi;

  String label(bool hi) => hi ? labelHi : labelEn;

  static PollDocKind? parse(Object? raw) {
    for (final k in values) {
      if (k.value == raw) return k;
    }
    return null;
  }
}

/// Label for a stored kind (falls back to the raw value like the web).
String pollDocKindLabel(String kind, {bool hi = false}) => PollDocKind.parse(kind)?.label(hi) ?? kind;

const List<String> pollDocExtensions = [
  'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif',
];
