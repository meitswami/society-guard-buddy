import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/supabase/db.dart';
import 'pdf_page.dart';

/// Society branding used for official report PDFs — port of the data side of
/// `src/lib/pdfLetterhead.ts`. Strictly scoped to one society id.

enum LetterheadMode {
  auto,
  image,
  stationery;

  static LetterheadMode? parse(Object? raw) => switch (raw?.toString()) {
        'auto' => LetterheadMode.auto,
        'image' => LetterheadMode.image,
        'stationery' => LetterheadMode.stationery,
        _ => null,
      };
}

/// User-facing PDF style: official society letterhead vs plain.
enum ReportPdfMode {
  letterhead,
  plain;

  String get dbValue => name;

  static ReportPdfMode parse(Object? raw) => raw?.toString() == 'plain' ? ReportPdfMode.plain : ReportPdfMode.letterhead;
}

class SocietyReportSettings {
  const SocietyReportSettings({this.defaultReportFormat = ReportPdfMode.letterhead});

  final ReportPdfMode defaultReportFormat;
}

/// Letterhead details for one society. `logoBytes` / `letterheadBytes` are the
/// preloaded images (web `logoDataUrl` / `letterheadDataUrl`).
@immutable
class SocietyLetterhead {
  const SocietyLetterhead({
    required this.name,
    this.societyId,
    this.logoUrl,
    this.letterheadUrl,
    this.letterheadStoragePath,
    this.letterheadMode,
    this.letterheadTopMm,
    this.letterheadBottomMm,
    this.letterheadLeftMm,
    this.letterheadRightMm,
    this.defaultReportFormat,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.contactPhone,
    this.contactEmail,
    this.logoBytes,
    this.letterheadBytes,
  });

  final String name;
  final String? societyId;
  final String? logoUrl;
  final String? letterheadUrl;
  final String? letterheadStoragePath;
  final LetterheadMode? letterheadMode;
  final double? letterheadTopMm;
  final double? letterheadBottomMm;
  final double? letterheadLeftMm;
  final double? letterheadRightMm;
  final ReportPdfMode? defaultReportFormat;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPhone;
  final String? contactEmail;
  final Uint8List? logoBytes;
  final Uint8List? letterheadBytes;

  /// `fromNameOnly` — auto letterhead band with just the society name.
  factory SocietyLetterhead.nameOnly([String? name]) {
    final n = name?.trim() ?? '';
    return SocietyLetterhead(
      name: n.isEmpty ? 'Society' : n,
      letterheadMode: LetterheadMode.auto,
      defaultReportFormat: ReportPdfMode.letterhead,
    );
  }

  /// `coerceLetterhead(info)` — accepts a [SocietyLetterhead], a society name or null.
  static SocietyLetterhead coerce(Object? info) {
    if (info is SocietyLetterhead) return info;
    if (info is String) return SocietyLetterhead.nameOnly(info);
    return SocietyLetterhead.nameOnly();
  }

  /// `normalizeSocietyRow` from a `societies` row.
  factory SocietyLetterhead.fromSocietyRow(Map<String, dynamic> data) {
    double num(Object? v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? double.nan;
    }

    String? s(Object? v) => v?.toString();
    final nameRaw = (data['name'] ?? '').toString();
    return SocietyLetterhead(
      societyId: s(data['id']),
      name: nameRaw.isEmpty ? 'Society' : nameRaw,
      logoUrl: s(data['logo_url']),
      letterheadUrl: s(data['letterhead_url']),
      letterheadStoragePath: s(data['letterhead_storage_path']),
      // DB null → 'auto'; an unknown value stays null so [brandMode] infers it (web `modeOf`).
      letterheadMode: data['letterhead_mode'] == null ? LetterheadMode.auto : LetterheadMode.parse(data['letterhead_mode']),
      letterheadTopMm: num(data['letterhead_top_mm'], 40),
      letterheadBottomMm: num(data['letterhead_bottom_mm'], 18),
      letterheadLeftMm: num(data['letterhead_left_mm'], kPdfMarginMm),
      letterheadRightMm: num(data['letterhead_right_mm'], kPdfMarginMm),
      defaultReportFormat: ReportPdfMode.parse(data['default_report_format'] ?? 'letterhead'),
      address: s(data['address']),
      city: s(data['city']),
      state: s(data['state']),
      pincode: s(data['pincode']),
      contactPhone: s(data['contact_phone']),
      contactEmail: s(data['contact_email']),
    );
  }

  SocietyLetterhead copyWith({
    String? name,
    String? societyId,
    String? letterheadUrl,
    LetterheadMode? letterheadMode,
    Uint8List? logoBytes,
    Uint8List? letterheadBytes,
    bool clearLogoBytes = false,
    bool clearLetterheadBytes = false,
  }) =>
      SocietyLetterhead(
        name: name ?? this.name,
        societyId: societyId ?? this.societyId,
        logoUrl: logoUrl,
        letterheadUrl: letterheadUrl ?? this.letterheadUrl,
        letterheadStoragePath: letterheadStoragePath,
        letterheadMode: letterheadMode ?? this.letterheadMode,
        letterheadTopMm: letterheadTopMm,
        letterheadBottomMm: letterheadBottomMm,
        letterheadLeftMm: letterheadLeftMm,
        letterheadRightMm: letterheadRightMm,
        defaultReportFormat: defaultReportFormat,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        logoBytes: clearLogoBytes ? null : (logoBytes ?? this.logoBytes),
        letterheadBytes: clearLetterheadBytes ? null : (letterheadBytes ?? this.letterheadBytes),
      );

