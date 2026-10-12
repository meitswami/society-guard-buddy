import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/supabase/db.dart';
import 'gov_backend.dart';

/// Society branding used on the voting charter (subset of web `pdfLetterhead.ts`).
class GovLetterhead {
  const GovLetterhead({
    required this.name,
    this.mode = 'auto',
    this.logoUrl,
    this.letterheadUrl,
    this.letterheadStoragePath,
    this.topMm = 40,
    this.bottomMm = 18,
    this.leftMm = 19.05,
    this.rightMm = 19.05,
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

  /// `auto` | `image` | `stationery`
  final String mode;
  final String? logoUrl;
  final String? letterheadUrl;
  final String? letterheadStoragePath;
  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPhone;
  final String? contactEmail;
  final Uint8List? logoBytes;
  final Uint8List? letterheadBytes;

  /// Web `letterheadAddressLine`.
  String get addressLine {
    final parts = [address, [city, state].where((s) => (s ?? '').trim().isNotEmpty).join(', '), pincode]
        .map((p) => (p ?? '').trim())
        .where((p) => p.isNotEmpty);
    return parts.join(' · ');
  }

  /// Web `letterheadContactLine`.
  String get contactLine => [contactPhone, contactEmail].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');

  /// Full-page uploaded letterhead image is available.
  bool get hasPageImage => mode == 'image' && letterheadBytes != null;

  static double _mm(Object? v, double fallback, {double? min}) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null || !n.isFinite || n <= 0) return fallback;
    return min != null && n < min ? min : n;
  }

  static Future<Uint8List?> _fetch(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(res);
      client.close();
      final ct = res.headers.contentType?.mimeType ?? '';
      if (ct == 'application/pdf' || url.toLowerCase().contains('.pdf')) return null;
      return bytes;
    } catch (e) {
      debugPrint('[letterhead] image fetch failed $url: $e');
      return null;
    }
  }

  /// Web `fetchSocietyLetterhead` + `resolveLetterheadAssets`.
  static Future<GovLetterhead?> fetch(String societyId) async {
    if (!dbReady) return null;
    const full =
        'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
    const fallback =
        'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';
    Map<String, dynamic>? row;
    try {
      row = await db.from('societies').select(full).eq('id', societyId).maybeSingle();
    } catch (_) {
      try {
        row = await db.from('societies').select(fallback).eq('id', societyId).maybeSingle();
      } catch (e) {
        debugPrint('[letterhead] fetch failed: $e');
        return null;
      }
    }
    if (row == null || (row['id'] != null && '${row['id']}' != societyId)) return null;
    String? s(String k) => row![k] as String?;
    var letterheadUrl = s('letterhead_url');
    final storagePath = s('letterhead_storage_path');
    if ((letterheadUrl == null || letterheadUrl.isEmpty) && storagePath != null && storagePath.isNotEmpty) {
      try {
        letterheadUrl = await db.storage.from(GovBackend.societyDocumentsBucket).createSignedUrl(storagePath, 3600);
      } catch (_) {}
    }
    final rawMode = s('letterhead_mode');
    final mode = (rawMode == 'image' || rawMode == 'stationery' || rawMode == 'auto')
        ? rawMode!
        : ((letterheadUrl ?? '').isNotEmpty || (storagePath ?? '').isNotEmpty ? 'image' : 'auto');
    final results = await Future.wait([_fetch(s('logo_url')), _fetch(letterheadUrl)]);
    return GovLetterhead(
      name: ((row['name'] ?? '') as String).trim().isEmpty ? 'Society' : (row['name'] as String).trim(),
      // The charter always shows branding: stationery falls back to the digital band.
      mode: mode == 'image' ? 'image' : 'auto',
      logoUrl: s('logo_url'),
      letterheadUrl: letterheadUrl,
      letterheadStoragePath: storagePath,
      topMm: _mm(row['letterhead_top_mm'], 40),
      bottomMm: _mm(row['letterhead_bottom_mm'], 18, min: 16),
      leftMm: _mm(row['letterhead_left_mm'], 19.05),
      rightMm: _mm(row['letterhead_right_mm'], 19.05),
      address: s('address'),
      city: s('city'),
      state: s('state'),
      pincode: s('pincode'),
      contactPhone: s('contact_phone'),
      contactEmail: s('contact_email'),
      logoBytes: results[0],
      letterheadBytes: results[1],
    );
  }
}
