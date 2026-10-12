import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';
import '../widgets/resident_widgets.dart';

/// Vehicles tab — web `tab === 'vehicles'`.
class ResidentVehiclesTab extends StatefulWidget {
  const ResidentVehiclesTab({super.key, required this.session});

  final SessionResident session;

  @override
  State<ResidentVehiclesTab> createState() => ResidentVehiclesTabState();
}

class ResidentVehiclesTabState extends State<ResidentVehiclesTab> {
  final _repo = const ResidentRepository();
  final _number = TextEditingController();
  String _type = '';
  List<ResidentVehicleRow> _vehicles = const [];
  bool _loading = true;
  bool _failed = false;
  bool _showForm = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final rows = await _repo.fetchVehicles(widget.session.resident.flatId);
      if (!mounted) return;
      setState(() {
        _vehicles = rows;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _vehicles.isEmpty;
      });
    }
  }

  Future<void> _add() async {
    final number = _number.text.trim();
    if (number.isEmpty) {
      AppFeedback.toast(context, context.tr('Vehicle number required', 'वाहन संख्या आवश्यक है'), tone: BadgeTone.alert);
      return;
    }
    if (_type.isEmpty) {
      AppFeedback.toast(context, context.tr('Please select a vehicle type', 'कृपया वाहन का प्रकार चुनें'), tone: BadgeTone.alert);
      return;
    }
    final r = widget.session.resident;
    setState(() => _saving = true);
    try {
      await _repo.addVehicle(
        societyId: widget.session.societyId,
        flatId: r.flatId,
        flatNumber: r.flatNumber,
        residentName: r.name,
        vehicleNumber: number,
        vehicleType: _type,
      );
      if (!mounted) return;
      AppFeedback.toast(context, context.tr('Vehicle added', 'वाहन जोड़ा गया'), tone: BadgeTone.success);
      setState(() {
        _number.clear();
        _type = '';
        _showForm = false;
        _saving = false;
      });
      await reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _delete(ResidentVehicleRow v) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete vehicle?', 'वाहन हटाएँ?'),
      message: context.tr('Remove ${v.vehicleNumber}?', '${v.vehicleNumber} हटाएँ?'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.deleteVehicle(id: v.id, flatId: widget.session.resident.flatId);
      if (!mounted) return;
      await AppFeedback.success(context, title: context.tr('Removed!', 'हटा दिया!'), message: context.tr('Vehicle removed successfully', 'वाहन सफलतापूर्वक हटाया गया'));
      await reload();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  String _typeLabel(String type) => switch (type) {
        'car' => context.tr('🚗 Car', '🚗 कार'),
        'bike' => context.tr('🏍️ Bike', '🏍️ बाइक'),
        'other' => context.tr('🚐 Other', '🚐 अन्य'),
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      onRefresh: reload,
      children: [
        PageHeader(
          title: context.t('resident.vehicles'),
          subtitle: context.tr('Vehicles registered for your flat', 'आपके फ्लैट के पंजीकृत वाहन'),
          icon: Icons.directions_car_outlined,
        ),
        ListLabel(
          context.tr('My Vehicles (${_vehicles.length})', 'मेरे वाहन (${_vehicles.length})'),
          trailing: TintAddButton(label: context.tr('Add', 'जोड़ें'), solid: true, onTap: () => setState(() => _showForm = true)),
        ),
        if (_showForm)
          CardSection(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(context.tr('Add Vehicle', 'वाहन जोड़ें'), style: AppText.sectionTitle(context)),
              const SizedBox(height: 12),
              AppTextField(
                controller: _number,
                hint: context.tr('Vehicle Number (e.g. MH04AB1234)', 'वाहन संख्या (जैसे MH04AB1234)'),
                mono: true,
                inputFormatters: [_UpperCase()],
              ),
              const SizedBox(height: 12),
              AppDropdown<String>(
                items: const ['car', 'bike', 'other'],
                value: _type.isEmpty ? null : _type,
                hint: context.tr('---Select---', '---चुनें---'),
                labelOf: _typeLabel,
                onChanged: (v) => setState(() => _type = v ?? ''),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppButton(label: context.tr('Add Vehicle', 'वाहन जोड़ें'), loading: _saving, onPressed: _add)),
                const SizedBox(width: 8),
                AppButton.secondary(label: context.t('common.cancel'), expand: false, onPressed: () => setState(() => _showForm = false)),
              ]),
            ]),
          ),
        if (_loading) const LoadingView(),
        if (_failed) ErrorView(onRetry: reload),
        if (!_loading && !_failed && _vehicles.isEmpty && !_showForm)
          EmptyView(message: context.tr('No vehicles registered', 'कोई वाहन पंजीकृत नहीं')),
        for (final v in _vehicles)
          CardSection(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.1), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                child: Icon(Icons.directions_car, size: 20, color: t.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.vehicleNumber, style: AppText.mono(context, size: 14, weight: FontWeight.w600)),
                  Text(
                    [
                      v.vehicleType.isEmpty ? '' : '${v.vehicleType[0].toUpperCase()}${v.vehicleType.substring(1)}',
                      if ((v.displayName ?? '').isNotEmpty) v.displayName!,
                      if ((v.color ?? '').isNotEmpty) v.color!,
                      if ((v.memberId ?? '').isNotEmpty) v.residentName,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: AppText.tiny(context),
                  ),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: t.mutedForeground),
                onPressed: () => _delete(v),
              ),
            ]),
          ),
      ],
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
