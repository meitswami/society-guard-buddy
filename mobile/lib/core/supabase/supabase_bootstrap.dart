import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

abstract final class SupabaseBootstrap {
  static Future<void> init() async {
    if (!Env.isConfigured) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      httpClient: TimeoutHttpClient(http.Client()),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

/// Gives every database / RPC / Edge Function call a deadline, so a screen shows its
/// "Could not load · Retry" state on a dead connection instead of a spinner that never ends.
/// Storage uploads and downloads are left without a limit (large files on slow networks).
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 30)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final path = request.url.path;
    final limited = path.startsWith('/rest/') || path.startsWith('/functions/');
    final res = _inner.send(request);
    return limited ? res.timeout(timeout) : res;
  }

  @override
  void close() => _inner.close();
}
