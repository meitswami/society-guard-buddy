import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/notification_compose.dart';
import '../data/notification_media_storage.dart';
import '../data/settings_repository.dart';
import '../data/society_settings_logic.dart';

/// Port of the "Dashboard login banners" card in web `SettingsPage`
/// (`society_dashboard_banners`: image data URL, title, active, sort order).
class BannersPanel extends StatefulWidget {
  const BannersPanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<BannersPanel> createState() => _BannersPanelState();
}

class _BannersPanelState extends State<BannersPanel> {
  final _repo = const SettingsRepository();
  final _newTitle = TextEditingController();
  List<Map<String, dynamic>> _banners = const [];
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newTitle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await _repo.loadBanners(widget.societyId);
      if (mounted) setState(() => _banners = b);
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _add() async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
      return;
    }
    if (x == null) return;
    setState(() => _adding = true);
    try {
      final bytes = await x.readAsBytes();
      final mime =
          guessContentType(x.name, mimeType: x.mimeType) ?? 'image/jpeg';
      final url = 'data:$mime;base64,${base64Encode(bytes)}';
      final title = _newTitle.text.trim();
      await _repo.addBanner(
        societyId: widget.societyId,
        imageUrl: url,
        title: title.isEmpty ? null : title,
        sortOrder: nextBannerSortOrder(_banners),
      );
      if (!mounted) return;
      AppFeedback.toast(context, context.t('settings.bannerAdded'),
          tone: BadgeTone.success);
      _newTitle.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(String id) async {
    final ok = await AppFeedback.confirm(context,
        title: context.ct('comms.settings.removeBannerConfirm'),
        destructive: true);
    if (!ok || !mounted) return;
    try {
      await _repo.deleteBanner(widget.societyId, id);
      if (!mounted) return;
      AppFeedback.toast(context, context.t('settings.bannerRemoved'),
          tone: BadgeTone.success);
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _saveTitle(String id, String title) async {
    try {
      await _repo.updateBanner(widget.societyId, id,
          {'title': title.trim().isEmpty ? null : title.trim()});
      if (!mounted) return;
      AppFeedback.toast(context, context.t('settings.bannerTitleSaved'),
          tone: BadgeTone.success);
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _toggle(String id, bool on) async {
    try {
      await _repo.updateBanner(widget.societyId, id, {'is_active': on});
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  Future<void> _move(int index, int dir) async {
    final other = bannerSwapIndex(index, dir, _banners.length);
    if (other == null) return;
    try {
      await _repo.swapBannerOrder(_banners[index], _banners[other]);
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = _banners.where((b) => b['is_active'] == true).length;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('settings.banners'),
              style: AppText.sectionTitle(context)),
          const SizedBox(height: 4),
          Text(context.t('settings.bannersHint'),
              style: AppText.tiny(context).copyWith(height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: AppTextField(
                      controller: _newTitle,
                      hint: context.t('settings.bannerTitlePlaceholder'),
                      caps: false)),
              const SizedBox(width: 8),
              AppButton(
                expand: false,
                icon: Icons.add_photo_alternate_outlined,
                loading: _adding,
                label: _adding
                    ? context.t('settings.bannerUploading')
                    : context.t('settings.bannerAdd'),
                onPressed: _adding ? null : _add,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              context.t('settings.bannersActiveCount',
                  {'active': active, 'total': _banners.length}),
              style: AppText.tiny(context)),
          const SizedBox(height: 8),
          if (_banners.isEmpty)
            Text(context.t('settings.bannersEmpty'),
                style: AppText.caption(context))
          else
            for (var i = 0; i < _banners.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.secondary, 0.3),
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                ),
                child: _BannerRow(
                  key: ValueKey(
                      '${_banners[i]['id']}-${_banners[i]['title'] ?? ''}'),
                  banner: _banners[i],
                  onTitle: (v) => _saveTitle(_banners[i]['id'].toString(), v),
                  onToggle: (v) => _toggle(_banners[i]['id'].toString(), v),
                  onUp: () => _move(i, -1),
                  onDown: () => _move(i, 1),
                  onRemove: () => _remove(_banners[i]['id'].toString()),
                ),
              ),
        ],
      ),
    );
  }
}

class _BannerRow extends StatefulWidget {
  const _BannerRow({
    super.key,
    required this.banner,
    required this.onTitle,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final Map<String, dynamic> banner;
  final ValueChanged<String> onTitle;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRemove;

  @override
  State<_BannerRow> createState() => _BannerRowState();
}

class _BannerRowState extends State<_BannerRow> {
  late final TextEditingController _title =
      TextEditingController(text: widget.banner['title']?.toString() ?? '');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  void _commit() {
    final next = _title.text.trim();
    final prev = (widget.banner['title']?.toString() ?? '').trim();
    if (next != prev) widget.onTitle(next);
  }

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _image(BuildContext context) {
    final t = context.tokens;
    final url = widget.banner['image_url']?.toString() ?? '';
    Widget fallback() => Icon(Icons.image_outlined, color: t.mutedForeground);
    Widget child;
    if (url.startsWith('data:')) {
      Uint8List? bytes;
      try {
        bytes = UriData.parse(url).contentAsBytes();
      } catch (_) {}
      child = bytes == null
          ? fallback()
          : Image.memory(bytes,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback());
    } else if (url.isNotEmpty) {
      child = CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => fallback());
    } else {
      child = fallback();
    }
    return Container(
      width: 96,
      height: 56,
      decoration: BoxDecoration(
          color: t.background,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = widget.banner['is_active'] == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _image(context),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                focusNode: _focus,
                style: const TextStyle(fontSize: 12),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _focus.unfocus(),
                decoration: InputDecoration(
                    isDense: true,
                    hintText: context.t('settings.bannerTitlePlaceholder')),
              ),
              const SizedBox(height: 4),
              Text(
                  context.ct('comms.settings.order',
                      {'n': widget.banner['sort_order'] ?? 0}),
                  style: AppText.tiny(context)),
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 28,
                    child: Checkbox(
                        value: active,
                        onChanged: (v) => widget.onToggle(v ?? false),
                        visualDensity: VisualDensity.compact),
                  ),
                  Text(context.t('settings.bannerActive'),
                      style: AppText.tiny(context)),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.ct('comms.settings.moveUp'),
              icon: Icon(Icons.keyboard_arrow_up,
                  size: 18, color: t.mutedForeground),
              onPressed: widget.onUp,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.ct('comms.settings.moveDown'),
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 18, color: t.mutedForeground),
              onPressed: widget.onDown,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.ct('comms.settings.remove'),
              icon: Icon(Icons.delete_outline, size: 18, color: t.destructive),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ],
    );
  }
}
