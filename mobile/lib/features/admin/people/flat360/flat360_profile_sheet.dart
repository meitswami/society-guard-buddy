import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import 'flat360_models.dart';
import 'flat360_panel.dart';
import 'flat360_service.dart';

export 'flat360_models.dart' show Flat360ResidentContext, Flat360FetchParams;
export 'flat360_panel.dart' show Flat360ProfilePanel;

/// Flat 360° profile in a draggable bottom sheet (web `Flat360ProfilePanel`).
///
/// Admin (default): includes gate visitors and shows all notices addressed to the flat.
/// Resident: pass [residentId] + [residentName] so notices are filtered for resident
/// visibility (visitors are then excluded unless [includeVisitors] is set).
abstract final class Flat360ProfileSheet {
  static Future<void> show(
    BuildContext context, {
    required String societyId,
    required String flatId,
    String? flatNumber,
    String? residentId,
    String? residentName,
    bool? includeVisitors,
    bool compact = false,
    int monthsBack = 12,
  }) {
    final resident = (residentId != null && residentId.isNotEmpty)
        ? Flat360ResidentContext(id: residentId, name: residentName ?? '')
        : null;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _SheetBody(
          scroll: scroll,
          societyId: societyId,
          flatId: flatId,
          flatNumber: flatNumber,
          resident: resident,
          includeVisitors: includeVisitors ?? resident == null,
          compact: compact,
          monthsBack: monthsBack,
        ),
      ),
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.scroll,
    required this.societyId,
    required this.flatId,
    required this.flatNumber,
    required this.resident,
    required this.includeVisitors,
    required this.compact,
    required this.monthsBack,
  });

  final ScrollController scroll;
  final String societyId;
  final String flatId;
  final String? flatNumber;
  final Flat360ResidentContext? resident;
  final bool includeVisitors;
  final bool compact;
  final int monthsBack;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  String? _flatNumber;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _flatNumber = widget.flatNumber;
    if (_flatNumber == null || _flatNumber!.isEmpty) _resolve();
  }

  Future<void> _resolve() async {
    try {
      final n = await Flat360Service().flatNumberFor(widget.flatId);
      if (!mounted) return;
      setState(() {
        _flatNumber = n ?? '';
        _failed = n == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_failed) {
      body = ErrorView(onRetry: () {
        setState(() => _failed = false);
        _resolve();
      });
    } else if (_flatNumber == null) {
      body = const LoadingView();
    } else {
      body = Flat360ProfilePanel(
        compact: widget.compact,
        params: Flat360FetchParams(
          societyId: widget.societyId,
          flatId: widget.flatId,
          flatNumber: _flatNumber!,
          monthsBack: widget.monthsBack,
          residentContext: widget.resident,
          includeVisitors: widget.includeVisitors,
        ),
      );
    }
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Row(children: [
          Expanded(child: Text(context.tr('360° Profile', '360° प्रोफ़ाइल'), style: AppText.pageTitle(context))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}
