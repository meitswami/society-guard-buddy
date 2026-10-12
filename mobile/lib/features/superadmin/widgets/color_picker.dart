import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../superadmin_i18n.dart';

/// `#rrggbb` → [Color] (null when invalid).
Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  var v = hex.trim().replaceFirst('#', '');
  if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
  if (v.length != 6) return null;
  final n = int.tryParse(v, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

/// [Color] → lowercase `#rrggbb` (what the web `<input type="color">` produces).
String hexFromColor(Color c) {
  String h(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// Labelled colour swatch that opens [showHexColorPicker] (web `<input type="color">`).
class ColorSwatchField extends StatelessWidget {
  const ColorSwatchField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = colorFromHex(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Material(
          color: t.input,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: () async {
              final picked = await showHexColorPicker(context, initial: value, title: label);
              if (picked != null) onChanged(picked);
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color ?? t.muted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTokens.tint(t.foreground, 0.12)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(value, textAlign: TextAlign.center, style: AppText.mono(context, size: 10, color: t.mutedForeground)),
      ],
    );
  }
}

/// Bottom sheet with hue / saturation / brightness sliders, hex input and presets.
Future<String?> showHexColorPicker(BuildContext context, {required String initial, required String title}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ColorPickerSheet(initial: initial, title: title),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial, required this.title});

  final String initial;
  final String title;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  /// Brand presets: web defaults (`#14B8A6`, `#0F766E`, `#F0FAFA`), the migration defaults
  /// (`#F58220`, `#E08E10`, `#F8F7F4`) and common Tailwind hues.
  static const _presets = [
    '#14b8a6', '#0f766e', '#f0fafa', '#f58220', '#e08e10', '#f8f7f4', //
    '#0ea5e9', '#2563eb', '#4f46e5', '#7c3aed', '#db2777', '#e11d48', //
    '#16a34a', '#65a30d', '#ca8a04', '#ea580c', '#475569', '#0f172a', //
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(colorFromHex(widget.initial) ?? const Color(0xFF14B8A6));
    _hex = TextEditingController(text: hexFromColor(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _hex.text = hexFromColor(hsv.toColor());
  }

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required List<Color> track,
    required ValueChanged<double> onChanged,
  }) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption(context)),
        const SizedBox(height: 4),
        Container(
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: track),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.border),
          ),
        ),
        Slider(value: value.clamp(0, max), max: max, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppText.sectionTitle(context)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      border: Border.all(color: t.border),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      style: AppText.mono(context, size: 14),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: const InputDecoration(hintText: '#14b8a6'),
                      onChanged: (v) {
                        final c = colorFromHex(v);
                        if (c != null && v.replaceFirst('#', '').length == 6) setState(() => _hsv = HSVColor.fromColor(c));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _slider(
                label: context.st('sa.color.hue'),
                value: _hsv.hue,
                max: 360,
                track: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
                onChanged: (v) => _set(_hsv.withHue(v)),
              ),
              _slider(
                label: context.st('sa.color.saturation'),
                value: _hsv.saturation * 100,
                max: 100,
                track: [_hsv.withSaturation(0).toColor(), _hsv.withSaturation(1).toColor()],
                onChanged: (v) => _set(_hsv.withSaturation(v / 100)),
              ),
              _slider(
                label: context.st('sa.color.brightness'),
                value: _hsv.value * 100,
                max: 100,
                track: [_hsv.withValue(0).toColor(), _hsv.withValue(1).toColor()],
                onChanged: (v) => _set(_hsv.withValue(v / 100)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _presets)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _set(HSVColor.fromColor(colorFromHex(p)!)),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: colorFromHex(p),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hexFromColor(color) == p ? t.primary : t.border,
                            width: hexFromColor(color) == p ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(label: context.t('common.cancel'), onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: context.st('sa.color.use'),
                      onPressed: () => Navigator.pop(context, hexFromColor(_hsv.toColor())),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
