import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import '../../../models/resident_user.dart';
import '../../../services/resident_onboarding_service.dart';
import '../../../utils/member_categories.dart';
import '../../../utils/phone_utils.dart';

/// Result of the first-time login (web `ResidentLoginPayload`).
class ResidentOnboardingResult {
  const ResidentOnboardingResult(this.user, {this.openFamilyTab = false});
  final ResidentUser user;

  /// The first primary of an empty flat lands on the Family tab (web `openFamilyTab`).
  final bool openFamilyTab;
}

/// Port of web `completeResidentOtpOnboarding`: after the phone was verified (OTP) or the
/// flat password matched, links the member / creates the `resident_users` row, asking the
/// same questions as the web SweetAlert dialogs (here as bottom sheets).
class ResidentOtpOnboarding {
  ResidentOtpOnboarding._();

  static Future<ResidentOnboardingResult?> run(
    BuildContext context, {
    required String phone,
    required String flatId,
    required String flatNumber,
    ResidentOnboardingService? service,
  }) async {
    final svc = service ?? ResidentOnboardingService();
    final normalized = normalizeLoginPhone(phone);

    final existing = await svc.findExistingUser(flatId, normalized);
    if (existing != null) return ResidentOnboardingResult(existing);

    final members = await svc.fetchFlatMembers(flatId);
    if (!context.mounted) return null;
    final decision = decideResidentOnboarding(members: members, phone: normalized);

    switch (decision.kind) {
      case OnboardingStepKind.firstPrimary:
        final first = await _FirstPrimarySheet.show(context);
        if (first == null || !context.mounted) return null;
        try {
          await svc.insertMember(buildFirstPrimaryPayload(flatId: flatId, name: first.name, phone: normalized, gender: first.gender));
        } on ResidentOnboardingFailure catch (e) {
          if (context.mounted) await _saveFailed(context, e.message);
          return null;
        }
        await svc.markFlatOwner(flatId: flatId, ownerName: first.name);
        final row = await svc.ensureResidentUserRow(
          flatId: flatId,
          flatNumber: flatNumber,
          phone: normalized,
          name: first.name,
          mustChangePassword: true,
        );
        if (row == null) {
          if (context.mounted) await _saveFailed(context, null);
          return null;
        }
        return ResidentOnboardingResult(row, openFamilyTab: true);

      case OnboardingStepKind.noPrimary:
        await AppFeedback.error(context,
            title: context.t('login.onboard.noPrimaryTitle'), message: context.t('login.onboard.noPrimaryBody'));
        return null;

      case OnboardingStepKind.linkPrimary:
        final primary = decision.primary!;
        final row = await svc.ensureResidentUserRow(
          flatId: flatId,
          flatNumber: flatNumber,
          phone: normalized,
          name: primary.name,
          mustChangePassword: false,
        );
        return row == null ? null : ResidentOnboardingResult(row);

      case OnboardingStepKind.claimPrimary:
        final primary = decision.primary!;
        final ok = await AppFeedback.confirm(
          context,
          title: context.t('login.onboard.claimPrimaryTitle', {'name': primary.name}),
          message: context.t('login.onboard.claimPrimaryBody'),
          confirmLabel: context.t('swal.yes'),
          cancelLabel: context.t('swal.no'),
        );
        if (!context.mounted) return null;
        if (ok) {
          try {
            await svc.updateMemberPhone(memberId: primary.id, phone: normalized);
          } on ResidentOnboardingFailure catch (e) {
            if (context.mounted) await _saveFailed(context, e.message);
            return null;
          }
          final row = await svc.ensureResidentUserRow(
            flatId: flatId,
            flatNumber: flatNumber,
            phone: normalized,
            name: primary.name,
            mustChangePassword: false,
          );
          return row == null ? null : ResidentOnboardingResult(row);
        }
        return _newMember(context, svc, flatId: flatId, flatNumber: flatNumber, phone: normalized);

      case OnboardingStepKind.newMember:
        return _newMember(context, svc, flatId: flatId, flatNumber: flatNumber, phone: normalized);
    }
  }

