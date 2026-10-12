import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../logic/js_compat.dart';
import '../logic/society_form.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';

/// Web dashboard heading: crown square + "Super Admin Panel" + name, red logout button.
class SuperadminHeader extends StatelessWidget {
  const SuperadminHeader({super.key, required this.name, required this.onLogout, this.bottomSpacing = 20});

  final String name;
  final VoidCallback onLogout;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageHeader(
      title: context.t('superadmin.panel'),
      subtitle: name,
      icon: Icons.workspace_premium_outlined,
      bottomSpacing: bottomSpacing,
      actions: [
        Material(
          color: AppTokens.tint(t.destructive, 0.10),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: onLogout,
            child: Tooltip(
              message: context.t('swal.confirmLogoutUser'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.logout, size: 20, color: t.destructive),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Web `<select>` of societies shown above the tab content (shared selection).
class SocietySelector extends StatelessWidget {
  const SocietySelector({super.key, this.bottomSpacing = 16});

  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final console = SuperadminScope.of(context);
    if (console.societies.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: AppDropdown<String>(
        items: [for (final s in console.societies) s.id],
        value: console.selectedSocietyId.isEmpty ? null : console.selectedSocietyId,
        hint: context.t('superadmin.selectSociety'),
        labelOf: (id) {
          final s = console.societyById(id);
          if (s == null) return id;
          return s.isActive ? s.name : '${s.name} (${context.st('sa.societies.inactive')})';
        },
        onChanged: (v) {
          if (v != null) console.selectSociety(v);
        },
      ),
    );
  }
}

/// `text-[10px] text-muted-foreground`, optionally with the web's left accent border.
class SaHint extends StatelessWidget {
  const SaHint(this.text, {super.key, this.accent, this.padding = const EdgeInsets.only(top: 4)});

  final String text;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: AppText.tiny(context).copyWith(height: 1.4));
    if (accent == null) return Padding(padding: padding, child: label);
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: accent!, width: 2))),
        child: label,
      ),
    );
  }
}

/// Web form sub-section: top border + uppercase muted label.
class SaSubsection extends StatelessWidget {
  const SaSubsection({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label.toUpperCase(), style: AppText.fieldLabel(context)),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Yes / No / Not specified select (web `TriState` selects).
class TriStateField extends StatelessWidget {
  const TriStateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final TriState value;
  final ValueChanged<TriState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: AppText.caption(context))),
        AppDropdown<TriState>(
          items: TriState.values,
          value: value,
          labelOf: (v) => switch (v) {
            TriState.unset => context.t('superadmin.notSpecified'),
            TriState.yes => context.t('swal.yes'),
            TriState.no => context.t('swal.no'),
          },
          onChanged: (v) => onChanged(v ?? TriState.unset),
        ),
      ],
    );
  }
}

/// Web 6-digit code input: centred, mono, wide letter spacing, digits only.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({super.key, required this.controller, this.onSubmitted, this.autofocus = true});

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: onSubmitted,
      style: AppText.mono(context, size: 18).copyWith(letterSpacing: 7),
      decoration: const InputDecoration(hintText: '000000', counterText: ''),
    );
  }
}

/// Web `<img class="rounded-lg object-cover">` with a muted placeholder.
class SaNetImage extends StatelessWidget {
  const SaNetImage(this.url, {super.key, this.width = 40, this.height = 40, this.radius = 8, this.fit = BoxFit.cover});

  final String url;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final placeholder = Container(
      width: width,
      height: height,
      color: t.muted,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: (width < height ? width : height) * 0.45, color: t.mutedForeground),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: url,
                width: width,
                height: height,
                fit: fit,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

/// Inline error line (web `text-destructive text-sm text-center`).
class SaErrorText extends StatelessWidget {
  const SaErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: context.tokens.destructive),
    );
  }
}

/// Underlined muted link button (web `text-xs text-muted-foreground underline`).
class SaLinkButton extends StatelessWidget {
  const SaLinkButton({super.key, required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.mutedForeground;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c, decoration: TextDecoration.underline, decorationColor: c),
        ),
      ),
    );
  }
}

/// Small rounded tag (web `text-[10px] px-2 py-0.5 rounded-full`).
class SaTag extends StatelessWidget {
  const SaTag(this.label, {super.key, this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: primary ? AppTokens.tint(t.primary, 0.10) : t.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: primary ? t.primary : t.mutedForeground)),
    );
  }
}

/// Copies [text] and shows a toast.
Future<void> saCopy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) AppFeedback.toast(context, context.st('sa.copied'), tone: BadgeTone.success);
}

/// Upper-cases as you type (web inputs with `uppercase` + `.toUpperCase()` on save).
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Rough check used by the society list for `tel:` / `mailto:` actions.
bool looksLikePhone(String? v) => v != null && digitsOnly(v).length >= 6;
