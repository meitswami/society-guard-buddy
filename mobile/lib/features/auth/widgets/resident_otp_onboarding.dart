import 'package:flutter/material.dart';

import '../../../models/resident_user.dart';
import '../../../services/resident_onboarding_service.dart';
import '../../../utils/member_categories.dart';
import '../../../utils/phone_utils.dart';

/// Port of web `completeResidentOtpOnboarding` — simplified Flutter dialogs.
class ResidentOtpOnboarding {
  static Future<ResidentUser?> run(
    BuildContext context, {
    required String phone,
    required String flatId,
    required String flatNumber,
  }) async {
    final service = ResidentOnboardingService();
    final normalized = normalizeLoginPhone(phone);

    final existing = await service.findExistingUser(flatId, normalized);
    if (existing != null) return existing;

    final members = await service.fetchMembers(flatId);

    if (members.isEmpty) {
      return _firstPrimaryDialog(context, service, flatId: flatId, flatNumber: flatNumber, phone: normalized);
    }

    final primary = service.pickPrimary(members);
    if (primary == null) {
      if (!context.mounted) return null;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Setup incomplete'),
          content: const Text('No primary household member found. Contact your society admin.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return null;
    }

    final primaryPhone = primary.phone != null ? normalizeLoginPhone(primary.phone!) : '';
    if (primaryPhone.isNotEmpty && primaryPhone == normalized) {
      return service.linkPrimaryPhone(
        memberId: primary.id,
        flatId: flatId,
        flatNumber: flatNumber,
        phone: normalized,
        name: primary.name,
      );
    }

    if (primary.phone == null || primaryPhone.isEmpty) {
      final claim = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Link as ${primary.name}?'),
          content: Text('Use this phone for primary member ${primary.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
          ],
        ),
      );
      if (claim == true) {
        return service.linkPrimaryPhone(
          memberId: primary.id,
          flatId: flatId,
          flatNumber: flatNumber,
          phone: normalized,
          name: primary.name,
        );
      }
    }

    return _newMemberDialog(context, service, flatId: flatId, flatNumber: flatNumber, phone: normalized);
  }

  static Future<ResidentUser?> _firstPrimaryDialog(
    BuildContext context,
    ResidentOnboardingService service, {
    required String flatId,
    required String flatNumber,
    required String phone,
  }) async {
    final nameCtrl = TextEditingController();
    var gender = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Welcome!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set up the primary member for this flat.'),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: gender.isEmpty ? null : gender,
                decoration: const InputDecoration(labelText: 'Gender (optional)'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setDialog(() => gender = v ?? ''),
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

    if (ok != true || nameCtrl.text.trim().isEmpty) return null;
    try {
      return await service.createFirstPrimary(
        flatId: flatId,
        flatNumber: flatNumber,
        phone: phone,
        name: nameCtrl.text.trim(),
        gender: gender.isEmpty ? null : gender,
      );
    } on ResidentOnboardingFailure catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    }
  }

  static Future<ResidentUser?> _newMemberDialog(
    BuildContext context,
    ResidentOnboardingService service, {
    required String flatId,
    required String flatNumber,
    required String phone,
  }) async {
    final nameCtrl = TextEditingController();
    var relation = 'family';
    var gender = '';

    const relations = [
      'owner', 'spouse', 'son', 'daughter', 'father', 'mother',
      'family', 'brother', 'sister', 'tenant',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add yourself'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your phone is not linked yet. Add your household profile.'),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: relation,
                  decoration: const InputDecoration(labelText: 'Relation *'),
                  items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => relation = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: gender.isEmpty ? null : gender,
                  decoration: const InputDecoration(labelText: 'Gender *'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDialog(() => gender = v ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true || nameCtrl.text.trim().isEmpty || gender.isEmpty) return null;

    if (!allowsResidentLogin(relation)) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This role cannot use the resident app.')),
      );
      return null;
    }

    try {
      return await service.addHouseholdMemberAndLogin(
        flatId: flatId,
        flatNumber: flatNumber,
        phone: phone,
        name: nameCtrl.text.trim(),
        relation: relation,
        gender: gender,
      );
    } on ResidentOnboardingFailure catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    }
  }
}
