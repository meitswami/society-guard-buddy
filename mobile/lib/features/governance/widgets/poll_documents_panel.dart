import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../logic/document_logic.dart';
import '../logic/meeting_logic.dart' show mimeFromFileName, stripExtension;
import '../models/poll_models.dart';
import 'gov_widgets.dart';

/// Port of web `PollDocumentsPanel.tsx` — circulars / letters attached to a poll.
class PollDocumentsPanel extends StatefulWidget {
  const PollDocumentsPanel({
    super.key,
    required this.pollId,
    required this.repo,
    required this.isAdmin,
    required this.documents,
    required this.createdBy,
    required this.onChanged,
  });

  final String pollId;
  final PollRepository repo;
  final bool isAdmin;
  final List<PollDocumentRow> documents;
  final String createdBy;
  final VoidCallback onChanged;

  @override
  State<PollDocumentsPanel> createState() => _PollDocumentsPanelState();
}

class _PollDocumentsPanelState extends State<PollDocumentsPanel> {
  late bool _open = widget.documents.any((d) => d.pollId == widget.pollId);
  PollDocKind _kind = PollDocKind.circular;
  final _title = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<PollDocumentRow> get _mine => widget.documents.where((d) => d.pollId == widget.pollId).toList();

  Future<void> _add() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: pollDocExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    var ok = 0;
    final base = _mine.length;
    for (final (i, f) in res.files.indexed) {
      if (f.bytes == null) continue;
      final saved = await widget.repo.uploadPollDocument(
        pollId: widget.pollId,
        bytes: f.bytes!,
        fileName: f.name,
        mimeType: mimeFromFileName(f.name),
        title: _title.text.trim().isEmpty ? stripExtension(f.name) : _title.text.trim(),
        docKind: _kind.value,
        createdBy: widget.createdBy,
        sortOrder: base + i,
      );
      if (saved) ok += 1;
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    _title.clear();
    if (ok > 0) {
      GovToast.ok(context, context.tr('$ok document(s) added', '$ok दस्तावेज़ जोड़े गए'));
      setState(() => _open = true);
      widget.onChanged();
    } else {
      GovToast.error(context, context.tr('Could not upload document(s)', 'दस्तावेज़ अपलोड नहीं हो सके'));
    }
  }

  Future<void> _remove(PollDocumentRow doc) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Remove document?', 'दस्तावेज़ हटाएँ?'),
      message: doc.title,
      confirmLabel: context.tr('Remove', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await widget.repo.deletePollDocument(doc.id);
      if (!mounted) return;
      GovToast.ok(context, context.tr('Document removed', 'दस्तावेज़ हटाया गया'));
      widget.onChanged();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hi = context.lang == AppLang.hi;
    final mine = _mine;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 14, color: t.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${context.tr('Documents', 'दस्तावेज़')}${mine.isNotEmpty ? ' (${mine.length})' : ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                Text(_open ? '▾' : '▸', style: AppText.caption(context)),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            if (mine.isEmpty)
              Text(
                widget.isAdmin
                    ? context.tr('Attach circulars, letters, or other documents members can open with this poll.',
                        'परिपत्र, पत्र या अन्य दस्तावेज़ संलग्न करें जिन्हें सदस्य इस मतदान के साथ खोल सकें।')
                    : context.tr('No documents attached.', 'कोई दस्तावेज़ संलग्न नहीं।'),
                style: AppText.tiny(context).copyWith(fontSize: 11),
              ),
            for (final doc in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 12, color: t.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => ExportKit.openUrl(doc.fileUrl),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: doc.title, style: TextStyle(color: t.primary)),
                            TextSpan(text: ' · ${pollDocKindLabel(doc.docKind, hi: hi)}', style: AppText.tiny(context)),
                          ]),
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (widget.isAdmin)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _remove(doc),
                        icon: Icon(Icons.delete_outline, size: 16, color: t.destructive),
                      ),
                  ],
                ),
              ),
            if (widget.isAdmin)
              SectionBox(
                dashed: true,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppDropdown<PollDocKind>(
                          label: context.tr('Type', 'प्रकार'),
                          items: PollDocKind.values,
                          value: _kind,
                          labelOf: (k) => k.label(hi),
                          onChanged: (v) => setState(() => _kind = v ?? PollDocKind.circular),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTextField(
                          controller: _title,
                          label: context.tr('Title (optional)', 'शीर्षक (वैकल्पिक)'),
                          hint: context.tr('e.g. Election circular', 'जैसे चुनाव परिपत्र'),
                          caps: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MiniButton(
                      label: _uploading ? context.tr('Uploading…', 'अपलोड हो रहा है…') : context.tr('Add document(s)', 'दस्तावेज़ जोड़ें'),
                      icon: Icons.attach_file,
                      busy: _uploading,
                      onPressed: _add,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
