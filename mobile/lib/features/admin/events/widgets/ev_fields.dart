import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/ui.dart';
import '../data/events_storage.dart';
import '../logic/contribution_rows.dart';
import '../logic/finance_dates.dart';
import 'ev_i18n.dart';
import 'ev_ui.dart';

/// Web `DateInput`: shows dd/MM/yyyy, emits `yyyy-MM-dd` ('' when cleared).
class EvDateField extends StatelessWidget {
  const EvDateField({super.key, required this.value, required this.onChanged, this.label, this.hint, this.allowClear = true});

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final bool allowClear;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = parseYmd(value.length >= 10 ? value.substring(0, 10) : value) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) onChanged(DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final display = value.isEmpty ? '' : fmtIsoDateToDisplay(value);
    final field = InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: allowClear && value.isNotEmpty
              ? IconButton(icon: Icon(Icons.close, size: 16, color: t.mutedForeground), onPressed: () => onChanged(''))
              : Icon(Icons.calendar_today_outlined, size: 16, color: t.mutedForeground),
        ),
        child: Text(
          display.isEmpty ? (hint ?? 'dd/mm/yyyy') : display,
          style: TextStyle(fontSize: 14, color: display.isEmpty ? t.mutedForeground : t.foreground),
        ),
      ),
    );
    if (label == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [FieldLabel(label!), field]);
  }
}

/// `<input type="time">` → `HH:mm` ('' when cleared).
class EvTimeField extends StatelessWidget {
  const EvTimeField({super.key, required this.value, required this.onChanged, this.label});

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;

  Future<void> _pick(BuildContext context) async {
    TimeOfDay initial = TimeOfDay.now();
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (m != null) initial = TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: value.isNotEmpty
              ? IconButton(icon: Icon(Icons.close, size: 16, color: t.mutedForeground), onPressed: () => onChanged(''))
              : Icon(Icons.schedule, size: 16, color: t.mutedForeground),
        ),
        child: Text(
          value.isEmpty ? '--:--' : value,
          style: TextStyle(fontSize: 14, color: value.isEmpty ? t.mutedForeground : t.foreground),
        ),
      ),
    );
    if (label == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [FieldLabel(label!), field]);
  }
}

/// What a file input accepts (web `accept=`).
enum AttachKind { image, pdf, audio, docs }

const _imageExt = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'];
const _audioExt = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'amr'];
const _docExt = ['doc', 'docx', 'xls', 'xlsx', 'csv'];

/// Camera / gallery / files chooser. Returns the picked files (bytes loaded).
Future<List<PickedAttachment>> pickAttachments(
  BuildContext context, {
  required Set<AttachKind> kinds,
  bool multiple = false,
}) async {
  final allowImages = kinds.contains(AttachKind.image);
  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowImages)
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(ctx.ev('att.camera')), onTap: () => Navigator.pop(ctx, 'camera')),
          if (allowImages)
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(ctx.ev('att.gallery')), onTap: () => Navigator.pop(ctx, 'gallery')),
          ListTile(leading: const Icon(Icons.attach_file), title: Text(ctx.ev('att.files')), onTap: () => Navigator.pop(ctx, 'files')),
        ],
      ),
    ),
  );
  if (source == null) return const [];
  try {
    if (source == 'camera' || source == 'gallery') {
      final picker = ImagePicker();
      final files = <XFile>[];
      if (source == 'camera') {
        final f = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
        if (f != null) files.add(f);
      } else if (multiple) {
        files.addAll(await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80));
      } else {
        final f = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
        if (f != null) files.add(f);
      }
      final out = <PickedAttachment>[];
      for (final f in files) {
        final bytes = await f.readAsBytes();
        out.add(PickedAttachment(name: f.name, bytes: bytes, mimeType: f.mimeType ?? mimeTypeForFileName(f.name)));
      }
      return out;
    }
    final ext = <String>[
      if (allowImages) ..._imageExt,
      if (kinds.contains(AttachKind.pdf)) 'pdf',
      if (kinds.contains(AttachKind.audio)) ..._audioExt,
      if (kinds.contains(AttachKind.docs)) ..._docExt,
    ];
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext, allowMultiple: multiple);
    if (res == null) return const [];
    final out = <PickedAttachment>[];
    for (final f in res.files) {
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        if (f.size > EventsStorage.maxBytes * 4) {
          // Too large to bother loading; keep a stub so the caller can show the size error.
          bytes = Uint8List(EventsStorage.maxBytes + 1);
        } else {
          bytes = await File(f.path!).readAsBytes();
        }
      }
      if (bytes == null) continue;
      out.add(PickedAttachment(name: f.name, bytes: bytes, mimeType: mimeTypeForFileName(f.name)));
    }
    return out;
  } catch (e) {
    if (context.mounted) AppFeedback.toast(context, '${context.ev('att.failed')}: $e', tone: BadgeTone.alert);
    return const [];
  }
}

