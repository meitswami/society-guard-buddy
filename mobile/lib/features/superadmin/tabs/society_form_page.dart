import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import '../data/image_upload.dart';
import '../data/superadmin_models.dart';
import '../logic/society_form.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/sa_widgets.dart';

/// New / edit society form — the web inline `showSocietyForm` card of the Societies tab,
/// with building & site, flat numbering (trim + generate on save, reset flats), photos,
/// branding & contact and report letterhead.
class SocietyFormPage extends StatefulWidget {
  const SocietyFormPage({super.key, required this.console, this.society});

  final SuperadminConsole console;

  /// `null` → new society.
  final SocietyRow? society;

  static Future<bool?> open(BuildContext context, SuperadminConsole console,
          {SocietyRow? society}) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
            builder: (_) =>
                SocietyFormPage(console: console, society: society)),
      );

  @override
  State<SocietyFormPage> createState() => _SocietyFormPageState();
}

class _SocietyFormPageState extends State<SocietyFormPage> {
  late final SocietyFormData _sf;
  final List<PickedImage> _pendingPhotos = [];
  PickedImage? _pendingLogo;
  PickedImage? _pendingLetterhead;
  bool _saving = false;
  bool _resetting = false;
  bool _nameError = false;

  String? get _editingId => widget.society?.id;

  @override
  void initState() {
    super.initState();
    _sf = widget.society == null
        ? emptySocietyForm()
        : societyToForm(widget.society!.formSource);
  }

  void _toast(String msg, [BadgeTone tone = BadgeTone.alert]) {
    if (mounted) {
      AppFeedback.toast(context, msg,
          tone: tone, duration: const Duration(seconds: 4));
    }
  }

