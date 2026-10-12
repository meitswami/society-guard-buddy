import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/supabase/db.dart';
import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/society_document_repository.dart';
import '../logic/document_logic.dart';
import '../logic/meeting_logic.dart' show mimeFromFileName;
import '../models/society_document_models.dart';
import '../widgets/gov_widgets.dart';
import '../widgets/protected_document_viewer.dart';

/// Port of web `SocietyDocumentsManager.tsx` (admin + resident).
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    required this.societyId,
    required this.isResident,
    this.adminName,
    this.viewerLabel,
  });

  final String societyId;
  final bool isResident;
  final String? adminName;
  final String? viewerLabel;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late final SocietyDocumentRepository _repo =
      SocietyDocumentRepository(widget.societyId);
  List<SocietyDocumentRow> _docs = const [];
  bool _loading = true;
  SocietyDocCategory? _filter;
  bool _showUpload = false;
  bool _uploading = false;
  final _title = TextEditingController();
  final _description = TextEditingController();
  SocietyDocCategory _newCategory = SocietyDocCategory.other;
  final Map<String, String> _thumbUrls = {};
  String? _openingId;
  DateTime _now = DateTime.now();
  Timer? _clock;
  RealtimeChannel? _channel;
  String? _viewerDocId;
  final ValueNotifier<String?> _viewerReveal = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _load();
    if (dbReady) {
      _channel = _repo.subscribeUpdates((row) {
        if (!mounted) return;
        final id = '${row['id']}';
        setState(() =>
            _docs = [for (final d in _docs) d.id == id ? d.merge(row) : d]);
        if (_viewerDocId == id && row.containsKey('member_reveal_until')) {
          _viewerReveal.value = row['member_reveal_until'] as String?;
        }
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    final ch = _channel;
    if (ch != null) unawaited(db.removeChannel(ch));
    _title.dispose();
    _description.dispose();
    _viewerReveal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await _repo.load(residentOnly: widget.isResident);
      if (!mounted) return;
      setState(() => _docs = docs);
      if (widget.isResident) unawaited(_loadThumbs(docs));
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadThumbs(List<SocietyDocumentRow> docs) async {
    final images = docs.where((d) => d.isImage).toList();
    if (images.isEmpty) return;
    final entries = await Future.wait(images.map((d) async {
      try {
        return MapEntry(d.id, await _repo.signedUrl(d.storagePath, 300));
      } catch (_) {
        return null;
      }
    }));
    if (!mounted) return;
    setState(() {
      _thumbUrls
        ..clear()
        ..addEntries(entries.whereType<MapEntry<String, String>>());
    });
  }

  bool get _hi => context.lang == AppLang.hi;

  List<SocietyDocumentRow> get _filtered => _filter == null
      ? _docs
      : _docs.where((d) => d.category == _filter).toList();

  Future<void> _openViewer(SocietyDocumentRow doc,
      {required bool protectedView}) async {
    setState(() => _openingId = doc.id);
    try {
      if (!protectedView && !widget.isResident) {
        // Admin preview: in-app view without blur.
        _viewerDocId = doc.id;
        _viewerReveal.value = doc.memberRevealUntil;
        await ProtectedDocumentViewer.open(
          context,
          title: doc.title,
          loadBytes: () => _repo.download(doc.storagePath),
          fileName: doc.fileName,
          mimeType: doc.mimeType,
          watermark: widget.viewerLabel ??
              context.tr('Society document', 'सोसायटी दस्तावेज़'),
        );
        return;
      }
      _viewerDocId = doc.id;
      _viewerReveal.value = doc.memberRevealUntil;
      await ProtectedDocumentViewer.open(
        context,
        title: doc.title,
        loadBytes: () => _repo.download(doc.storagePath),
        fileName: doc.fileName,
        mimeType: doc.mimeType,
        watermark: widget.viewerLabel ??
            context.tr('Society document', 'सोसायटी दस्तावेज़'),
        revealUntil: _viewerReveal,
        protectedForMember: widget.isResident,
      );
    } catch (e) {
      if (mounted) {
        GovToast.error(context,
            context.tr('Could not open document', 'दस्तावेज़ नहीं खुल सका'));
      }
    } finally {
      _viewerDocId = null;
      if (mounted) setState(() => _openingId = null);
    }
  }

  /// Admin download: signed URL (1 h) opened outside the app like the web new tab.
  Future<void> _download(SocietyDocumentRow doc) async {
    setState(() => _openingId = doc.id);
    try {
      final url = await _repo.signedUrl(doc.storagePath, 3600);
      await ExportKit.openUrl(url);
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_title.text.trim().isEmpty) {
      GovToast.error(
          context,
          context.tr(
              'Enter a document title', 'दस्तावेज़ का शीर्षक दर्ज करें'));
      return;
    }
    final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: societyDocExtensions,
        withData: true);
    final file = res?.files.firstOrNull;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      GovToast.error(context,
          context.tr('Could not read the file', 'फ़ाइल पढ़ी नहीं जा सकी'));
      return;
    }
    final mime = mimeFromFileName(file.name);
    final err = validateSocietyDocUpload(
        title: _title.text, mimeType: mime, size: bytes.length);
    if (err != null) {
      GovToast.error(context, _hi ? err.$2 : err.$1);
      return;
    }
    setState(() => _uploading = true);
    try {
      await _repo.upload(
        title: _title.text,
        description: _description.text,
        category: _newCategory,
        bytes: bytes,
        fileName: file.name,
        mimeType: mime,
        sortOrder: _docs.length,
        uploadedBy: widget.adminName,
      );
      if (!mounted) return;
      GovToast.ok(
          context, context.tr('Document uploaded', 'दस्तावेज़ अपलोड हुआ'));
      _title.clear();
      _description.clear();
      setState(() {
        _newCategory = SocietyDocCategory.other;
        _showUpload = false;
      });
      await _load();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _togglePublished(SocietyDocumentRow doc) async {
    final next = !doc.published;
    try {
      await _repo.setPublished(doc, next);
      if (!mounted) return;
      GovToast.ok(
        context,
        next
            ? context.tr(
                'Visible to members (blurred)', 'सदस्यों को दिखेगा (धुंधला)')
            : context.tr('Hidden from members', 'सदस्यों से छिपाया गया'),
      );
      await _load();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Future<void> _reveal(SocietyDocumentRow doc, int seconds) async {
    if (!doc.published) {
      GovToast.error(
          context,
          context.tr('Publish the document for members first',
              'पहले दस्तावेज़ सदस्यों के लिए प्रकाशित करें'));
      return;
    }
    final until = DateTime.now()
        .add(Duration(seconds: seconds))
        .toUtc()
        .toIso8601String();
    try {
      await _repo.setRevealUntil(doc.id, until);
      if (!mounted) return;
      setState(() => _docs = [
            for (final d in _docs)
              d.id == doc.id ? d.merge({'member_reveal_until': until}) : d
          ]);
      GovToast.ok(
        context,
        seconds < 60
            ? context.tr('Members can view clearly for $seconds seconds',
                'सदस्य $seconds सेकंड तक स्पष्ट देख सकते हैं')
            : context.tr('Members can view clearly for 1 minute',
                'सदस्य 1 मिनट तक स्पष्ट देख सकते हैं'),
      );
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Future<void> _hideNow(SocietyDocumentRow doc) async {
    try {
      await _repo.setRevealUntil(doc.id, null);
      if (!mounted) return;
      setState(() => _docs = [
            for (final d in _docs)
              d.id == doc.id ? d.merge({'member_reveal_until': null}) : d
          ]);
      GovToast.ok(
          context,
          context.tr('Member viewing disabled — content blurred again',
              'सदस्य दृश्य बंद — सामग्री फिर धुंधली'));
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Future<void> _delete(SocietyDocumentRow doc) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Delete document?', 'दस्तावेज़ हटाएँ?'),
      message: context.tr('"${doc.title}" will be removed permanently.',
          '"${doc.title}" स्थायी रूप से हटा दिया जाएगा।'),
      confirmLabel: context.tr('Delete', 'हटाएँ'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final storageErr = await _repo.delete(doc);
      if (!mounted) return;
      if (storageErr != null) GovToast.error(context, storageErr);
      GovToast.ok(
          context, context.tr('Document deleted', 'दस्तावेज़ हटाया गया'));
      await _load();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Widget _uploadCard() {
    final t = context.tokens;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('NEW DOCUMENT', 'नया दस्तावेज़'),
              style: AppText.fieldLabel(context)),
          const SizedBox(height: 10),
          AppTextField(
              controller: _title,
              hint: context.tr('Title *', 'शीर्षक *'),
              caps: false),
          const SizedBox(height: 10),
          AppTextField(
            controller: _description,
            hint: context.tr('Description (optional)', 'विवरण (वैकल्पिक)'),
            maxLines: 3,
            minLines: 2,
            caps: false,
          ),
          const SizedBox(height: 10),
          AppDropdown<SocietyDocCategory>(
            items: SocietyDocCategory.values,
            value: _newCategory,
            onChanged: (v) =>
                setState(() => _newCategory = v ?? SocietyDocCategory.other),
            labelOf: (c) => c.label(_hi),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _uploading ? null : _pickAndUpload,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: SectionBox(
              dashed: true,
              children: [
                const SizedBox(height: 8),
                Icon(Icons.upload_outlined, size: 26, color: t.mutedForeground),
                const SizedBox(height: 6),
                Text(
                  context.tr('PDF or image (max 15 MB)',
                      'PDF या चित्र (अधिकतम 15 MB)'),
                  textAlign: TextAlign.center,
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (_uploading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6)),
                  const SizedBox(width: 8),
                  Text(context.tr('Uploading…', 'अपलोड हो रहा है…'),
                      style: AppText.caption(context)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    Widget pill(String label, bool on, VoidCallback tap) {
      final t = context.tokens;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? t.primary : t.card,
          shape:
              StadiumBorder(side: BorderSide(color: on ? t.primary : t.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: on ? t.primaryForeground : t.foreground)),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          pill(context.tr('All', 'सभी'), _filter == null,
              () => setState(() => _filter = null)),
          for (final c in SocietyDocCategory.values)
            pill(c.label(_hi), _filter == c, () => setState(() => _filter = c)),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String tip, VoidCallback? onTap,
      {Color? fg, Color? bg, bool busy = false}) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: tip,
        child: Material(
          color: bg ?? t.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: fg ?? t.foreground))
                  : Icon(icon, size: 16, color: fg ?? t.foreground),
            ),
          ),
        ),
      ),
    );
  }

  Widget _docCard(SocietyDocumentRow doc) {
    final t = context.tokens;
    final reveal = doc.revealActive(_now);
    final left = doc.secondsLeft(_now);
    final thumb = _thumbUrls[doc.id];
    final status = <InlineSpan>[TextSpan(text: Fmt.date(doc.createdAt))];
    void add(String s, Color c) =>
        status.add(TextSpan(text: '  $s', style: TextStyle(color: c)));
    if (!widget.isResident) {
      add(
          doc.published
              ? context.tr('· Listed for members', '· सदस्यों हेतु सूचीबद्ध')
              : context.tr('· Hidden', '· छिपा'),
          doc.published ? t.success : t.warning);
      if (reveal) {
        add(
            context.tr(
                '· Viewing enabled (${left}s)', '· देखना सक्षम ($left से.)'),
            t.accent);
      }
    } else {
      if (reveal) {
        add(context.tr('· Clear view (${left}s)', '· स्पष्ट दृश्य ($left से.)'),
            t.accent);
      } else {
        add(context.tr('· Blurred preview', '· धुंधला पूर्वावलोकन'), t.warning);
      }
    }

    final thumbBox = ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Container(
        width: 48,
        height: 48,
        color: t.muted,
        child: widget.isResident && doc.isImage && thumb != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                        sigmaX: reveal ? 0 : 8, sigmaY: reveal ? 0 : 8),
                    child:
                        CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
                  ),
                  if (!reveal)
                    ColoredBox(
                      color: AppTokens.tint(t.background, 0.3),
                      child: Icon(Icons.lock_outline,
                          size: 14, color: t.mutedForeground),
                    ),
                ],
              )
            : Icon(Icons.description_outlined, size: 18, color: t.primary),
      ),
    );

    return CardSection(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thumbBox,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMedium(context)),
                if ((doc.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(doc.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(context)),
                  ),
                const SizedBox(height: 4),
                Text.rich(TextSpan(children: status),
                    style: AppText.tiny(context)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _actionIcon(
                Icons.visibility_outlined,
                widget.isResident
                    ? context.tr('View', 'देखें')
                    : context.tr('Preview', 'पूर्वावलोकन'),
                () => _openViewer(doc, protectedView: widget.isResident),
                fg: t.primary,
                bg: AppTokens.tint(t.primary, 0.1),
                busy: _openingId == doc.id,
              ),
              if (!widget.isResident) ...[
                _actionIcon(Icons.download_outlined,
                    context.tr('Download', 'डाउनलोड'), () => _download(doc)),
                _actionIcon(
                  doc.published
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  doc.published
                      ? context.tr('Hide from members', 'सदस्यों से छिपाएँ')
                      : context.tr('Show to members (blurred)',
                          'सदस्यों को दिखाएँ (धुंधला)'),
                  () => _togglePublished(doc),
                ),
                PopupMenuButton<int>(
                  tooltip: context.tr('Enable clear viewing for members',
                      'सदस्यों के लिए स्पष्ट दृश्य सक्षम करें'),
                  onSelected: (v) => v < 0 ? _hideNow(doc) : _reveal(doc, v),
                  itemBuilder: (_) => [
                    for (final d in revealDurations)
                      PopupMenuItem(
                          value: d.seconds,
                          child: Text(_hi ? d.labelHi : d.labelEn)),
                    if (reveal)
                      PopupMenuItem(
                        value: -1,
                        child: Text(context.tr('Hide now', 'अभी छिपाएँ'),
                            style: TextStyle(color: t.destructive)),
                      ),
                  ],
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: reveal ? AppTokens.tint(t.accent, 0.15) : t.muted,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: Icon(Icons.timer_outlined,
                        size: 16, color: reveal ? t.accent : t.foreground),
                  ),
                ),
                _actionIcon(Icons.delete_outline, context.tr('Delete', 'हटाएँ'),
                    () => _delete(doc),
                    fg: t.destructive, bg: AppTokens.tint(t.destructive, 0.1)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filtered = _filtered;
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          icon: Icons.folder_open_outlined,
          title: context.tr('Society documents', 'सोसायटी दस्तावेज़'),
          subtitle: widget.isResident
              ? context.tr(
                  'Official society records — previews stay blurred until your office enables viewing',
                  'सोसायटी के आधिकारिक अभिलेख — कार्यालय द्वारा अनुमति तक पूर्वावलोकन धुंधले रहते हैं')
              : context.tr(
                  'Upload documents for members. They always see blurred previews until you enable viewing.',
                  'सदस्यों के लिए दस्तावेज़ अपलोड करें। आपके सक्षम करने तक उन्हें धुंधला पूर्वावलोकन दिखेगा।'),
          actions: [
            if (!widget.isResident)
              MiniButton(
                label: _showUpload
                    ? context.tr('Close', 'बंद')
                    : context.tr('Add', 'जोड़ें'),
                icon: _showUpload ? Icons.close : Icons.add,
                variant: MiniVariant.primary,
                onPressed: () => setState(() => _showUpload = !_showUpload),
              ),
          ],
        ),
        if (!widget.isResident && _showUpload) _uploadCard(),
        _filterBar(),
        const SizedBox(height: 12),
        if (_loading)
          LoadingView(
              message:
                  context.tr('Loading documents…', 'दस्तावेज़ लोड हो रहे हैं…'))
        else if (filtered.isEmpty)
          CardSection(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.description_outlined,
                    size: 40, color: AppTokens.tint(t.mutedForeground, 0.4)),
                const SizedBox(height: 12),
                Text(
                  widget.isResident
                      ? context.tr('No documents published yet.',
                          'अभी कोई दस्तावेज़ प्रकाशित नहीं।')
                      : context.tr(
                          'No documents yet. Upload the first one above.',
                          'अभी कोई दस्तावेज़ नहीं। ऊपर पहला अपलोड करें।'),
                  textAlign: TextAlign.center,
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground),
                ),
              ],
            ),
          )
        else
          for (final cat in SocietyDocCategory.values)
            if (filtered.any((d) => d.category == cat)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(cat.label(_hi).toUpperCase(),
                    style: AppText.fieldLabel(context)),
              ),
              for (final d in filtered.where((d) => d.category == cat))
                _docCard(d),
              const SizedBox(height: 12),
            ],
      ],
    );
  }
}