  static Future<ResidentOnboardingResult?> _newMember(
    BuildContext context,
    ResidentOnboardingService svc, {
    required String flatId,
    required String flatNumber,
    required String phone,
  }) async {
    final nm = await _NewMemberSheet.show(context);
    if (nm == null || !context.mounted) return null;

    _StaffExtra? extra;
    if (isRestrictedMemberCategory(nm.relation)) {
      extra = await _StaffExtraSheet.show(context);
      if (extra == null || !context.mounted) return null;
    }

    try {
      await svc.insertMember(buildNewMemberPayload(
        flatId: flatId,
        name: nm.name,
        phone: phone,
        relation: nm.relation,
        gender: nm.gender,
        idPhotoFront: extra?.idPhotoFront,
        idPhotoBack: extra?.idPhotoBack,
        policeVerification: extra?.policeVerification,
      ));
    } on ResidentOnboardingFailure catch (e) {
      if (context.mounted) await _saveFailed(context, e.message);
      return null;
    }
    if (!context.mounted) return null;

    if (!allowsResidentLogin(nm.relation)) {
      await _info(context, context.t('login.onboard.staffNoAppTitle'), context.t('login.onboard.staffNoAppBody'));
      return null;
    }

    final row = await svc.ensureResidentUserRow(
      flatId: flatId,
      flatNumber: flatNumber,
      phone: phone,
      name: nm.name,
      mustChangePassword: false,
    );
    if (row == null) {
      if (context.mounted) await _saveFailed(context, null);
      return null;
    }
    return ResidentOnboardingResult(row);
  }

  static Future<void> _saveFailed(BuildContext context, String? message) =>
      AppFeedback.error(context, title: context.t('login.onboard.saveFailed'), message: message);

  static Future<void> _info(BuildContext context, String title, String message) {
    final t = context.tokens;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.info_outline_rounded, color: t.primary, size: 44),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sheets
// -----------------------------------------------------------------------------

const _genders = ['Male', 'Female', 'Other'];

String _genderLabel(BuildContext c, String g) => switch (g) {
      'Male' => c.tr('Male', 'पुरुष'),
      'Female' => c.tr('Female', 'महिला'),
      _ => c.tr('Other', 'अन्य'),
    };

/// Web `RELATION_OPTIONS_HTML` (Household / Staff-service groups; `owner` first = default).
const _householdRelations = ['owner', 'spouse', 'son', 'daughter', 'father', 'mother', 'family', 'tenant', 'other'];
const _staffRelations = ['cook', 'maid', 'washerman', 'newspaper', 'driver'];

String _relationLabel(BuildContext c, String r) => switch (r) {
      'owner' => c.tr('Owner', 'मालिक'),
      'spouse' => c.tr('Spouse', 'जीवनसाथी'),
      'son' => c.tr('Son', 'पुत्र'),
      'daughter' => c.tr('Daughter', 'पुत्री'),
      'father' => c.tr('Father', 'पिता'),
      'mother' => c.tr('Mother', 'माता'),
      'family' => c.tr('Family', 'परिवार'),
      'tenant' => c.tr('Tenant', 'किरायेदार'),
      'other' => c.tr('Other', 'अन्य'),
      'cook' => c.tr('Cook', 'रसोइया'),
      'maid' => c.tr('Maid', 'घरेलू सहायिका'),
      'washerman' => c.tr('Washerman', 'धोबी'),
      'newspaper' => c.tr('Newspaper', 'अख़बार वाला'),
      'driver' => c.tr('Driver', 'चालक'),
      _ => r,
    };

/// Shared bottom-sheet frame: title, body text, fields, validation line, Cancel / Save.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.body, required this.children, required this.onSave, this.validation});

