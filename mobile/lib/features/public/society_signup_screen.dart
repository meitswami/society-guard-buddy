import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/ui.dart';
import 'data/society_signup_service.dart';
import 'public_nav.dart';
import 'society_signup_status_screen.dart';

/// Port of web `NewSocietySignupPage` (`/society-signup`): society, contact and admin
/// details → `phonepe-init-order` → PhonePe checkout in an in-app browser → status polling.
class SocietySignupScreen extends StatefulWidget {
  const SocietySignupScreen({super.key});

  @override
  State<SocietySignupScreen> createState() => _SocietySignupScreenState();
}

class _SocietySignupScreenState extends State<SocietySignupScreen> {
  final _c = <String, TextEditingController>{
    for (final k in const [
      'society_name', 'address', 'city', 'state', 'pincode', 'blocks_csv', 'total_floors', 'flats_per_floor', //
      'flat_series_start', 'flat_series_end', 'contact_person', 'contact_phone', 'contact_email', 'referral_code',
      'admin_id', 'admin_password',
    ])
      k: TextEditingController(),
  };
  bool _loading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    for (final c in _c.values) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  SocietySignupDraft get _draft => SocietySignupDraft(
        societyName: _c['society_name']!.text,
        address: _c['address']!.text,
        city: _c['city']!.text,
        state: _c['state']!.text,
        pincode: _c['pincode']!.text,
        blocksCsv: _c['blocks_csv']!.text,
        totalFloors: _c['total_floors']!.text,
        flatsPerFloor: _c['flats_per_floor']!.text,
        flatSeriesStart: _c['flat_series_start']!.text,
        flatSeriesEnd: _c['flat_series_end']!.text,
        contactPerson: _c['contact_person']!.text,
        contactPhone: _c['contact_phone']!.text,
        contactEmail: _c['contact_email']!.text,
        referralCode: _c['referral_code']!.text,
        adminId: _c['admin_id']!.text,
        adminPassword: _c['admin_password']!.text,
      );

