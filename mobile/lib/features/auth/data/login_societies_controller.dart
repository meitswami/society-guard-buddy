import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/config/env.dart';
import '../../../services/society_service.dart';

/// Port of web `useLoginSocieties`: loads the active societies with retry / backoff,
/// exposes loading + error for `SocietyListStatus`, and reloads when the device comes
/// back online (web `online` event) or the app returns to the foreground
/// (`visibilitychange`) while the list is still empty.
class LoginSocietiesController extends ChangeNotifier {
  LoginSocietiesController({
    SocietyService? service,
    Future<List<SocietyRow>> Function()? fetch,
    Future<bool> Function()? probe,
    Duration probeInterval = const Duration(seconds: 4),
  })  : _fetch = fetch ?? (service ?? SocietyService()).fetchActiveSocietiesWithRetry,
        _probe = probe ?? _defaultProbe(),
        _probeInterval = probeInterval;

  final Future<List<SocietyRow>> Function() _fetch;
  final Future<bool> Function()? _probe;
  final Duration _probeInterval;

  List<SocietyRow> _societies = const [];
  bool _loading = true;
  String? _error;
  bool _inFlight = false;
  bool _disposed = false;
  int _count = 0;
  Timer? _probeTimer;
  bool? _lastProbeOk;
  bool _probing = false;

  List<SocietyRow> get societies => _societies;
  bool get loading => _loading;
  String? get error => _error;

  /// Starts the first load and the reconnect watcher.
  void start() {
    unawaited(reload());
    if (_probe != null) {
      _probeTimer ??= Timer.periodic(_probeInterval, (_) => _checkConnectivity());
    }
  }

  /// Web `reload` — ignored while a load is in flight.
  Future<void> reload() async {
    if (_inFlight || _disposed) return;
    _inFlight = true;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _fetch();
      if (_disposed) return;
      _count = rows.length;
      _societies = rows;
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
    } finally {
      _inFlight = false;
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Web `retryIfEmpty` (app resumed / back online).
  void retryIfEmpty() {
    if (_count == 0) unawaited(reload());
  }

  Future<void> _checkConnectivity() async {
    final probe = _probe;
    if (probe == null || _disposed || _probing || _inFlight || _count > 0) return;
    _probing = true;
    try {
      final ok = await probe();
      if (_disposed) return;
      final wasOffline = _lastProbeOk == false;
      _lastProbeOk = ok;
      // Only an offline → online transition triggers a reload (like the browser `online` event).
      if (ok && wasOffline) retryIfEmpty();
    } finally {
      _probing = false;
    }
  }

  /// DNS lookup of the Supabase host (no extra connectivity package needed).
  static Future<bool> Function()? _defaultProbe() {
    if (kIsWeb || !Env.isConfigured) return null;
    final host = Uri.tryParse(Env.supabaseUrl)?.host ?? '';
    if (host.isEmpty) return null;
    return () async {
      try {
        final res = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
        return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _probeTimer?.cancel();
    _probeTimer = null;
    super.dispose();
  }
}
