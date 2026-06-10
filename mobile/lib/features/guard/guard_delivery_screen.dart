import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../services/visitor_entry_service.dart';

const _deliveryCompanies = ['Amazon', 'Flipkart', 'Blinkit', 'Zepto', 'Swiggy', 'Other'];
const _serviceCompanies = ['Housekeeping', 'Cook', 'Maid', 'Plumber', 'Electrician', 'Other'];

class GuardDeliveryScreen extends StatefulWidget {
  const GuardDeliveryScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardDeliveryScreen> createState() => _GuardDeliveryScreenState();
}

class _GuardDeliveryScreenState extends State<GuardDeliveryScreen> {
  final _service = VisitorEntryService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  bool _isDelivery = true;
  String _company = 'Amazon';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _flatCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final flat = _flatCtrl.text.trim();
    if (name.isEmpty || phone.length < 10 || flat.isEmpty) {
      setState(() => _error = 'Name, 10-digit phone, and flat are required');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final blocked = await _service.isBlacklisted(
        societyId: widget.session.societyId,
        phone: phone,
      );
      if (blocked) {
        setState(() => _error = 'Person is blacklisted');
        return;
      }

      await _service.registerDelivery(
        societyId: widget.session.societyId,
        guardId: widget.session.guard.guardId,
        guardName: widget.session.guard.name,
        name: name.toUpperCase(),
        phone: phone,
        flatNumber: flat.toUpperCase(),
        company: _company,
        isDelivery: _isDelivery,
        vehicleNumber: _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim().toUpperCase(),
      );

      _nameCtrl.clear();
      _phoneCtrl.clear();
      _flatCtrl.clear();
      _vehicleCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isDelivery ? 'Delivery registered' : 'Service visit registered')),
      );
    } catch (_) {
      setState(() => _error = 'Could not register entry');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final companies = _isDelivery ? _deliveryCompanies : _serviceCompanies;

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery & service')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Delivery')),
              ButtonSegment(value: false, label: Text('Service')),
            ],
            selected: {_isDelivery},
            onSelectionChanged: (s) {
              setState(() {
                _isDelivery = s.first;
                _company = _isDelivery ? 'Amazon' : 'Housekeeping';
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: companies.contains(_company) ? _company : companies.first,
            decoration: const InputDecoration(labelText: 'Company', border: OutlineInputBorder()),
            items: companies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _company = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _flatCtrl,
            decoration: const InputDecoration(labelText: 'Flat number', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vehicleCtrl,
            decoration: const InputDecoration(labelText: 'Vehicle (optional)', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.characters,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: brand.primary, minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Register entry'),
          ),
        ],
      ),
    );
  }
}
