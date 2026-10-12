import 'flat_layout.dart';
import 'js_compat.dart';

/// Web `TriState` (`'' | 'yes' | 'no'`) for optional yes/no society facts.
enum TriState { unset, yes, no }

TriState boolToTri(bool? v) =>
    v == null ? TriState.unset : (v ? TriState.yes : TriState.no);

bool? triToBool(TriState v) => v == TriState.unset ? null : v == TriState.yes;

/// Web `letterhead_mode` values.
const List<String> kLetterheadModes = ['auto', 'image', 'stationery'];

const int kMaxSocietyPhotos = 12;
const int kMaxSocietyPhotoBytes = 8 * 1024 * 1024;
const int kMaxLogoBytes = 2 * 1024 * 1024;
const int kMaxLetterheadBytes = kMaxLogoBytes * 2;

/// Web `SocietyFormState` (all text fields kept as typed strings).
class SocietyFormData {
  SocietyFormData({
    this.name = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.contactPerson = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.logoUrl = '',
    this.letterheadUrl = '',
    this.letterheadMode = 'auto',
    this.letterheadTopMm = '40',
    this.letterheadBottomMm = '18',
    this.totalFlats = '',
    this.totalFloors = '',
    this.blocksCsv = '',
    this.terrace = TriState.unset,
    this.basement = TriState.unset,
    this.basementUsable = TriState.unset,
    this.flatsPerFloor = '',
    this.flatSeriesFrom = '',
    this.flatSeriesTo = '',
    List<String>? existingPhotoUrls,
  }) : existingPhotoUrls = existingPhotoUrls ?? <String>[];

  String name;
  String address;
  String city;
  String state;
  String pincode;
  String contactPerson;
  String contactEmail;
  String contactPhone;
  String logoUrl;
  String letterheadUrl;
  String letterheadMode;
  String letterheadTopMm;
  String letterheadBottomMm;
  String totalFlats;
  String totalFloors;
  String blocksCsv;
  TriState terrace;
  TriState basement;
  TriState basementUsable;
  String flatsPerFloor;
  String flatSeriesFrom;
  String flatSeriesTo;
  List<String> existingPhotoUrls;
}

/// Fields of a `societies` row the form reads (see `SocietyRow.toFormSource`).
class SocietyFormSource {
  const SocietyFormSource({
    required this.name,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.contactPerson,
    this.contactEmail,
    this.contactPhone,
    this.logoUrl,
    this.letterheadUrl,
    this.letterheadMode,
    this.letterheadTopMm,
    this.letterheadBottomMm,
    this.totalFlats,
    this.totalFloors,
    this.blockNames,
    this.terraceAccessible,
    this.hasBasement,
    this.basementUsableForResidents,
    this.flatsPerFloor,
    this.flatSeriesStart,
    this.flatSeriesEnd,
    this.photoUrls,
  });

  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPerson;
  final String? contactEmail;
  final String? contactPhone;
  final String? logoUrl;
  final String? letterheadUrl;
  final String? letterheadMode;
  final num? letterheadTopMm;
  final num? letterheadBottomMm;
  final int? totalFlats;
  final int? totalFloors;
  final List<String>? blockNames;
  final bool? terraceAccessible;
  final bool? hasBasement;
  final bool? basementUsableForResidents;
  final int? flatsPerFloor;
  final String? flatSeriesStart;
  final String? flatSeriesEnd;
  final List<String>? photoUrls;
}

