import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../data/member_rules.dart';
import '../data/resident_media.dart';

final Map<int, Uint8List> _dataUrlCache = {};

/// `data:image/...;base64,` or http(s) photo → image provider (web stores both).
ImageProvider? residentImageProvider(String? src) {
  final s = (src ?? '').trim();
  if (s.isEmpty) return null;
  if (s.startsWith('data:')) {
    final key = Object.hash(s.length, s.hashCode);
    final cached = _dataUrlCache[key];
    if (cached != null) return MemoryImage(cached);
    final comma = s.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(s.substring(comma + 1));
      if (_dataUrlCache.length > 64) _dataUrlCache.clear();
      _dataUrlCache[key] = bytes;
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  if (s.startsWith('http://') || s.startsWith('https://')) return CachedNetworkImageProvider(s);
  return null;
}

/// Small rounded image thumbnail with an optional remove button.
class ResidentThumb extends StatelessWidget {
  const ResidentThumb({super.key, required this.src, this.size = 56, this.circle = false, this.onRemove});

  final String src;
  final double size;
  final bool circle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final provider = residentImageProvider(src);
    final img = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.muted,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: t.border),
        image: provider == null ? null : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null ? Icon(Icons.image_not_supported_outlined, size: 18, color: t.mutedForeground) : null,
    );
    if (onRemove == null) return img;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        img,
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: t.destructive,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.close, size: 12, color: t.destructiveForeground)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bordered outline action (web `text-xs px-3 py-2 rounded-lg border`).
class OutlineChipButton extends StatelessWidget {
  const OutlineChipButton({super.key, required this.label, required this.onTap, this.icon, this.done = false});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm), side: BorderSide(color: t.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: t.foreground), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 12, color: t.foreground, fontWeight: FontWeight.w500)),
              if (done) ...[const SizedBox(width: 6), Icon(Icons.check, size: 14, color: t.success)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tinted "+ Add" button (web `text-xs bg-primary/10 text-primary`).
class TintAddButton extends StatelessWidget {
  const TintAddButton({super.key, required this.label, required this.onTap, this.solid = false});

  final String label;
  final VoidCallback onTap;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = solid ? t.primaryForeground : t.primary;
    return Material(
      color: solid ? t.primary : AppTokens.tint(t.primary, 0.10),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Date input showing `dd/MM/yyyy`, emitting `yyyy-MM-dd` (web `DateInput`).
class ResidentDateField extends StatelessWidget {
  const ResidentDateField({super.key, required this.value, required this.onChanged, this.label, this.clearable = false});

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final current = DateTime.tryParse(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(Fmt.isoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: clearable && value.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => onChanged(''))
              : Icon(Icons.calendar_today_outlined, size: 16, color: t.mutedForeground),
        ),
        child: Text(
          value.isEmpty ? 'dd/mm/yyyy' : Fmt.isoToDisplay(value),
          style: TextStyle(fontSize: 14, color: value.isEmpty ? t.mutedForeground : t.foreground),
        ),
      ),
    );
    if (label == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [FieldLabel(label!), field]);
  }
}

/// `HH:mm` time input (web `<input type="time">`).
class ResidentTimeField extends StatelessWidget {
  const ResidentTimeField({super.key, required this.value, required this.onChanged, this.label});

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;

  Future<void> _pick(BuildContext context) async {
    final parts = value.split(':');
    final initial = parts.length >= 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) {
      onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(suffixIcon: Icon(Icons.schedule, size: 16, color: t.mutedForeground)),
        child: Text(value.isEmpty ? '--:--' : value, style: AppText.mono(context, size: 14)),
      ),
    );
    if (label == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [FieldLabel(label!), field]);
  }
}

/// Status pill with web colours (`bg-green-500/20 text-green-600`, destructive, amber, secondary).
class ToneBadge extends StatelessWidget {
  const ToneBadge(this.label, {super.key, required this.tone, this.uppercase = false});