  final String title;
  final String body;
  final List<Widget> children;
  final VoidCallback onSave;
  final String? validation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.pageTitle(context).copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text(body, style: AppText.body(context).copyWith(color: AppTokens.tint(t.foreground, 0.9))),
              const SizedBox(height: 16),
              ...children,
              if (validation != null) ...[
                const SizedBox(height: 12),
                NoticeBanner(message: validation!, tone: BadgeTone.alert, icon: Icons.error_outline),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: AppButton.secondary(label: context.t('common.cancel'), onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(child: AppButton(label: context.t('common.save'), onPressed: onSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstPrimary {
  const _FirstPrimary(this.name, this.gender);
  final String name;
  final String gender;
}

class _FirstPrimarySheet extends StatefulWidget {
  const _FirstPrimarySheet();

  static Future<_FirstPrimary?> show(BuildContext context) => showModalBottomSheet<_FirstPrimary>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => const _FirstPrimarySheet(),
      );

  @override
  State<_FirstPrimarySheet> createState() => _FirstPrimarySheetState();
}

class _FirstPrimarySheetState extends State<_FirstPrimarySheet> {
  final _name = TextEditingController();
  String? _gender;
  String? _validation;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _validation = context.t('login.onboard.nameRequired'));
      return;
    }
    Navigator.pop(context, _FirstPrimary(name, _gender ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: context.t('login.onboard.firstPrimaryTitle'),
      body: context.t('login.onboard.firstPrimaryBody'),
      validation: _validation,
      onSave: _save,
      children: [
        AppTextField(controller: _name, hint: context.t('login.onboard.fullName'), maxLength: 120, caps: false, autofocus: true),
        const SizedBox(height: 8),
        AppDropdown<String>(
          items: _genders,
          value: _gender,
          hint: context.t('login.onboard.genderOptional'),
          labelOf: (g) => _genderLabel(context, g),
          onChanged: (v) => setState(() => _gender = v),
        ),
      ],
    );
  }
}

class _NewMember {
  const _NewMember(this.name, this.relation, this.gender);
  final String name;
  final String relation;
  final String gender;
}

class _NewMemberSheet extends StatefulWidget {
  const _NewMemberSheet();

  static Future<_NewMember?> show(BuildContext context) => showModalBottomSheet<_NewMember>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => const _NewMemberSheet(),
      );

  @override
  State<_NewMemberSheet> createState() => _NewMemberSheetState();
}

class _NewMemberSheetState extends State<_NewMemberSheet> {
  final _name = TextEditingController();
  String _relation = 'owner';
  String? _gender;
  String? _validation;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    String? problem;
    if (name.isEmpty) {
      problem = context.t('login.onboard.nameRequired');
    } else if (_relation.isEmpty) {
      problem = context.t('login.onboard.relationRequired');
    } else if ((_gender ?? '').isEmpty) {
      problem = context.t('login.onboard.genderRequired');
    }
    if (problem != null) {
      setState(() => _validation = problem);
      return;
    }
    Navigator.pop(context, _NewMember(name, _relation, _gender!));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _SheetFrame(
      title: context.t('login.onboard.newMemberTitle'),
      body: context.t('login.onboard.newMemberBody'),
      validation: _validation,
      onSave: _save,
      children: [
        AppTextField(controller: _name, hint: context.t('login.onboard.fullName'), caps: false, autofocus: true),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(_relation),
          initialValue: _relation,
          isExpanded: true,
          dropdownColor: t.card,
          style: TextStyle(fontSize: 14, color: t.foreground),
          items: [
            DropdownMenuItem<String>(
              enabled: false,
              value: '__household',
              child: Text(context.tr('Household', 'परिवार'), style: AppText.fieldLabel(context)),
            ),
            for (final r in _householdRelations) DropdownMenuItem(value: r, child: Text('   ${_relationLabel(context, r)}')),
            DropdownMenuItem<String>(
              enabled: false,
              value: '__staff',
              child: Text(context.tr('Staff / service', 'कर्मचारी / सेवा'), style: AppText.fieldLabel(context)),
            ),
            for (final r in _staffRelations) DropdownMenuItem(value: r, child: Text('   ${_relationLabel(context, r)}')),
          ],
          selectedItemBuilder: (ctx) => [
            const SizedBox.shrink(),
            for (final r in _householdRelations) Align(alignment: Alignment.centerLeft, child: Text(_relationLabel(ctx, r))),
            const SizedBox.shrink(),
            for (final r in _staffRelations) Align(alignment: Alignment.centerLeft, child: Text(_relationLabel(ctx, r))),
          ],
          onChanged: (v) {
            if (v != null && !v.startsWith('__')) setState(() => _relation = v);
          },
        ),
        const SizedBox(height: 8),
        AppDropdown<String>(
          items: _genders,
          value: _gender,
          hint: context.t('login.onboard.selectGender'),
          labelOf: (g) => _genderLabel(context, g),
          onChanged: (v) => setState(() => _gender = v),
        ),
      ],
    );
  }
}