/// File input replacement: "Choose file" + chosen file chip.
class EvAttachmentField extends StatelessWidget {
  const EvAttachmentField({
    super.key,
    required this.file,
    required this.onChanged,
    required this.kinds,
    this.label,
  });

  final PickedAttachment? file;
  final ValueChanged<PickedAttachment?> onChanged;
  final Set<AttachKind> kinds;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[EvTinyLabel(label!), const SizedBox(height: 4)],
        Row(
          children: [
            EvOutlineButton(
              icon: Icons.upload_file,
              label: context.ev('att.choose'),
              onTap: () async {
                final picked = await pickAttachments(context, kinds: kinds);
                if (picked.isNotEmpty) onChanged(picked.first);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: file == null
                  ? Text(context.ev('att.none'), style: TextStyle(fontSize: 11, color: t.mutedForeground))
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${file!.name} · ${(file!.size / 1024).toStringAsFixed(0)} KB',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: t.foreground),
                          ),
                        ),
                        InkWell(onTap: () => onChanged(null), child: Icon(Icons.close, size: 16, color: t.destructive)),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Web `RecordingDateBanner`.
class RecordingDateBanner extends StatelessWidget {
  const RecordingDateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: AppTokens.tint(t.primary, 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        side: BorderSide(color: AppTokens.tint(t.primary, 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: () => AppFeedback.info(context, title: context.ev('rdb.title'), description: context.ev('rdb.desc')),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EvTinyLabel(context.ev('rdb.title')),
                    Text(
                      fmtIsoDateToDisplay(todayRecordingDate()),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.info_outline, size: 14, color: t.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display label for a stored payment method (raw value when unknown).
String paymentMethodLabel(BuildContext context, String? method) {
  final m = (method ?? '').trim();
  return switch (m) {
    'cash' => context.ev('pm.cash'),
    'upi' => context.ev('pm.upi'),
    'bank_transfer' => context.ev('pm.bank_transfer'),
    'cheque' => context.ev('pm.cheque'),
    'other' => context.ev('pm.other'),
    _ => m,
  };
}

/// Display label for `service_kind`.
String serviceKindLabel(BuildContext context, String? kind) {
  final k = kind ?? '';
  return switch (k) {
    'one_time' || '' => context.ev('sk.one_time'),
    'recurring' => context.ev('sk.recurring'),
    'temporary' => context.ev('sk.temporary'),
    _ => k[0].toUpperCase() + k.substring(1),
  };
}

/// Status text of events / campaigns (raw value when unknown).
String recordStatusLabel(BuildContext context, String status) {
  final key = 'st.$status';
  final v = context.ev(key);
  return v == key ? status : v;
}

/// `2 adults, 1 kid` (web pluralisation).
String peopleText(BuildContext context, int adults, int kids) =>
    '$adults ${context.ev(adults == 1 ? 'evc.adult' : 'evc.adults')}, $kids ${context.ev(kids == 1 ? 'evc.kid' : 'evc.kids')}';

ContribLabelWords contribWords(BuildContext context) => ContribLabelWords(
      flat: context.ev('evc.flat'),
      noFlat: context.ev('evc.noFlat'),
      receipt: context.ev('evc.receipt'),
      headcount: context.ev('evc.tagHeadcount'),
      lump: context.ev('evc.tagLump'),
      individual: context.ev('evc.tagIndividual'),
      receiptNoFlat: context.ev('evc.receiptNoFlat'),
    );

/// Lets a parent module reload every section (pull-to-refresh / `onRecordsChanged`).
class EvReloadHub {
  final Map<Object, Future<void> Function()> _loaders = {};

  void register(Object owner, Future<void> Function() loader) => _loaders[owner] = loader;
  void unregister(Object owner) => _loaders.remove(owner);

  /// Reloads all registered sections except [except] (the caller already reloaded itself).
  Future<void> reloadAll({Object? except}) async {
    await Future.wait([
      for (final e in _loaders.entries)
        if (!identical(e.key, except)) e.value().catchError((_) {}),
    ]);
  }
}
