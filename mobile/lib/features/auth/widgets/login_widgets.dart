import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/login_logic.dart';

/// Web login heading: 64px tinted Shield tile, `app.name`, `app.subtitle`, `app.tagline`.
class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key, this.icon = Icons.shield_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(AppTokens.radiusXl)),
            child: Icon(icon, size: 32, color: t.primary),
          ),
          const SizedBox(height: 12),
          Text(context.t('app.name'), textAlign: TextAlign.center, style: AppText.pageTitle(context)),
          const SizedBox(height: 4),
          Text(context.t('app.subtitle'), textAlign: TextAlign.center, style: AppText.caption(context)),
          const SizedBox(height: 2),
          Text(
            context.t('app.tagline'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTokens.tint(t.mutedForeground, 0.8)),
          ),
        ],
      ),
    );
  }
}

/// Web `<select class="input-field">` with a placeholder option. Opens a bottom-sheet list
/// (like the native mobile select), with search for long lists (societies, flats).
class SelectSheetField<T> extends StatelessWidget {
  const SelectSheetField({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.placeholder,
    required this.onChanged,
    this.sheetTitle,
    this.enabled = true,
    this.leadingIcon,
    this.allowPlaceholder = true,
  });

  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final String placeholder;
  final ValueChanged<T?>? onChanged;
  final String? sheetTitle;
  final bool enabled;
  final IconData? leadingIcon;

  /// Offer the placeholder as a choice (web `<option value="">`), which clears the value.
  final bool allowPlaceholder;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<_Pick<T>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SelectSheet<T>(
        title: sheetTitle ?? placeholder,
        options: options,
        value: value,
        labelOf: labelOf,
        placeholder: allowPlaceholder ? placeholder : null,
      ),
    );
    if (picked != null) onChanged?.call(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = enabled && onChanged != null;
    final selected = value;
    final text = selected == null ? placeholder : labelOf(selected);
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Material(
        color: t.input,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: t.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: active ? () => _open(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 16, color: t.mutedForeground),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: selected == null ? t.mutedForeground : t.foreground),
                  ),
                ),
                Icon(Icons.unfold_more_rounded, size: 18, color: t.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pick<T> {
  const _Pick(this.value);
  final T? value;
}

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({required this.title, required this.options, required this.value, required this.labelOf, this.placeholder});

  final String title;
  final List<T> options;
  final T? value;
  final String Function(T) labelOf;
  final String? placeholder;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final searchable = widget.options.length > 8;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty ? widget.options : widget.options.where((o) => widget.labelOf(o).toLowerCase().contains(q)).toList();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    Widget tile(String label, bool selected, VoidCallback onTap, {bool muted = false}) => ListTile(
          dense: true,
          title: Text(label, style: TextStyle(fontSize: 14, color: muted ? t.mutedForeground : t.foreground)),
          trailing: selected ? Icon(Icons.check_rounded, size: 18, color: t.primary) : null,
          selected: selected,
          onTap: onTap,
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(widget.title, style: AppText.sectionTitle(context)),
              ),
              if (searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: context.t('mobile.search'),
                      prefixIcon: Icon(Icons.search, size: 18, color: t.mutedForeground),
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.placeholder != null && q.isEmpty)
                      tile(widget.placeholder!, widget.value == null, () => Navigator.pop(context, _Pick<T>(null)), muted: true),
                    for (final o in filtered)
                      tile(widget.labelOf(o), o == widget.value, () => Navigator.pop(context, _Pick<T>(o))),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(context.t('mobile.empty'), textAlign: TextAlign.center, style: AppText.caption(context)),
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

/// Web `SocietyListStatus`: shown under the society picker when the list failed / is empty.
class SocietyListStatus extends StatelessWidget {
  const SocietyListStatus({super.key, required this.loading, required this.error, required this.count, required this.onRetry});

  final bool loading;
  final String? error;
  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final key = societyListStatusKey(loading: loading, error: error, count: count);
    if (key == null) return const SizedBox.shrink();
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.destructive, 0.05),
        border: Border.all(color: AppTokens.tint(t.destructive, 0.3)),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(child: Text(context.t(key), style: TextStyle(fontSize: 12, height: 1.35, color: t.destructive))),
          const SizedBox(width: 8),
          Material(
            color: t.secondary,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 14, color: t.secondaryForeground),
                    const SizedBox(width: 4),
                    Text(
                      context.t('login.retry'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.secondaryForeground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Web "Register a new society" gradient CTA (`from-primary via-cyan-400 to-primary`).
class RegisterSocietyCta extends StatefulWidget {
  const RegisterSocietyCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<RegisterSocietyCta> createState() => _RegisterSocietyCtaState();
}

class _RegisterSocietyCtaState extends State<RegisterSocietyCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = t.primaryForeground;
    final radius = BorderRadius.circular(AppTokens.radius);
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(colors: [t.primary, t.accent, t.primary]),
          border: Border.all(color: AppTokens.tint(t.primary, t.isDark ? 0.25 : 0.4)),
          boxShadow: [BoxShadow(color: AppTokens.tint(t.primary, 0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(Icons.apartment_rounded, size: 20, color: fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('login.registerNewSociety'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.auto_awesome, size: 16, color: AppTokens.tint(fg, 0.95)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: AppTokens.tint(fg, 0.9)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web mode switch inside `bg-muted rounded-xl p-1`: "OTP Login" | "ID & Password".
class LoginModeToggle extends StatelessWidget {
  const LoginModeToggle({super.key, required this.mode, required this.onChanged, this.otpDisabled = false});

  final LoginMode mode;
  final ValueChanged<LoginMode> onChanged;
  final bool otpDisabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget opt(LoginMode m, IconData icon, String label, {bool disabled = false}) {
      final active = mode == m;
      final fg = active ? t.primaryForeground : t.mutedForeground;
      return Expanded(
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: GestureDetector(
            onTap: disabled ? null : () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
              decoration: BoxDecoration(
                color: active ? t.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                boxShadow: active ? [BoxShadow(color: AppTokens.tint(t.foreground, 0.08), blurRadius: 2, offset: const Offset(0, 1))] : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.muted, borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: Row(
        children: [
          opt(LoginMode.otp, Icons.phone_outlined, context.tr('OTP Login', 'ओटीपी प्रवेश'), disabled: otpDisabled),
          const SizedBox(width: 4),
          opt(LoginMode.credentials, Icons.shield_outlined, context.tr('ID & Password', 'पहचान और कूटशब्द')),
        ],
      ),
    );
  }
}

/// Web dashed "Login with Fingerprint" button (`border-2 border-dashed border-primary/30 bg-primary/5`).
class BiometricQuickButton extends StatelessWidget {
  const BiometricQuickButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(AppTokens.radius);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppTokens.tint(t.primary, 0.3), radius: AppTokens.radius),
        child: Material(
          color: AppTokens.tint(t.primary, 0.05),
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  if (loading)
                    SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary))
                  else
                    Icon(Icons.fingerprint, size: 28, color: t.primary),
                  const SizedBox(height: 4),
                  Text(
                    context.t('biometric.loginButton'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(1);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + 6).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color || old.radius != radius;
}

/// Small centred helper text (`text-xs text-muted-foreground text-center`).
class LoginHint extends StatelessWidget {
  const LoginHint(this.text, {super.key, this.size = 12, this.color, this.bottom = 12});

  final String text;
  final double size;
  final Color? color;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, height: 1.4, color: color ?? context.tokens.mutedForeground),
      ),
    );
  }
}