  Future<ImageSource?> _askSource() => showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(ctx.st('sa.pick.gallery')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(ctx.st('sa.pick.camera')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickPhotos() async {
    final source = await _askSource();
    if (source == null) return;
    List<PickedImage> files;
    try {
      files = source == ImageSource.gallery
          ? await SuperadminImagePicker.pickMany()
          : [...?await _cameraPhoto()];
    } catch (_) {
      if (mounted) _toast(context.st('sa.pick.failed'));
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() {
      for (final f in files) {
        if (_pendingPhotos.length + _sf.existingPhotoUrls.length >=
            kMaxSocietyPhotos) {
          _toast(context.t('superadmin.societyPhotosLimit'));
          break;
        }
        _pendingPhotos.add(f);
      }
    });
  }

  Future<List<PickedImage>?> _cameraPhoto() async {
    final f = await SuperadminImagePicker.pickOne(
        source: ImageSource.camera, maxSide: 2048, quality: 88);
    return f == null ? null : [f];
  }

  Future<PickedImage?> _pickSingle({double? maxSide}) async {
    final source = await _askSource();
    if (source == null) return null;
    try {
      return await SuperadminImagePicker.pickOne(
          source: source,
          maxSide: source == ImageSource.camera ? (maxSide ?? 2048) : maxSide,
          quality: source == ImageSource.camera ? 90 : null);
    } catch (_) {
      if (mounted) _toast(context.st('sa.pick.failed'));
      return null;
    }
  }

  Future<void> _save() async {
    if (_sf.name.trim().isEmpty) {
      setState(() => _nameError = true);
      _toast(context.st('sa.societies.nameRequired'));
      return;
    }
    final baseRow = buildSocietyBaseRow(_sf);
    if (_sf.existingPhotoUrls.length + _pendingPhotos.length >
        kMaxSocietyPhotos) {
      _toast(context.t('superadmin.societyPhotosLimit'));
      return;
    }
    final repo = widget.console.repo;
    final uploads = SuperadminUploads(onError: _toast);
    String? logoUrl = baseRow['logo_url'] as String?;
    String? letterheadUrl = baseRow['letterhead_url'] as String?;
    final layout = layoutFromForm(_sf);
    final msgUpdated = context.t('superadmin.societyUpdated');
    final msgAdded = context.t('superadmin.societyAdded');
    final msgTrimmed = context.t('superadmin.flatsTrimmed');
    final msgGenerated = context.t('superadmin.flatsGenerated');
    final msgFailed = context.t('superadmin.societySaveFailed');

    setState(() => _saving = true);
    try {
      String societyId;
      final editingId = _editingId;
      if (editingId != null) {
        societyId = editingId;
        if (_pendingLogo != null) {
          logoUrl =
              await uploads.societyLogo(editingId, _pendingLogo!) ?? logoUrl;
        }
        if (_pendingLetterhead != null) {
          letterheadUrl =
              await uploads.societyLetterhead(editingId, _pendingLetterhead!) ??
                  letterheadUrl;
        }
        var photoUrls = [..._sf.existingPhotoUrls];
        if (_pendingPhotos.isNotEmpty) {
          photoUrls = [
            ...photoUrls,
            ...await uploads.societyPhotos(editingId, _pendingPhotos)
          ];
        }
        await repo.updateSociety(editingId, {
          ...baseRow,
          'logo_url': logoUrl,
          'letterhead_url': letterheadUrl,
          'photo_urls': photoUrls,
        });
        _toast(msgUpdated, BadgeTone.success);
      } else {
        societyId =
            await repo.insertSociety({...baseRow, 'photo_urls': <String>[]});
        if (_pendingLogo != null) {
          logoUrl =
              await uploads.societyLogo(societyId, _pendingLogo!) ?? logoUrl;
        }
        if (_pendingLetterhead != null) {
          letterheadUrl =
              await uploads.societyLetterhead(societyId, _pendingLetterhead!) ??
                  letterheadUrl;
        }
        var photoUrls = [..._sf.existingPhotoUrls];
        if (_pendingPhotos.isNotEmpty) {
          photoUrls = [
            ...photoUrls,
            ...await uploads.societyPhotos(societyId, _pendingPhotos)
          ];
        }
        final patch = <String, dynamic>{
          if (photoUrls.isNotEmpty) 'photo_urls': photoUrls,
          if (logoUrl != null) 'logo_url': logoUrl,
          if (letterheadUrl != null) 'letterhead_url': letterheadUrl,
        };
        if (patch.isNotEmpty) await repo.updateSociety(societyId, patch);
        _toast(msgAdded, BadgeTone.success);
      }

      final trimmed = await repo.trimFlatsToConfiguredRange(societyId, layout);
      if (trimmed > 0) {
        _toast(msgTrimmed.replaceAll('{count}', '$trimmed'), BadgeTone.info);
      }

      final generated = await repo.upsertFlatsFromLayout(societyId, layout);
      if (generated.error != null) {
        _toast(generated.error!);
      } else if (generated.created > 0) {
        _toast(
          msgGenerated
              .replaceAll('{created}', '${generated.created}')
              .replaceAll('{skipped}', '${generated.skipped}'),
          BadgeTone.success,
        );
      }
      await widget.console.loadAll();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _toast(msgFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetFlats() async {
    final id = _editingId;
    if (id == null) return;
    final layout = layoutFromForm(_sf);
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('superadmin.resetFlatsConfirmTitle'),
      message: context.t('superadmin.resetFlatsConfirmText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final msgRegenerated = context.t('superadmin.flatsRegenerated');
    final msgFailed = context.t('superadmin.flatResetFailed');
    setState(() => _resetting = true);
    try {
      await widget.console.repo.deleteResidentialFlats(id);
      final generated =
          await widget.console.repo.upsertFlatsFromLayout(id, layout);
      if (generated.error != null) {
        _toast(generated.error!);
      } else {
        _toast(
          msgRegenerated
              .replaceAll('{created}', '${generated.created}')
              .replaceAll('{skipped}', '${generated.skipped}'),
          BadgeTone.success,
        );
      }
      await widget.console.loadAll();
    } catch (_) {
      _toast(msgFailed);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Widget _row2(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b)
        ],
      );

  Widget _field(String hint, String value, ValueChanged<String> onChanged,
      {TextInputType? keyboard,
      int maxLines = 1,
      IconData? icon,
      bool error = false,
      String? label}) {
    return AppTextField(
      label: label,
      hint: hint,
      initialValue: value,
      onChanged: onChanged,
      keyboardType: keyboard,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : null,
      prefixIcon: icon,
      caps: false,
      validator: error ? (_) => context.st('sa.societies.nameRequired') : null,
    );
  }

  List<Widget> _spaced(List<Widget> items, [double h = 12]) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: h),
          items[i]
        ],
      ];

  Widget _imagePreview(
      {String? url, PickedImage? pending, double w = 40, double h = 40}) {
    final t = context.tokens;
    if (pending != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: t.border)),
          child: Image.memory(pending.bytes,
              width: w, height: h, fit: BoxFit.cover),
        ),
      );
    }
    if (url != null && url.trim().isNotEmpty) {
      return SaNetImage(url.trim(), width: w, height: h);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final editing = _editingId != null;
    final busy = _saving || _resetting;
    return Scaffold(
      appBar: AppBar(
          title: Text(editing
              ? context.t('superadmin.editSociety')
              : context.t('superadmin.newSociety'))),
      body: SafeArea(
        child: PageContainer(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            CardSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spaced([
                  AppTextField(
                    hint: context.t('superadmin.societyName'),
                    label: context.t('superadmin.societyName'),
                    required: true,
                    initialValue: _sf.name,
                    caps: false,
                    onChanged: (v) => setState(() {
                      _sf.name = v;
                      if (v.trim().isNotEmpty) _nameError = false;
                    }),
                  ),
                  if (_nameError)
                    Text(context.st('sa.societies.nameRequired'),
                        style: TextStyle(fontSize: 12, color: t.destructive)),
                  _field(context.t('superadmin.address'), _sf.address,
                      (v) => _sf.address = v,
                      maxLines: 3),
                  _row2(
                    _field(context.t('superadmin.city'), _sf.city,
                        (v) => _sf.city = v),
                    _field(context.t('superadmin.state'), _sf.state,
                        (v) => _sf.state = v),
                  ),
                  _field(context.t('superadmin.pincode'), _sf.pincode,
                      (v) => _sf.pincode = v,
                      keyboard: TextInputType.number),

                  // Building & site
                  SaSubsection(
                    label: context.t('superadmin.societyBuilding'),
                    children: [
                      _row2(
                        _field(context.t('superadmin.totalFlats'),
                            _sf.totalFlats, (v) => _sf.totalFlats = v,
                            keyboard: TextInputType.number),
                        _field(context.t('superadmin.totalFloors'),
                            _sf.totalFloors, (v) => _sf.totalFloors = v,
                            keyboard: TextInputType.number),
                      ),
                      const SizedBox(height: 8),
                      _field(context.t('superadmin.blocksPlaceholder'),
                          _sf.blocksCsv, (v) => _sf.blocksCsv = v),
                      SaHint(context.t('superadmin.blocksHint')),
                      const SizedBox(height: 8),
                      TriStateField(
                        label: context.t('superadmin.terraceAccessible'),
                        value: _sf.terrace,
                        onChanged: (v) => setState(() => _sf.terrace = v),
                      ),
                      const SizedBox(height: 8),
                      TriStateField(
                        label: context.t('superadmin.basement'),
                        value: _sf.basement,
                        onChanged: (v) => setState(() {
                          _sf.basement = v;
                          if (v != TriState.yes) {
                            _sf.basementUsable = TriState.unset;
                          }
                        }),
                      ),
                      if (_sf.basement == TriState.yes) ...[
                        const SizedBox(height: 8),
                        TriStateField(
                          label: context.t('superadmin.basementUsable'),
                          value: _sf.basementUsable,
                          onChanged: (v) =>
                              setState(() => _sf.basementUsable = v),
                        ),
                      ],
                    ],
                  ),

                  // Flat numbering
                  SaSubsection(
                    label: context.t('superadmin.flatNumbering'),
                    children: [
                      _field(context.t('superadmin.flatsPerFloor'),
                          _sf.flatsPerFloor, (v) => _sf.flatsPerFloor = v,
                          keyboard: TextInputType.number),
                      const SizedBox(height: 8),
                      _row2(
                        _field(context.t('superadmin.flatSeriesFrom'),
                            _sf.flatSeriesFrom, (v) => _sf.flatSeriesFrom = v),
                        _field(context.t('superadmin.flatSeriesTo'),
                            _sf.flatSeriesTo, (v) => _sf.flatSeriesTo = v),
                      ),
                      SaHint(context.t('superadmin.flatSeriesHelp')),
                      SaHint(context.t('superadmin.flatTrimHint'),
                          accent: AppTokens.tint(t.primary, 0.3),
                          padding: const EdgeInsets.only(top: 6)),
                      SaHint(context.t('superadmin.flatGenerateHint'),
                          accent: AppTokens.tint(t.success, 0.4),
                          padding: const EdgeInsets.only(top: 6)),
                      if (editing) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton.secondary(
                            label: _resetting
                                ? '${context.t('superadmin.resetFlatsButton')}...'
                                : context.t('superadmin.resetFlatsButton'),
                            icon: Icons.layers_outlined,
                            dense: true,
                            expand: false,
                            loading: _resetting,
                            onPressed: busy ? null : _resetFlats,
                          ),
                        ),
                        SaHint(context.t('superadmin.resetFlatsHint')),
                      ],
                    ],
                  ),

                  // Photos
                  SaSubsection(
                    label: context.t('superadmin.societyPhotos'),
                    children: [
                      SaHint(context.t('superadmin.societyPhotosHint'),
                          padding: const EdgeInsets.only(bottom: 8)),
                      if (_sf.existingPhotoUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final url in _sf.existingPhotoUrls)
                                Stack(
                                  children: [
                                    SaNetImage(url, width: 64, height: 64),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setState(() =>
                                            _sf.existingPhotoUrls.remove(url)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: AppTokens.tint(
                                                t.background, 0.9),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Icon(Icons.close,
                                              size: 12, color: t.destructive),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      for (var i = 0; i < _pendingPhotos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(_pendingPhotos[i].bytes,
                                    width: 28, height: 28, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_pendingPhotos[i].name,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.tiny(context)),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _pendingPhotos.removeAt(i)),
                                child: Icon(Icons.close,
                                    size: 14, color: t.destructive),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppButton.secondary(
                          label: context.t('superadmin.addSocietyPhotos'),
                          icon: Icons.add_photo_alternate_outlined,
                          dense: true,
                          expand: false,
                          onPressed: busy ? null : _pickPhotos,
                        ),
                      ),
                    ],
                  ),

                  // Branding & contact
                  SaSubsection(
                    label: context.t('superadmin.branding'),
                    children: _spaced([
                      _field(context.t('superadmin.contactPerson'),
                          _sf.contactPerson, (v) => _sf.contactPerson = v,
                          icon: Icons.person_outline),
                      _field(context.t('superadmin.contactEmail'),
                          _sf.contactEmail, (v) => _sf.contactEmail = v,
                          icon: Icons.mail_outline,
                          keyboard: TextInputType.emailAddress),
                      _field(context.t('superadmin.contactPhone'),
                          _sf.contactPhone, (v) => _sf.contactPhone = v,
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      Row(
                        children: [
                          if (_pendingLogo != null ||
                              _sf.logoUrl.trim().isNotEmpty) ...[
                            _imagePreview(
                                url: _sf.logoUrl, pending: _pendingLogo),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: _field(
                                context.t('superadmin.logoUrl'),
                                _sf.logoUrl,
                                (v) => setState(() => _sf.logoUrl = v),
                                keyboard: TextInputType.url),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppButton.secondary(
                          label: context.t('superadmin.uploadLogo'),
                          icon: Icons.image_outlined,
                          dense: true,
                          expand: false,
                          onPressed: busy
                              ? null
                              : () async {
                                  final f = await _pickSingle(maxSide: 1024);
                                  if (f != null && mounted) {
                                    setState(() => _pendingLogo = f);
                                  }
                                },
                        ),
                      ),
                      if (_pendingLogo != null)
                        SaHint(
                            '${_pendingLogo!.name} — ${context.t('superadmin.logoUploadOnSave')}',
                            padding: EdgeInsets.zero),

                      // Letterhead
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color: AppTokens.tint(t.border, 0.6)))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _spaced([
                            Text(context.t('superadmin.letterhead'),
                                style: AppText.caption(context)
                                    .copyWith(fontWeight: FontWeight.w500)),
                            SaHint(context.t('superadmin.letterheadHint'),
                                padding: EdgeInsets.zero),
                            AppDropdown<String>(
                              items: kLetterheadModes,
                              value: _sf.letterheadMode,
                              labelOf: (m) => switch (m) {
                                'image' =>
                                  context.t('superadmin.letterheadModeImage'),
                                'stationery' => context
                                    .t('superadmin.letterheadModeStationery'),
                                _ => context.t('superadmin.letterheadModeAuto'),
                              },
                              onChanged: (v) => setState(
                                  () => _sf.letterheadMode = v ?? 'auto'),
                            ),
                            Row(
                              children: [
                                if (_pendingLetterhead != null ||
                                    _sf.letterheadUrl.trim().isNotEmpty) ...[
                                  _imagePreview(
                                      url: _sf.letterheadUrl,
                                      pending: _pendingLetterhead,
                                      w: 64,
                                      h: 40),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: _field(
                                      context.t('superadmin.letterheadUrl'),
                                      _sf.letterheadUrl,
                                      (v) =>
                                          setState(() => _sf.letterheadUrl = v),
                                      keyboard: TextInputType.url),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppButton.secondary(
                                label: context.t('superadmin.uploadLetterhead'),
                                icon: Icons.image_outlined,
                                dense: true,
                                expand: false,
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final f =
                                            await _pickSingle(maxSide: 2480);
                                        if (f != null && mounted) {
                                          setState(() {
                                            _pendingLetterhead = f;
                                            _sf.letterheadMode = 'image';
                                          });
                                        }
                                      },
                              ),
                            ),
                            if (_pendingLetterhead != null)
                              SaHint(
                                  '${_pendingLetterhead!.name} — ${context.t('superadmin.logoUploadOnSave')}',
                                  padding: EdgeInsets.zero),
                            _row2(
                              _field('15–80', _sf.letterheadTopMm,
                                  (v) => _sf.letterheadTopMm = v,
                                  keyboard:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  label:
                                      context.t('superadmin.letterheadTopMm')),
                              _field('10–40', _sf.letterheadBottomMm,
                                  (v) => _sf.letterheadBottomMm = v,
                                  keyboard:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  label: context
                                      .t('superadmin.letterheadBottomMm')),
                            ),
                          ], 8),
                        ),
                      ),
                    ], 8),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: _saving ? '…' : context.t('common.save'),
                          loading: _saving,
                          onPressed: busy ? null : _save,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton.secondary(
                          label: context.t('common.cancel'),
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