  Future<void> _onPay() async {
    final draft = _draft;
    if (!draft.canSubmit || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final res = await PhonePeClient.initOrder(draft);
      if (!mounted) return;
      if (res.alreadyExists) {
        AppFeedback.toast(
            context, context.tr('Society already exists. No payment needed.', 'सोसाइटी पहले से मौजूद है। भुगतान की आवश्यकता नहीं।'));
        PublicNav.goToLogin(context);
        return;
      }
      if (res.redirectUrl.isEmpty || res.signupId.isEmpty) throw StateError('Missing redirect url');
      final pending = PendingSocietySignup(
        signupId: res.signupId,
        token: res.token,
        redirectUrl: res.redirectUrl,
        societyName: draft.societyName.trim(),
      );
      await SocietySignupStore.savePending(pending);
      await openPhonePeCheckout(res.redirectUrl);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => SocietySignupStatusScreen(signupId: res.signupId, token: res.token, paymentUrl: res.redirectUrl),
      ));
    } catch (e) {
      debugPrint('phonepe-init-order failed: $e');
      if (mounted) AppFeedback.toast(context, context.t('signup.errorGeneric'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(String key, String labelKey, IconData icon,
      {TextInputType? keyboard, bool obscure = false, bool upper = false, List<String>? autofill}) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: t.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(context.t(labelKey), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.foreground))),
            ],
          ),
        ),
        TextField(
          controller: _c[key],
          keyboardType: keyboard,
          obscureText: obscure && !_showPassword,
          autofillHints: autofill,
          textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
          inputFormatters: upper ? [_UpperCase()] : null,
          style: TextStyle(fontSize: 14, color: t.foreground),
          decoration: InputDecoration(
            constraints: const BoxConstraints(minHeight: 44),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: t.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: AppTokens.tint(t.border, 0.8))),
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radius), borderSide: BorderSide(color: t.ring, width: 2)),
            fillColor: t.background,
            suffixIcon: obscure
                ? IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    color: t.mutedForeground,
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /// Web `grid sm:grid-cols-2`: one column on phones, two from 600 dp; [wide] spans both.
  Widget _grid(List<(Widget, bool)> fields) => LayoutBuilder(builder: (context, c) {
        final two = c.maxWidth >= 560;
        final half = (c.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final (w, wide) in fields) SizedBox(width: two && !wide ? half : c.maxWidth, child: w),
          ],
        );
      });

  Widget _section(int step, String titleKey, IconData icon, List<(Widget, bool)> fields) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: AppTokens.tint(t.border, 0.7)),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: [BoxShadow(color: AppTokens.tint(t.foreground, 0.04), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.primary, 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  border: Border.all(color: AppTokens.tint(t.primary, 0.25)),
                ),
                child: Icon(icon, size: 24, color: t.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.t('signup.step')} $step'.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: t.primary),
                    ),
                    Text(context.t(titleKey), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.foreground)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _grid(fields),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canSubmit = _draft.canSubmit;
    final price = NumberFormat.decimalPattern('en_IN').format(kSocietySignupPriceInr);
    const num = TextInputType.number;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.alphaBlend(AppTokens.tint(t.muted, 0.4), t.background), t.background, t.background],
          ),
        ),
        child: SafeArea(
          child: PageContainer(
            maxWidth: 672,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              // Web `flex justify-between`: back link + toggles (wraps on narrow phones).
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Material(
                    color: t.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius), side: BorderSide(color: t.border)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      onTap: () => PublicNav.leave(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 16, color: t.mutedForeground),
                            const SizedBox(width: 6),
                            // The key text starts with "← "; the icon already shows the arrow.
                            Text(context.t('login.backToSociety').replaceFirst(RegExp(r'^←\s*'), ''),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.mutedForeground)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [LanguageToggle(), SizedBox(width: 8), ThemeToggle()],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Hero(),
              const SizedBox(height: 32),
              _section(1, 'signup.societyDetails', Icons.apartment_outlined, [
                (_field('society_name', 'signup.name', Icons.apartment_outlined, autofill: const [AutofillHints.organizationName]), false),
                (_field('address', 'signup.address', Icons.place_outlined, autofill: const [AutofillHints.fullStreetAddress]), true),
                (_field('city', 'signup.city', Icons.home_outlined, autofill: const [AutofillHints.addressCity]), false),
                (_field('state', 'signup.state', Icons.place_outlined, autofill: const [AutofillHints.addressState]), false),
                (_field('pincode', 'signup.pincode', Icons.tag, keyboard: num, autofill: const [AutofillHints.postalCode]), false),
                (_field('blocks_csv', 'signup.blocks', Icons.grid_view_outlined), false),
                (_field('total_floors', 'signup.totalFloors', Icons.layers_outlined, keyboard: num), false),
                (_field('flats_per_floor', 'signup.flatsPerFloor', Icons.grid_view_outlined, keyboard: num), false),
                (_field('flat_series_start', 'signup.flatSeriesFrom', Icons.home_outlined), false),
                (_field('flat_series_end', 'signup.flatSeriesTo', Icons.home_outlined), false),
              ]),
              _section(2, 'signup.contactDetails', Icons.person_outline, [
                (_field('contact_person', 'signup.contactPerson', Icons.person_outline, autofill: const [AutofillHints.name]), false),
                (
                  _field('contact_phone', 'signup.contactPhone', Icons.phone_outlined,
                      keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
                  false
                ),
                (
                  _field('contact_email', 'signup.contactEmail', Icons.mail_outline,
                      keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
                  true
                ),
                (_field('referral_code', 'signup.referralOptional', Icons.tag, upper: true), true),
              ]),
              _section(3, 'signup.adminCreds', Icons.shield_outlined, [
                // Admin IDs are matched upper-case at login (`admin_id = input.toUpperCase()`).
                (
                  _field('admin_id', 'signup.adminId', Icons.shield_outlined, upper: true, autofill: const [AutofillHints.newUsername]),
                  false
                ),
                (
                  _field('admin_password', 'signup.adminPassword', Icons.shield_outlined,
                      obscure: true, autofill: const [AutofillHints.newPassword]),
                  false
                ),
              ]),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.card, 0.8),
                  border: Border.all(color: AppTokens.tint(t.primary, 0.25)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                  boxShadow: [BoxShadow(color: AppTokens.tint(t.primary, 0.05), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Opacity(
                      opacity: canSubmit ? 1 : 0.5,
                      child: Material(
                        color: t.primary,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        elevation: canSubmit ? 3 : 0,
                        shadowColor: AppTokens.tint(t.primary, 0.25),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                          onTap: canSubmit && !_loading ? _onPay : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_loading)
                                  SizedBox(
                                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.primaryForeground))
                                else
                                  Icon(Icons.auto_awesome, size: 20, color: t.primaryForeground),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _loading ? context.t('signup.processing') : context.t('signup.payNow'),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.primaryForeground),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('Price: ₹$price', 'मूल्य: ₹$price'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: t.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTokens.tint(t.primary, 0.2)),
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(AppTokens.tint(t.primary, 0.12), t.card),
              t.card,
              Color.alphaBlend(AppTokens.tint(t.accent, 0.08), t.card),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -48,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppTokens.tint(t.primary, 0.15), AppTokens.tint(t.primary, 0)]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTokens.tint(t.primary, 0.2),
                      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                      border: Border.all(color: AppTokens.tint(t.primary, 0.25), width: 2),
                    ),
                    child: Icon(Icons.auto_awesome, size: 28, color: t.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t('signup.title'), style: AppText.pageTitle(context).copyWith(fontSize: 24)),
                        const SizedBox(height: 8),
                        Text(context.t('signup.subtitle'), style: AppText.body(context).copyWith(color: t.mutedForeground, height: 1.5)),
                        const SizedBox(height: 8),
                        Text(
                          context.t('signup.requiredNote'),
                          style: TextStyle(fontSize: 11, height: 1.4, color: AppTokens.tint(t.mutedForeground, 0.9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Opens the PhonePe checkout in an in-app browser (Custom Tabs / SFSafariViewController,
/// which can hand UPI intents to payment apps); falls back to the external browser.
Future<void> openPhonePeCheckout(String url) async {
  final uri = Uri.parse(url);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {}
  if (ok) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
