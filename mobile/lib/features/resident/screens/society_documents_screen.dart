import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';
import '../../../models/society_document.dart';
import '../../../services/society_document_service.dart';

class SocietyDocumentsScreen extends StatefulWidget {
  const SocietyDocumentsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<SocietyDocumentsScreen> createState() => _SocietyDocumentsScreenState();
}

class _SocietyDocumentsScreenState extends State<SocietyDocumentsScreen> {
  final _service = SocietyDocumentService();
  List<SocietyDocument> _docs = const [];
  bool _loading = true;
  String _categoryFilter = 'all';
  final Map<String, String> _thumbUrls = {};
  Timer? _clock;
  DateTime _now = DateTime.now();
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_channel != null) {
      unawaited(SupabaseBootstrap.client.removeChannel(_channel!));
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    final societyId = widget.session.societyId;
    _channel = SupabaseBootstrap.client
        .channel('society-docs-$societyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'society_documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'society_id',
            value: societyId,
          ),
          callback: (payload) {
            final updated = SocietyDocument.fromRow(Map<String, dynamic>.from(payload.newRecord));
            if (!mounted) return;
            setState(() {
              _docs = _docs.map((d) => d.id == updated.id ? updated : d).toList();
            });
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchPublished(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _docs = rows;
      _loading = false;
    });
    await _loadThumbs(rows);
  }

  Future<void> _loadThumbs(List<SocietyDocument> docs) async {
    final imageDocs = docs.where((d) => d.isImage).toList();
    if (imageDocs.isEmpty) return;

    final entries = await Future.wait(
      imageDocs.map((doc) async {
        final url = await _service.createSignedUrl(doc.storagePath);
        return url == null ? null : MapEntry(doc.id, url);
      }),
    );

    if (!mounted) return;
    setState(() {
      _thumbUrls
        ..clear()
        ..addEntries(entries.whereType<MapEntry<String, String>>());
    });
  }

  List<SocietyDocument> get _filtered {
    if (_categoryFilter == 'all') return _docs;
    return _docs.where((d) => d.category == _categoryFilter).toList();
  }

  Map<String, List<SocietyDocument>> get _grouped {
    final map = <String, List<SocietyDocument>>{};
    for (final doc in _filtered) {
      map.putIfAbsent(doc.category, () => []).add(doc);
    }
    return map;
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Future<void> _openDocument(SocietyDocument doc) async {
    final revealActive = doc.isRevealActive(_now);
    final url = await _service.createSignedUrl(doc.storagePath);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
      );
      return;
    }

    if (doc.isImage) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _ProtectedDocumentDialog(
          title: doc.title,
          watermark: '${widget.session.resident.flatNumber} · ${widget.session.resident.name}',
          imageUrl: url,
          blurred: !revealActive,
          secondsLeft: revealActive ? doc.revealSecondsLeft(_now) : null,
        ),
      );
      return;
    }

    if (doc.isPdf) {
      if (!revealActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document is blurred — office must enable clear viewing first'),
          ),
        );
        return;
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PDF')),
        );
      }
      return;
    }

    if (!revealActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clear viewing is not enabled for this document')),
      );
      return;
    }
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final categories = ['all', ...societyDocumentCategories.keys];

    return Scaffold(
      appBar: AppBar(title: const Text('Society documents')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Official society records — previews stay blurred until your office enables viewing.',
              style: TextStyle(fontSize: 12, color: KutumbikaColors.textMuted.withValues(alpha: 0.9)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final id = categories[index];
                final selected = _categoryFilter == id;
                final label = id == 'all' ? 'All' : (societyDocumentCategories[id] ?? id);
                return FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => setState(() => _categoryFilter = id),
                  selectedColor: brand.primary.withValues(alpha: 0.15),
                  checkmarkColor: brand.primary,
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No documents published yet',
                                  style: TextStyle(color: KutumbikaColors.textMuted),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              for (final entry in _grouped.entries) ...[
                                Text(
                                  societyDocumentCategories[entry.key] ?? entry.key,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: KutumbikaColors.textMuted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...entry.value.map((doc) {
                                  final revealActive = doc.isRevealActive(_now);
                                  final thumb = _thumbUrls[doc.id];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      onTap: () => _openDocument(doc),
                                      leading: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: doc.isImage && thumb != null
                                              ? Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    ImageFiltered(
                                                      imageFilter: ImageFilter.blur(
                                                        sigmaX: revealActive ? 0 : 10,
                                                        sigmaY: revealActive ? 0 : 10,
                                                      ),
                                                      child: CachedNetworkImage(
                                                        imageUrl: thumb,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    if (!revealActive)
                                                      Container(
                                                        color: Colors.black26,
                                                        child: const Icon(Icons.lock, size: 16, color: Colors.white),
                                                      ),
                                                  ],
                                                )
                                              : ColoredBox(
                                                  color: brand.primary.withValues(alpha: 0.1),
                                                  child: Icon(Icons.description_outlined, color: brand.primary),
                                                ),
                                        ),
                                      ),
                                      title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (doc.description != null && doc.description!.isNotEmpty)
                                            Text(doc.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_formatDate(doc.createdAt)} · ${revealActive ? 'Clear view (${doc.revealSecondsLeft(_now)}s)' : 'Blurred preview'}',
                                            style: TextStyle(fontSize: 11, color: brand.primary.withValues(alpha: 0.8)),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProtectedDocumentDialog extends StatelessWidget {
  const _ProtectedDocumentDialog({
    required this.title,
    required this.watermark,
    required this.imageUrl,
    required this.blurred,
    this.secondsLeft,
  });

  final String title;
  final String watermark;
  final String imageUrl;
  final bool blurred;
  final int? secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (secondsLeft != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Clear view · $secondsLeft s remaining',
                style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
              ),
            ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurred ? 18 : 0,
                    sigmaY: blurred ? 18 : 0,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                if (blurred)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 36),
                        SizedBox(height: 8),
                        Text('Blurred preview', style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text(
                          'Office must enable clear viewing',
                          style: TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                IgnorePointer(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Text(
                        watermark,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
