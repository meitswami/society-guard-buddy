import 'dart:convert';

import 'package:http/http.dart' as http;

import 'smoke_schema.dart';

/// Fake Supabase backend for smoke tests: answers PostgREST, RPC, Storage, Functions and
/// Auth requests with schema-shaped rows, so every screen renders with realistic data.
///
/// All ids are `00000000-0000-0000-0000-00000000000N` (N = row number), so foreign keys
/// line up across tables (row 1's `flat_id` is flat row 1's `id`, and so on).
class FakeSupabaseBackend extends http.BaseClient {
  FakeSupabaseBackend({required this.societyId, this.rowsPerTable = 3});

  final String societyId;
  final int rowsPerTable;

  /// Every request seen: method + full URL (for assertions and debugging).
  final List<String> requests = [];

  static String uuid(int n) => '00000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final path = uri.path;
    requests.add('${request.method} ${Uri.decodeFull(uri.toString())}');
    final accept = request.headers['Accept'] ?? request.headers['accept'] ?? '';
    final wantsObject = accept.contains('vnd.pgrst.object');

    Object? body;
    var headers = <String, String>{'content-type': 'application/json'};
    if (path.startsWith('/rest/v1/rpc/')) {
      body = const [];
    } else if (path.startsWith('/rest/v1/')) {
      final table = path.substring('/rest/v1/'.length);
      var rows = _rows(table);
      // Lookups by primary key (`id=eq.x`) or `limit=1` return at most one row, as in Postgres.
      final q = uri.queryParameters;
      if ((q['id'] ?? '').startsWith('eq.') || q['limit'] == '1') rows = rows.take(1).toList();
      headers['content-range'] = '0-${rows.length - 1}/${rows.length}';
      if (request.method == 'HEAD') {
        body = null;
      } else if (request.method == 'GET') {
        body = wantsObject ? (rows.isEmpty ? null : rows.first) : rows;
      } else if (request.method == 'DELETE') {
        body = const [];
      } else {
        // POST / PATCH: echo a full row so `.select()` after insert/update has data.
        body = wantsObject ? (rows.isEmpty ? <String, dynamic>{} : rows.first) : rows.take(1).toList();
      }
    } else if (path.startsWith('/storage/v1/object/sign/')) {
      body = {'signedURL': '/object/sign/fake?token=t'};
    } else if (path.startsWith('/storage/v1/')) {
      body = {'Key': 'fake/key', 'Id': 'fake'};
    } else if (path.startsWith('/functions/v1/')) {
      body = <String, dynamic>{'ok': true};
    } else {
      body = <String, dynamic>{};
    }
    final bytes = body == null ? <int>[] : utf8.encode(jsonEncode(body));
    return http.StreamedResponse(Stream.value(bytes), 200, headers: headers, request: request);
  }

  /// A realistic number of flats, so "whole society" queries look different from
  /// per-flat or per-committee ones.
  static const _rowsFor = {'flats': 35};

  List<Map<String, dynamic>> _rows(String table) {
    final cols = kSmokeSchema[table];
    if (cols == null) return const [];
    final count = _rowsFor[table] ?? rowsPerTable;
    return [for (var n = 1; n <= count; n++) _row(table, cols, n)];
  }

  Map<String, dynamic> _row(String table, Map<String, String> cols, int n) {
    final now = DateTime.now().toUtc();
    final row = <String, dynamic>{};
    cols.forEach((c, rawType) {
      final nullable = rawType.endsWith('?');
      final type = nullable ? rawType.substring(0, rawType.length - 1) : rawType;
      // Row 2 has every nullable column null (real rows are often sparse).
      row[c] = (nullable && n == 2 && c != 'id' && c != 'society_id') ? null : _value(table, c, type, n, now);
    });
    return row;
  }

  Object? _value(String table, String c, String type, int n, DateTime now) {
    if (c == 'society_id') return societyId;
    if (c == 'id' || c.endsWith('_id')) {
      return type == 'number' ? n : uuid(n);
    }
    switch (type) {
      case 'number':
        if (c.contains('year')) return now.year;
        if (c.contains('month')) return now.month;
        return n * 100;
      case 'bool':
        return n.isOdd;
      case 'json':
        return null;
      case 'list':
        return const [];
    }
    final ts = now.subtract(Duration(days: n - 1));
    if (c.endsWith('_at') || c.contains('time') || c == 'timestamp') return ts.toIso8601String();
    if (c.contains('date') || c == 'dob' || c.endsWith('_on') || c == 'valid_from' || c == 'valid_until') {
      return ts.toIso8601String().substring(0, 10);
    }
    if (c.contains('month')) return ts.toIso8601String().substring(0, 7);
    if (c == 'flat_number' || c.endsWith('flat_number')) return 'A-10$n';
    if (c.contains('phone') || c.contains('mobile') || c == 'whatsapp') return '98765432$n$n';
    if (c.contains('email')) return 'user$n@example.com';
    if (c.contains('url') || c.contains('photo') || c.contains('image') || c.contains('logo') || c.contains('signature')) {
      return null;
    }
    if (c == 'status') return const ['active', 'pending', 'approved'][(n - 1) % 3];
    if (c == 'role' || c.endsWith('_role')) return 'resident';
    if (c.contains('name') || c == 'title') return 'Test ${table.replaceAll('_', ' ')} $n';
    if (c.contains('password')) return 'pass$n';
    return '$c $n';
  }
}
