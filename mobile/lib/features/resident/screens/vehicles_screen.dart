import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/resident_vehicle.dart';
import '../../../models/session_models.dart';
import '../../../services/vehicle_service.dart';

const _vehicleTypes = [
  ('car', 'Car'),
  ('bike', 'Bike'),
  ('delivery', 'Delivery'),
  ('other', 'Other'),
];

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _service = VehicleService();
  List<ResidentVehicle> _vehicles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final vehicles = await _service.fetchForFlat(
      widget.session.societyId,
      widget.session.resident.flatId,
    );
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _loading = false;
    });
  }

  Future<void> _addVehicle() async {
    final numberCtrl = TextEditingController();
    var type = 'car';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add vehicle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                decoration: const InputDecoration(labelText: 'Vehicle number *'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _vehicleTypes
                    .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialog(() => type = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final number = numberCtrl.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle number is required')),
      );
      return;
    }

    try {
      await _service.addVehicle(
        societyId: widget.session.societyId,
        flatId: widget.session.resident.flatId,
        flatNumber: widget.session.resident.flatNumber,
        residentName: widget.session.resident.name,
        vehicleNumber: number,
        vehicleType: type,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle added')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add vehicle: $e')),
      );
    }
  }

  Future<void> _removeVehicle(ResidentVehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('Remove ${vehicle.vehicleNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _service.removeVehicle(widget.session.societyId, vehicle.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
  }

  String _typeLabel(String type) =>
      _vehicleTypes.firstWhere((e) => e.$1 == type, orElse: () => ('other', type)).$2;

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVehicle,
        backgroundColor: brand.primary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _vehicles.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No vehicles registered', style: TextStyle(color: KutumbikaColors.textMuted))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _vehicles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final v = _vehicles[index];
                        return ListTile(
                          leading: Icon(Icons.directions_car, color: brand.primary),
                          title: Text(v.vehicleNumber),
                          subtitle: Text(_typeLabel(v.vehicleType)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: KutumbikaColors.textMuted),
                            onPressed: () => _removeVehicle(v),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