class _StaffExtra {
  const _StaffExtra(this.idPhotoFront, this.idPhotoBack, this.policeVerification);
  final String idPhotoFront;
  final String idPhotoBack;
  final String policeVerification;
}

class _StaffExtraSheet extends StatefulWidget {
  const _StaffExtraSheet();

  static Future<_StaffExtra?> show(BuildContext context) => showModalBottomSheet<_StaffExtra>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => const _StaffExtraSheet(),
      );

  @override
  State<_StaffExtraSheet> createState() => _StaffExtraSheetState();
}

class _StaffExtraSheetState extends State<_StaffExtraSheet> {
  String? _front;
  String? _back;
  String _police = 'pending';
  String? _validation;

  /// Picks an image and returns it as a JPEG data URL (web stores `FileReader` data URLs).
  Future<String?> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('Camera', 'कैमरा')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.tr('Gallery', 'गैलरी')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 75);
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('login.onboard.saveFailed'), tone: BadgeTone.alert);
      return null;
    }
  }

  void _save() {
    if (_front == null) {
      setState(() => _validation = context.t('login.onboard.idFrontRequired'));
      return;
    }
    Navigator.pop(context, _StaffExtra(_front!, _back ?? '', _police));
  }

  Widget _photoField(String label, String? value, ValueChanged<String?> onPicked) {
    final t = context.tokens;
    final bytes = value == null ? null : base64Decode(value.substring(value.indexOf(',') + 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.caption(context).copyWith(color: t.foreground)),
        const SizedBox(height: 6),
        Row(
          children: [
            if (bytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: AppButton.secondary(
                label: bytes == null ? context.tr('Choose photo', 'फोटो चुनें') : context.tr('Change photo', 'फोटो बदलें'),
                icon: Icons.add_a_photo_outlined,
                dense: true,
                onPressed: () async {
                  final picked = await _pick();
                  if (picked != null) onPicked(picked);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: context.t('login.onboard.staffExtraTitle'),
      body: context.t('login.onboard.staffExtraBody'),
      validation: _validation,
      onSave: _save,
      children: [
        _photoField(context.t('login.onboard.idFront'), _front, (v) => setState(() => _front = v)),
        const SizedBox(height: 12),
        _photoField(context.t('login.onboard.idBackOptional'), _back, (v) => setState(() => _back = v)),
        const SizedBox(height: 12),
        AppDropdown<String>(
          items: const ['pending', 'submitted', 'verified'],
          value: _police,
          labelOf: (p) => switch (p) {
            'submitted' => context.tr('Police: Submitted', 'पुलिस: जमा'),
            'verified' => context.tr('Police: Verified', 'पुलिस: सत्यापित'),
            _ => context.tr('Police: Pending', 'पुलिस: लंबित'),
          },
          onChanged: (v) => setState(() => _police = v ?? 'pending'),
        ),
      ],
    );
  }
}
