import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../shared/directory/directory_widgets.dart';
import '../core/admin_module.dart';
import 'data/parking_service.dart';
import 'data/people_models.dart';

/// Admin → Parking — port of web `src/components/ParkingManager.tsx`: add spaces
/// (car / bike / visitor, floor level, optional flat allocation + vehicle, notes),
/// allocated / available lists, free (deallocate) and delete.
class AdminParkingModule extends StatefulWidget {
  const AdminParkingModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminParkingModule> createState() => _AdminParkingModuleState();
}

class _AdminParkingModuleState extends State<AdminParkingModule> {
  final _service = ParkingService();
  ParkingSnapshot _snap = ParkingSnapshot.empty;
  bool _loading = true;
  Object? _error;
  bool _showForm = false;
  bool _saving = false;

  final _number = TextEditingController();
  final _floor = TextEditingController();
  final _vehicle = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'car';
  String _flat = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_number, _floor, _vehicle, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _snap.spaces.isEmpty && _snap.flats.isEmpty;
      _error = null;
    });
    try {
      final s = await _service.load(widget.ctx.societyId);
      if (!mounted) return;
      setState(() {
        _snap = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    if (_number.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _service.addSpace(
        societyId: widget.ctx.societyId,
        spaceNumber: _number.text,
        spaceType: _type,
        floorLevel: _floor.text,
        allocatedFlatNumber: _flat,
        allocatedVehicleNumber: _flat.isEmpty ? '' : _vehicle.text,
        notes: _notes.text,
        flats: _snap.flats,
      );
      for (final c in [_number, _floor, _vehicle, _notes]) {
        c.clear();
      }
      if (!mounted) return;
      setState(() {
        _type = 'car';
        _flat = '';
        _showForm = false;
      });
      AppFeedback.toast(context,
          context.tr('Parking space added', 'पार्किंग स्थान जोड़ा गया'),
          tone: BadgeTone.success);
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(ParkingSpace s) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete Space?', 'स्थान हटाएँ?'),
      message:
          context.tr('Remove this parking space?', 'यह पार्किंग स्थान हटाएँ?'),
      confirmLabel: context.tr('Yes, Delete', 'हाँ, हटाएँ'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _service.deleteSpace(societyId: widget.ctx.societyId, id: s.id);
      if (!mounted) return;
      await AppFeedback.success(context,
          title: context.tr('Deleted!', 'हटाया गया!'),
          message:
              context.tr('Parking space removed', 'पार्किंग स्थान हटाया गया'));
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _free(ParkingSpace s) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Deallocate?', 'आवंटन हटाएँ?'),
      message: context.tr(
          'Remove allocation from this space?', 'इस स्थान से आवंटन हटाएँ?'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    try {
      await _service.deallocate(societyId: widget.ctx.societyId, id: s.id);
      if (!mounted) return;
      await AppFeedback.success(context,
          title: context.tr('Done!', 'हो गया!'),
          message: context.tr('Space deallocated', 'स्थान मुक्त किया गया'));
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  String _typeLabel(BuildContext context, String v) => switch (v) {
        'car' => '🚗 ${context.tr('Car', 'कार')}',
        'bike' => '🏍️ ${context.tr('Bike', 'बाइक')}',
        _ => '👤 ${context.tr('Visitor', 'आगंतुक')}',
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _snap.spaces.isEmpty) {
      return ErrorView(onRetry: _load);
    }
    final t = context.tokens;
    final allocated = _snap.allocated;
    final available = _snap.available;
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          icon: Icons.directions_car_outlined,
          iconColor: t.accent,
          title: context.tr('Parking Management', 'पार्किंग प्रबंधन'),
          subtitle: context.tr(
              '${allocated.length} allocated · ${available.length} available',
              '${allocated.length} आवंटित · ${available.length} उपलब्ध'),
          bottomSpacing: 16,
        ),
        AppButton(
          label: context.tr('Add Parking Space', 'पार्किंग स्थान जोड़ें'),
          icon: _showForm ? Icons.close : Icons.add,
          onPressed: () => setState(() => _showForm = !_showForm),
        ),
        const SizedBox(height: 16),
        if (_showForm) ...[
          CardSection(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                      hint: context.tr('Space Number (e.g. P-101)',
                          'स्थान संख्या (जैसे P-101)'),
                      controller: _number),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    items: const ['car', 'bike', 'visitor'],
                    value: _type,
                    labelOf: (v) => _typeLabel(context, v),
                    onChanged: (v) => setState(() => _type = v ?? 'car'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                      hint: context.tr(
                          'Floor/Level (e.g. B1)', 'मंज़िल/स्तर (जैसे B1)'),
                      controller: _floor),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    items: ['', ..._snap.flats.map((f) => f.flatNumber)],
                    value: _flat,
                    labelOf: (v) => v.isEmpty
                        ? context.tr('Not Allocated', 'आवंटित नहीं')
                        : '${context.t('common.flat')} $v',
                    onChanged: (v) => setState(() => _flat = v ?? ''),
                  ),
                  if (_flat.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                        hint: context.tr('Vehicle Number', 'वाहन संख्या'),
                        controller: _vehicle,
                        mono: true),
                  ],
                  const SizedBox(height: 12),
                  AppTextField(
                      hint: context.tr('Notes', 'टिप्पणी'),
                      controller: _notes,
                      maxLines: 3,
                      minLines: 2),
                  const SizedBox(height: 12),
                  AppButton(
                      label: context.tr('Add Space', 'स्थान जोड़ें'),
                      loading: _saving,
                      onPressed: _add),
                ]),
          ),
          const SizedBox(height: 16),
        ],
        if (allocated.isNotEmpty) ...[
          FieldLabel(context.tr('Allocated (${allocated.length})',
              'आवंटित (${allocated.length})')),
          for (final s in allocated)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardSection(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(s.spaceNumber,
                                style: AppText.mono(context,
                                    size: 14, weight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            TagChip(s.spaceType,
                                color: t.primary,
                                background: AppTokens.tint(t.primary, 0.1)),
                          ]),
                          Text(
                            '${context.t('common.flat')} ${s.allocatedFlatNumber ?? ''} · ${s.allocatedVehicleNumber ?? context.tr('No vehicle', 'कोई वाहन नहीं')}',
                            style: AppText.caption(context),
                          ),
                          if (s.floorLevel != null)
                            Text(
                                '${context.tr('Floor', 'मंज़िल')}: ${s.floorLevel}',
                                style: AppText.tiny(context)),
                          if (s.notes != null)
                            Text(s.notes!, style: AppText.tiny(context)),
                        ]),
                  ),
                  Material(
                    color: AppTokens.tint(t.warning, 0.1),
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: () => _free(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Text(context.tr('Free', 'मुक्त'),
                            style: TextStyle(fontSize: 12, color: t.warning)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TintIconButton(
                      icon: Icons.delete_outline,
                      size: 14,
                      padding: 6,
                      color: t.destructive,
                      onPressed: () => _delete(s)),
                ]),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (available.isNotEmpty) ...[
          FieldLabel(context.tr('Available (${available.length})',
              'उपलब्ध (${available.length})')),
          for (final s in available)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardSection(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(s.spaceNumber,
                                    style: AppText.mono(context,
                                        size: 14, weight: FontWeight.w700)),
                                TagChip(
                                    '${s.spaceType} · ${context.tr('Available', 'उपलब्ध')}',
                                    color: t.success,
                                    background: AppTokens.tint(t.success, 0.2)),
                              ]),
                          if (s.floorLevel != null)
                            Text(
                                '${context.tr('Floor', 'मंज़िल')}: ${s.floorLevel}',
                                style: AppText.tiny(context)),
                          if (s.notes != null)
                            Text(s.notes!, style: AppText.tiny(context)),
                        ]),
                  ),
                  TintIconButton(
                      icon: Icons.delete_outline,
                      size: 14,
                      padding: 6,
                      color: t.destructive,
                      onPressed: () => _delete(s)),
                ]),
              ),
            ),
        ],
        if (_snap.spaces.isEmpty)
          EmptyView(
              message: context.tr(
                  'No parking spaces yet', 'अभी कोई पार्किंग स्थान नहीं'),
              icon: Icons.local_parking_outlined),
      ],
    );
  }
}