  bool _has(String? v) => v != null && v.isNotEmpty;

  /// Uploaded official letterhead asset present (`hasOfficialLetterheadAsset`).
  bool get hasOfficialAsset =>
      (letterheadBytes != null && letterheadBytes!.isNotEmpty) || _has(letterheadUrl) || _has(letterheadStoragePath);

  bool get hasLogo => (logoBytes != null && logoBytes!.isNotEmpty) || _has(logoUrl);

  /// Effective mode (`modeOf`): explicit mode, else image when an asset exists.
  LetterheadMode get brandMode {
    final m = letterheadMode;
    if (m != null) return m;
    return hasOfficialAsset ? LetterheadMode.image : LetterheadMode.auto;
  }
}

/// `Address · City, State · Pincode`.
String letterheadAddressLine(SocietyLetterhead info) {
  final cityState = [info.city, info.state].where((p) => (p ?? '').isNotEmpty).join(', ');
  final parts = [info.address, cityState, info.pincode].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty);
  return parts.join(' · ');
}

/// `Phone · Email`.
String letterheadContactLine(SocietyLetterhead info) =>
    [info.contactPhone, info.contactEmail].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');

/// Whether this society has an uploaded official letterhead (or uses stationery).
bool societyHasOfficialLetterhead(SocietyLetterhead? info) {
  if (info == null) return false;
  return info.hasOfficialAsset || info.letterheadMode == LetterheadMode.stationery;
}

const String _fullSelect =
    'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
const String _fallbackSelect =
    'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';

/// Load a remote image (best-effort). PDF stationery is skipped like the web
/// (a raster background needs a PNG/JPG upload).
Future<Uint8List?> fetchImageBytes(String? url) async {
  final u = url?.trim() ?? '';
  if (u.isEmpty) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(Uri.parse(u)).timeout(const Duration(seconds: 20));
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('[letterhead] image fetch failed $u ${res.statusCode}');
      return null;
    }
    final type = res.headers.contentType?.mimeType ?? '';
    if (type == 'application/pdf' || u.toLowerCase().contains('.pdf')) {
      debugPrint('[letterhead] PDF letterhead cannot be embedded as image background; upload a PNG/JPG scan');
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 30))) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (e) {
    debugPrint('[letterhead] image fetch error $u $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<String?> _signedUrlForStoragePath(String? path) async {
  final p = path?.trim() ?? '';
  if (p.isEmpty) return null;
  try {
    return await db.storage.from('society-documents').createSignedUrl(p, 3600);
  } catch (e) {
    debugPrint('[letterhead] signed URL failed $p $e');
    return null;
  }
}

/// Preload logo / letterhead images (`resolveLetterheadAssets`).
Future<SocietyLetterhead> resolveLetterheadAssets(SocietyLetterhead info) async {
  var letterheadUrl = info.letterheadUrl;
  if ((letterheadUrl == null || letterheadUrl.isEmpty) &&
      info.letterheadStoragePath != null &&
      info.letterheadStoragePath!.isNotEmpty) {
    letterheadUrl = await _signedUrlForStoragePath(info.letterheadStoragePath);
  }
  final results = await Future.wait<Uint8List?>([
    info.logoBytes != null ? Future.value(info.logoBytes) : fetchImageBytes(info.logoUrl),
    info.letterheadBytes != null ? Future.value(info.letterheadBytes) : fetchImageBytes(letterheadUrl),
  ]);
  return info.copyWith(letterheadUrl: letterheadUrl, logoBytes: results[0], letterheadBytes: results[1]);
}

/// Fetch the current society's letterhead (never another society's).
Future<SocietyLetterhead?> fetchSocietyLetterhead(String? societyId, {bool loadAssets = true}) async {
  if (societyId == null || societyId.isEmpty || !dbReady) return null;
  Map<String, dynamic>? data;
  try {
    data = await db.from('societies').select(_fullSelect).eq('id', societyId).maybeSingle();
    if (data == null) return null;
  } catch (e) {
    debugPrint('[letterhead] primary select failed, trying fallback columns $e');
    try {
      data = await db.from('societies').select(_fallbackSelect).eq('id', societyId).maybeSingle();
    } catch (e2) {
      debugPrint('[letterhead] fallback select failed $e2');
      return null;
    }
    if (data == null) return null;
  }
  final row = SocietyLetterhead.fromSocietyRow(data);
  // Hard multi-society guard: only assets belonging to this society id.
  if (row.societyId != null && row.societyId!.isNotEmpty && row.societyId != societyId) {
    debugPrint('[letterhead] society id mismatch — refusing letterhead');
    return null;
  }
  final scoped = row.copyWith(societyId: societyId);
  return loadAssets ? resolveLetterheadAssets(scoped) : scoped;
}
