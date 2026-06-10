import 'package:flutter/material.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../services/visitor_service.dart';

class GuardVisitorsScreen extends StatefulWidget {
  const GuardVisitorsScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardVisitorsScreen> createState() => _GuardVisitorsScreenState();
}

class _GuardVisitorsScreenState extends State<GuardVisitorsScreen> {
  final _service = VisitorService();
  List<VisitorEntry> _visitors = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchToday(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _visitors = rows;
      _loading = false;
    });
  }

  Future<void> _markExit(VisitorEntry v) async {
    await _service.markExit(v.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      color: brand.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _visitors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final v = _visitors[index];
          return Card(
            child: ListTile(
              title: Text(v.name),
              subtitle: Text('${v.phone} · Flat ${v.flatNumber}'),
              trailing: v.isInside
                  ? TextButton(
                      onPressed: () => _markExit(v),
                      child: const Text('Exit'),
                    )
                  : const Text('Out'),
            ),
          );
        },
      ),
    );
  }
}
