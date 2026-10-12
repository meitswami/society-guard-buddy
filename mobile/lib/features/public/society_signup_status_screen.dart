import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/ui.dart';
import 'data/society_signup_service.dart';
import 'public_nav.dart';
import 'society_signup_screen.dart';

/// Port of web `SocietySignupStatusPage` (`/society-signup/status?signupId=…&token=…`):
/// polls `phonepe-poll-status` every 2.5 s until the society is provisioned / failed / cancelled.
///
/// Ids come from the constructor, else the route query (`GoRouterState`), else the signup
/// saved on this device when the payment was started.
class SocietySignupStatusScreen extends StatefulWidget {
  const SocietySignupStatusScreen({super.key, this.signupId, this.token, this.paymentUrl});

  final String? signupId;
  final String? token;

  /// PhonePe checkout URL, to reopen the payment page while it is still pending.
  final String? paymentUrl;

  @override
  State<SocietySignupStatusScreen> createState() => _SocietySignupStatusScreenState();
}

class _SocietySignupStatusScreenState extends State<SocietySignupStatusScreen> {
  String _signupId = '';
  String _token = '';
  String _paymentUrl = '';
  bool _loading = true;
  bool _pollError = false;
  String _status = '';
  String _societyName = '';
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  AppLifecycleListener? _lifecycle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_resolveAndStart());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Map<String, String> _routeQuery() {
    try {
      return GoRouterState.of(context).uri.queryParameters;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _resolveAndStart() async {
    var id = widget.signupId ?? '';
    var token = widget.token ?? '';
    var url = widget.paymentUrl ?? '';
    if (id.isEmpty || token.isEmpty) {
      final q = _routeQuery();
      id = q['signupId'] ?? '';
      token = q['token'] ?? '';
    }
    final pending = await SocietySignupStore.readPending();
    if (id.isEmpty || token.isEmpty) {
      id = pending?.signupId ?? '';
      token = pending?.token ?? '';
    }
    if (pending != null && pending.signupId == id) {
      if (url.isEmpty) url = pending.redirectUrl;
      _societyName = pending.societyName;
    }
    if (_disposed) return;
    setState(() {
      _signupId = id;
      _token = token;
      _paymentUrl = url;
    });
    if (id.isEmpty || token.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'failed';
      });
      return;
    }
    _lifecycle = AppLifecycleListener(onResume: () {
      if (!signupStatusIsTerminal(_status) && !_pollError) _pollNow();
    });
    await _poll();
  }

  void _pollNow() {
    _timer?.cancel();
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_disposed) return;
    try {
      final res = await PhonePeClient.pollStatus(signupId: _signupId, token: _token);
      if (_disposed) return;
      setState(() {
        _status = res.status;
        if (res.societyName.isNotEmpty) _societyName = res.societyName;
        _loading = false;
        _pollError = false;
      });
      if (signupStatusIsTerminal(res.status)) {
        await SocietySignupStore.clearPending();
        try {
          if (await supportsCloseForLaunchMode(LaunchMode.inAppBrowserView)) await closeInAppWebView();
        } catch (_) {}
        return;
      }
      _timer?.cancel();
      _timer = Timer(kSignupPollInterval, () => unawaited(_poll()));
    } catch (e) {
      if (_disposed || !mounted) return;
      debugPrint('phonepe-poll-status failed: $e');
      AppFeedback.toast(context, context.t('signup.errorGeneric'), tone: BadgeTone.alert);
      setState(() {
        _loading = false;
        _pollError = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _pollError = false;
      _loading = true;
    });
    _pollNow();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = signupStatusTitle(_status);
    final titleText = title.literal ?? context.t(title.key!);
    final failed = signupStatusFailed(_status);
    final done = _status.toLowerCase() == 'provisioned';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => PublicNav.leave(context)),
        actions: const [LanguageToggle(), SizedBox(width: 8), ThemeToggle(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: CardSection(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(titleText, style: AppText.pageTitle(context)),
                    if (_societyName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_societyName, style: AppText.body(context).copyWith(color: t.mutedForeground)),
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)),
                          const SizedBox(width: 8),
                          Text(context.t('signup.processing'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
                        ],
                      ),
                    ],
                    if (!done && !failed && !_loading && !_pollError && _paymentUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      AppButton.secondary(
                        icon: Icons.open_in_new,
                        label: context.tr('Open payment page again', 'भुगतान पृष्ठ फिर से खोलें'),
                        onPressed: () => openPhonePeCheckout(_paymentUrl),
                      ),
                    ],
                    if (_pollError) ...[
                      const SizedBox(height: 16),
                      Text(context.t('signup.errorGeneric'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
                      const SizedBox(height: 8),
                      AppButton.secondary(icon: Icons.refresh, label: context.tr('Check again', 'फिर से जाँचें'), onPressed: _retry),
                    ],
                    if (done) ...[
                      const SizedBox(height: 16),
                      Text(context.t('signup.successDone'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
                      const SizedBox(height: 8),
                      AppButton(label: context.t('signup.gotoHome'), onPressed: () => PublicNav.goToLogin(context)),
                    ],
                    if (failed) ...[
                      const SizedBox(height: 16),
                      Text(context.t('signup.errorGeneric'), style: AppText.body(context).copyWith(color: t.mutedForeground)),
                      const SizedBox(height: 8),
                      AppButton.secondary(
                        label: context.t('signup.payNow'),
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => const SocietySignupScreen()),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => PublicNav.goToLogin(context),
                          style: TextButton.styleFrom(foregroundColor: t.mutedForeground, textStyle: const TextStyle(fontSize: 12)),
                          child: Text(context.t('signup.gotoHome'), style: const TextStyle(decoration: TextDecoration.underline)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
