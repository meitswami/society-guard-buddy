import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../models/session_models.dart';
import '../../../providers/session_provider.dart';
import '../../../services/member_service.dart';
import '../../../utils/member_photo.dart';
import '../../shared/widgets/biometric_settings_tile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.session});

  final SessionResident session;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _photo;
  bool _loadingPhoto = true;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final member = await MemberService().findByPhone(
      widget.session.resident.flatId,
      widget.session.resident.phone,
    );
    if (!mounted) return;
    setState(() {
      _photo = member?.photo;
      _loadingPhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);
    final r = widget.session.resident;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: _loadingPhoto
              ? CircleAvatar(
                  radius: 36,
                  backgroundColor: brand.primaryLight,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : memberPhotoAvatar(
                  name: r.name,
                  photo: _photo,
                  backgroundColor: brand.primaryLight,
                  foregroundColor: brand.primary,
                  radius: 36,
                ),
        ),
        const SizedBox(height: 16),
        Text(r.name, style: theme.textTheme.headlineSmall),
        Text('Flat ${r.flatNumber} · ${widget.session.societyName}'),
        Text(r.phone),
        const SizedBox(height: 16),
        Card(child: BiometricSettingsTile(session: widget.session)),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: brand.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Log out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                ],
              ),
            );
            if (ok == true) {
              await ref.read(sessionProvider.notifier).logout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
