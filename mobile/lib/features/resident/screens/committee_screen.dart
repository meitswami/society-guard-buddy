import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/committee_member.dart';
import '../../../models/session_models.dart';
import '../../../services/committee_service.dart';

class CommitteeScreen extends StatefulWidget {
  const CommitteeScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  final _service = CommitteeService();
  List<CommitteeMember> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchActive(widget.session.societyId);
    if (!mounted) return;
    setState(() {
      _members = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Managing committee')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _members.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No committee members listed', style: TextStyle(color: KutumbikaColors.textMuted))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final displayName = m.showRepresentative && (m.repName?.isNotEmpty ?? false)
                            ? m.repName!
                            : m.name;
                        final displayPhone = m.showRepresentative && (m.repPhone?.isNotEmpty ?? false)
                            ? m.repPhone
                            : m.phone;
                        final photo = m.showRepresentative && (m.repName?.isNotEmpty ?? false)
                            ? null
                            : m.photo;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: brand.primary.withValues(alpha: 0.12),
                            backgroundImage: photo != null && photo.isNotEmpty
                                ? CachedNetworkImageProvider(photo)
                                : null,
                            child: photo == null || photo.isEmpty
                                ? Icon(Icons.person, color: brand.primary)
                                : null,
                          ),
                          title: Text(displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.position, style: TextStyle(color: brand.primary, fontWeight: FontWeight.w500)),
                              if (m.flatNumber != null && m.flatNumber!.isNotEmpty)
                                Text('Flat ${m.flatNumber}'),
                              if (displayPhone != null && displayPhone.isNotEmpty) Text(displayPhone),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
    );
  }
}