String _numText(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// Web `emptySocietyForm()`.
SocietyFormData emptySocietyForm() => SocietyFormData();

/// Web `societyToForm(s)`.
SocietyFormData societyToForm(SocietyFormSource s) => SocietyFormData(
      name: s.name,
      address: s.address ?? '',
      city: s.city ?? '',
      state: s.state ?? '',
      pincode: s.pincode ?? '',
      contactPerson: s.contactPerson ?? '',
      contactEmail: s.contactEmail ?? '',
      contactPhone: s.contactPhone ?? '',
      logoUrl: s.logoUrl ?? '',
      letterheadUrl: s.letterheadUrl ?? '',
      letterheadMode:
          s.letterheadMode == 'image' || s.letterheadMode == 'stationery'
              ? s.letterheadMode!
              : 'auto',
      letterheadTopMm:
          s.letterheadTopMm != null ? _numText(s.letterheadTopMm!) : '40',
      letterheadBottomMm:
          s.letterheadBottomMm != null ? _numText(s.letterheadBottomMm!) : '18',
      totalFlats: s.totalFlats != null ? '${s.totalFlats}' : '',
      totalFloors: s.totalFloors != null ? '${s.totalFloors}' : '',
      blocksCsv: (s.blockNames ?? const []).join(', '),
      terrace: boolToTri(s.terraceAccessible),
      basement: boolToTri(s.hasBasement),
      basementUsable: boolToTri(s.basementUsableForResidents),
      flatsPerFloor: s.flatsPerFloor != null ? '${s.flatsPerFloor}' : '',
      flatSeriesFrom: s.flatSeriesStart ?? '',
      flatSeriesTo: s.flatSeriesEnd ?? '',
      existingPhotoUrls: [...?s.photoUrls],
    );

/// Web `parseIntOrNull` inside `saveSociety`.
int? parseIntOrNull(String v) {
  final trimmed = v.trim();
  if (trimmed.isEmpty) return null;
  return jsParseInt(trimmed);
}

String? _blankToNull(String v) {
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Web `block_names` (`null` when no block was typed).
List<String>? blockNamesFromCsv(String csv) {
  final parts = splitBlocksCsv(csv);
  return parts.isEmpty ? null : parts;
}

num _mmOr(String raw, num fallback) {
  final v = jsNumber(raw);
  return v.isFinite && v > 0 ? jsonNumber(v) : fallback;
}

/// Web `baseRow` built by `saveSociety` (everything except `photo_urls`).
Map<String, dynamic> buildSocietyBaseRow(SocietyFormData sf) {
  final hasBasement = sf.basement == TriState.yes;
  return {
    'name': sf.name.trim(),
    'address': _blankToNull(sf.address),
    'city': _blankToNull(sf.city),
    'state': _blankToNull(sf.state),
    'pincode': _blankToNull(sf.pincode),
    'contact_person': _blankToNull(sf.contactPerson),
    'contact_email': _blankToNull(sf.contactEmail),
    'contact_phone': _blankToNull(sf.contactPhone),
    'logo_url': _blankToNull(sf.logoUrl),
    'letterhead_url': _blankToNull(sf.letterheadUrl),
    'letterhead_mode': sf.letterheadMode,
    'letterhead_top_mm': _mmOr(sf.letterheadTopMm, 40),
    'letterhead_bottom_mm': _mmOr(sf.letterheadBottomMm, 18),
    'total_flats': parseIntOrNull(sf.totalFlats),
    'total_floors': parseIntOrNull(sf.totalFloors),
    'block_names': blockNamesFromCsv(sf.blocksCsv),
    'terrace_accessible': triToBool(sf.terrace),
    'has_basement': triToBool(sf.basement),
    'basement_usable_for_residents':
        hasBasement ? triToBool(sf.basementUsable) : null,
    'flats_per_floor': parseIntOrNull(sf.flatsPerFloor),
    'flat_series_start': _blankToNull(sf.flatSeriesFrom),
    'flat_series_end': _blankToNull(sf.flatSeriesTo),
  };
}

/// Layout passed to trim / generate after saving (and for "Reset flats").
SocietyLayoutInput layoutFromForm(SocietyFormData sf) => SocietyLayoutInput(
      totalFloors: parseIntOrNull(sf.totalFloors),
      flatSeriesStart: _blankToNull(sf.flatSeriesFrom),
      flatSeriesEnd: _blankToNull(sf.flatSeriesTo),
      blockNames: blockNamesFromCsv(sf.blocksCsv),
    );

/// Web `[address, city, state].filter(Boolean).join(', ')`.
String societyAddressLine({String? address, String? city, String? state}) =>
    [address, city, state].where((x) => x != null && x.isNotEmpty).join(', ');

/// Port of `makeReferralCode(name, societyId)` from `supabase/functions/phonepe-callback`.
String makeReferralCode(String name, String societyId) {
  final words = name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]+'), '')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p.length > 4 ? p.substring(0, 4) : p)
      .join();
  final letters = words.length > 6 ? words.substring(0, 6) : words;
  final compact = societyId.replaceAll('-', '');
  final suffix =
      (compact.length > 6 ? compact.substring(0, 6) : compact).toUpperCase();
  return '${letters.isEmpty ? 'SOC' : letters}-$suffix';
}