  final String label;
  final BadgeTone tone;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (tone) {
      BadgeTone.success || BadgeTone.inside => (AppTokens.tint(t.success, 0.2), t.success),
      BadgeTone.alert => (AppTokens.tint(t.destructive, 0.2), t.destructive),
      BadgeTone.warning => (AppTokens.tint(t.warning, 0.2), t.warning),
      BadgeTone.info => (AppTokens.tint(t.primary, 0.15), t.primary),
      _ => (t.secondary, t.secondaryForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(uppercase ? label.toUpperCase() : label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// Photo ID / tenant document list editor (web "Photo ID uploads" + "Tenant documents").
class DocDraftsEditor extends StatelessWidget {
  const DocDraftsEditor({
    super.key,
    required this.docs,
    required this.kind,
    required this.onChanged,
    required this.title,
    required this.addLabel,
    this.emptyText,
    this.singleSide = false,
  });

  final List<MemberDocDraft> docs;
  final String kind;
  final ValueChanged<List<MemberDocDraft>> onChanged;
  final String title;
  final String addLabel;
  final String? emptyText;
  /// Tenant docs have one "Upload" (front) image.
  final bool singleSide;

  List<DocTypeOption> get _types => kind == MemberDocDraft.kindTenantDoc ? kTenantDocTypes : kPhotoIdDocTypes;

  Future<void> _capture(BuildContext context, int index, bool front) async {
    final data = await ResidentMedia.pickImageDataUrl(context, maxSide: 1280, quality: 75);
    if (data == null) return;
    final next = List.of(docs);
    next[index] = front ? next[index].copyWith(front: data) : next[index].copyWith(back: data);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final indexes = [for (var i = 0; i < docs.length; i++) if (docs[i].kind == kind) i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(title.toUpperCase(), style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600))),
          TintAddButton(
            label: addLabel,
            onTap: () => onChanged([
              ...docs,
              MemberDocDraft(kind: kind, type: kind == MemberDocDraft.kindTenantDoc ? 'rental_agreement' : 'aadhaar'),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        if (indexes.isEmpty && emptyText != null) Text(emptyText!, style: AppText.tiny(context)),
        for (final i in indexes)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.tint(t.background, 0.5),
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: AppDropdown<String>(
                      items: [for (final o in _types) o.value],
                      value: docs[i].type,
                      labelOf: (v) => _types.firstWhere((o) => o.value == v, orElse: () => DocTypeOption(v, v)).label,
                      onChanged: (v) {
                        if (v == null) return;
                        final next = List.of(docs);
                        next[i] = next[i].copyWith(type: v);
                        onChanged(next);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Remove', 'हटाएँ'),
                    icon: Icon(Icons.close, size: 18, color: t.mutedForeground),
                    onPressed: () => onChanged(List.of(docs)..removeAt(i)),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  OutlineChipButton(
                    icon: Icons.photo_camera_outlined,
                    label: singleSide ? context.tr('Upload', 'अपलोड') : context.tr('Front', 'आगे'),
                    done: docs[i].front.isNotEmpty,
                    onTap: () => _capture(context, i, true),
                  ),
                  if (!singleSide)
                    OutlineChipButton(
                      icon: Icons.photo_camera_outlined,
                      label: context.tr('Back', 'पीछे'),
                      done: docs[i].back.isNotEmpty,
                      onTap: () => _capture(context, i, false),
                    ),
                  if (docs[i].front.isNotEmpty) ResidentThumb(src: docs[i].front, size: 40),
                  if (docs[i].back.isNotEmpty) ResidentThumb(src: docs[i].back, size: 40),
                ]),
              ],
            ),
          ),
      ],
    );
  }
}

/// Share / print sheet for a generated PDF (web `SharePdfWhatsAppButton` + download).
Future<void> showPdfActions(
  BuildContext context, {
  required Uint8List bytes,
  required String filename,
  String? message,
  String? warning,
}) async {
  if (warning != null && warning.isNotEmpty) AppFeedback.toast(context, warning, tone: BadgeTone.warning);
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(filename, style: AppText.caption(ctx), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: Icon(Icons.share_outlined, color: ctx.tokens.success),
            title: Text(ctx.tr('Share PDF (WhatsApp, email…)', 'PDF साझा करें (व्हाट्सऐप, ईमेल…)')),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await ExportKit.sharePdf(bytes, filename, text: message);
              } catch (_) {
                if (context.mounted) AppFeedback.toast(context, context.tr('Could not share PDF', 'PDF साझा नहीं हो सकी'), tone: BadgeTone.alert);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(ctx.tr('Download / print PDF', 'PDF डाउनलोड / प्रिंट करें')),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await ExportKit.printPdf(bytes, name: filename);
              } catch (_) {
                if (context.mounted) AppFeedback.toast(context, context.tr('Could not open PDF', 'PDF नहीं खुल सकी'), tone: BadgeTone.alert);
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Muted uppercase list label (web `text-xs font-medium text-muted-foreground uppercase tracking-wider`).
class ListLabel extends StatelessWidget {
  const ListLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: AppText.fieldLabel(context))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
