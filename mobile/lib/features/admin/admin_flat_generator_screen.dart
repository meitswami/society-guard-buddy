import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/session_models.dart';
import '../../services/admin_flat_bulk_service.dart';
import '../../utils/society_flat_layout.dart';

class AdminFlatGeneratorScreen extends StatefulWidget {
  const AdminFlatGeneratorScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  State<AdminFlatGeneratorScreen> createState() => _AdminFlatGeneratorScreenState();
}

class _AdminFlatGeneratorScreenState extends State<AdminFlatGeneratorScreen> {
  final _service = AdminFlatBulkService();
  final _floorsCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _blocksCtrl = TextEditingController();
  bool _loading = true;
  bool _generating = false;
  String? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _floorsCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _blocksCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final layout = await _service.fetchLayout(widget.session.societyId);
    if (!mounted) return;
    if (layout != null) {
      _floorsCtrl.text = layout.totalFloors?.toString() ?? '';
      _startCtrl.text = layout.flatSeriesStart ?? '';
      _endCtrl.text = layout.flatSeriesEnd ?? '';
      _blocksCtrl.text = layout.blockNames.join(', ');
    }
    _updatePreview();
    setState(() => _loading = false);
  }

  void _updatePreview() {
    final floors = int.tryParse(_floorsCtrl.text.trim());
    if (floors == null || floors < 1) {
      setState(() => _preview = null);
      return;
    }
    final range = buildValidFlatNumberSet(
      totalFloors: floors,
      flatSeriesStart: _startCtrl.text,
      flatSeriesEnd: _endCtrl.text,
    );
    if (range == null) {
      setState(() => _preview = null);
      return;
    }
    final blocks = _parseBlocks();
    final perWing = range.valid.length;
    final wings = blocks.isEmpty ? 1 : blocks.length;
    setState(() => _preview = '~${perWing * wings} flats (${range.valid.length} per wing × $wings)');
  }

  List<String> _parseBlocks() {
    return _blocksCtrl.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _saveLayout() async {
    final floors = int.tryParse(_floorsCtrl.text.trim());
    if (floors == null || floors < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter total floors (≥ 1)')),
      );
      return;
    }
    await _service.saveLayout(
      societyId: widget.session.societyId,
      totalFloors: floors,
      flatSeriesStart: _startCtrl.text,
      flatSeriesEnd: _endCtrl.text,
      blockNames: _parseBlocks(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layout saved')));
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    await _saveLayout();
    final result = await _service.generateFromLayout(widget.session.societyId);
    if (!mounted) return;
    setState(() => _generating = false);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created ${result.created} flats (${result.skipped} skipped)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Generate flats from layout')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Uses Indian-style numbering (101–105, 201–205, …). '
                  'Skips flats that already exist. Same model as Superadmin society setup.',
                  style: TextStyle(fontSize: 13, color: KutumbikaColors.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _floorsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Total floors',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updatePreview(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _startCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Flat series start (e.g. 101)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updatePreview(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _endCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Flat series end (e.g. 105)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updatePreview(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _blocksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Block / wing names (comma-separated, optional)',
                    hintText: 'A, B or leave empty for single tower',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _updatePreview(),
                ),
                if (_preview != null) ...[
                  const SizedBox(height: 12),
                  Text(_preview!, style: TextStyle(color: brand.primary, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _generating ? null : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: brand.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _generating
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save layout & generate flats'),
                ),
              ],
            ),
    );
  }
}
