import 'package:supabase_flutter/supabase_flutter.dart';

/// postgrest-dart `order()` defaults to DESC and always sets NULLS FIRST/LAST, while supabase-js
/// defaults to ASC and leaves the Postgres default (ASC → nulls last, DESC → nulls first).
/// These helpers reproduce the supabase-js behaviour of the web queries.
extension WebOrderX<T> on PostgrestFilterBuilder<T> {
  /// supabase-js `.order(column)` / `.order(column, { ascending: true })`.
  PostgrestTransformBuilder<T> orderAsc(String column) => order(column, ascending: true, nullsFirst: false);

  /// supabase-js `.order(column, { ascending: false })`.
  PostgrestTransformBuilder<T> orderDesc(String column) => order(column, ascending: false, nullsFirst: true);
}

/// Human readable message for Supabase errors (web shows `error.message`).
String supabaseErrorMessage(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return '${d['error']}';
    return e.reasonPhrase ?? 'Function error (${e.status})';
  }
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}
