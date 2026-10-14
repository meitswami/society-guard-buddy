import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/gate_actor.dart';
import '../../core/ui/ui.dart';
import 'data/gate_logic.dart';
import 'data/gate_models.dart';
import 'data/gate_store.dart';
import 'gate_i18n.dart';
import 'widgets/flat_multi_select.dart';

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Resident vehicle registry at the gate — web `src/pages/VehiclePage.tsx`: search, add one
/// vehicle number to several flats at once (resident = primary member or owner), remove.
class VehicleView extends StatefulWidget {
  const VehicleView({super.key, required this.actor, this.initialSearchQuery});

  final GateActor actor;
  final String? initialSearchQuery;

  @override
  State<VehicleView> createState() => _VehicleViewState();
}

class _VehicleViewState extends State<VehicleView> {
  late final GateStore _store = GateStore.of(widget.actor.societyId);
  late final _search =
      TextEditingController(text: widget.initialSearchQuery ?? '');
  final _number = TextEditingController();
  bool _showAdd = false;
  List<String> _selectedFlats = const [];
  String _type = 'car';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_selectedFlats.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.vehicle.selectFlat'),
          tone: BadgeTone.alert);
      return;
    }
    final vnum = _number.text.trim().toUpperCase();
    if (vnum.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.vehicle.enterNumber'),
          tone: BadgeTone.warning);
      return;
    }
    setState(() => _saving = true);
    final count = _selectedFlats.length;
    try {
      for (final flatNumber in _selectedFlats) {
        GateFlat? flat;
        for (final f in _store.flats) {
          if (f.flatNumber == flatNumber) {
            flat = f;
            break;
          }
        }
        if (flat == null) continue;
        final residentName = residentNameForFlat(flat, _store.members);
        if (residentName.isEmpty) {
          if (mounted) {
            AppFeedback.toast(
              context,
              context.gt('gate.vehicle.noResident', {
                'label': context.t('vehicle.residentName'),
                'flat': flatNumber
              }),
              tone: BadgeTone.alert,
            );
          }
          return;
        }
        await _store.addResidentVehicle(
          flatNumber: flatNumber,
          residentName: residentName,
          vehicleNumber: vnum,
          vehicleType: _type,
          flatId: flat.id,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.gt('gate.saveFailed'),
            tone: BadgeTone.alert);
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    _number.clear();
    setState(() {
      _type = 'car';
      _selectedFlats = const [];
      _showAdd = false;
    });
    AppFeedback.toast(
      context,
      count > 1
          ? context.gt('gate.vehicle.savedMany', {'count': count})
          : context.gt('gate.vehicle.saved'),
      tone: BadgeTone.success,
    );
  }

  Future<void> _remove(GateResidentVehicle v) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmDelete'),
      message: context.t('swal.confirmDeleteText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _store.removeResidentVehicle(v.id);
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.gt('gate.deleteFailed'),
            tone: BadgeTone.alert);
      }
    }
  }

  String _typeLabel(String type) {
    for (final vt in kGateVehicleTypes) {
      if (vt.value == type) return context.tr(vt.en, vt.hi);
    }
    return type;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final t = context.tokens;
        final list = _store.residentVehicles
            .where((v) => vehicleMatchesSearch(v, _search.text))
            .toList();
        final flatOptions = [
          for (final f in _store.flats.where((f) => f.isOccupied))
            FlatOption(
                id: f.id,
                flatNumber: f.flatNumber,
                subtitle: residentNameForFlat(f, _store.members).isEmpty
                    ? null
                    : residentNameForFlat(f, _store.members)),
        ];
        return PageContainer(
          onRefresh: () => Future.wait(
              [_store.loadResidentVehicles(), _store.loadDirectory()]),
          children: [
            PageHeader(
              icon: Icons.directions_car_outlined,
              title: context.t('vehicle.title'),
              subtitle: context.t('vehicle.subtitle'),
              bottomSpacing: 24,
              actions: [
                AppButton(
                  label: context.t('common.add'),
                  icon: Icons.add,
                  dense: true,
                  expand: false,
                  onPressed: () => setState(() => _showAdd = !_showAdd),
                ),
              ],
            ),
            if (_showAdd)
              CardSection(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FlatMultiSelect(
                      flats: flatOptions,
                      selected: _selectedFlats,
                      onChanged: (s) => setState(() => _selectedFlats = s),
                      label: context.t('vehicle.flatNo'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _number,
                      hint: context.t('visitor.vehicleNumber'),
                      mono: true,
                      inputFormatters: [_UpperCase()],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final vt in kGateVehicleTypes) ...[
                          Expanded(
                            child: Material(
                              color:
                                  _type == vt.value ? t.primary : t.secondary,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusSm),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusSm),
                                onTap: () => setState(() => _type = vt.value),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  child: Text(
                                    context.tr(vt.en, vt.hi),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _type == vt.value
                                          ? t.primaryForeground
                                          : t.secondaryForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (vt != kGateVehicleTypes.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                        label: context.t('vehicle.saveVehicle'),
                        loading: _saving,
                        onPressed: _add),
                  ],
                ),
              ),
            AppTextField(
                controller: _search,
                hint: context.t('vehicle.searchPlaceholder'),
                prefixIcon: Icons.search,
                caps: false),
            const SizedBox(height: 16),
            if (!_store.vehiclesLoaded)
              const LoadingView()
            else if (_store.vehiclesError != null &&
                _store.residentVehicles.isEmpty)
              ErrorView(onRetry: _store.loadResidentVehicles)
            else if (list.isEmpty)
              EmptyView(message: context.t('vehicle.noVehicles'))
            else
              for (final v in list)
                CardSection(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: t.secondary,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusSm)),
                        child: Icon(Icons.directions_car_outlined,
                            size: 20, color: t.mutedForeground),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.vehicleNumber,
                                style: AppText.mono(context,
                                    size: 14, weight: FontWeight.w600)),
                            Text(
                              '${context.t('common.flat')} ${v.flatNumber} · ${v.residentName} · ${_typeLabel(v.vehicleType)}',
                              style: AppText.caption(context),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.t('common.delete'),
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: t.mutedForeground),
                        onPressed: () => _remove(v),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
