import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/notification_media_storage.dart';
import '../data/settings_repository.dart';
import '../data/society_settings_logic.dart';

/// Port of web `SocietyAddressPanel`: the registered address printed on letterheads,
/// receipts and reports (CAPS inputs, pincode without CAPS).
class SocietyAddressPanel extends StatefulWidget {
  const SocietyAddressPanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<SocietyAddressPanel> createState() => _SocietyAddressPanelState();
}

class _SocietyAddressPanelState extends State<SocietyAddressPanel> {
  final _repo = const SettingsRepository();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  String _name = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_address, _city, _state, _pincode]) {
      c.addListener(_refresh);
    }
    _reload();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_address, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final a = await _repo.loadAddress(widget.societyId);
      _name = a.name;
      _address.text = a.address;
      _city.text = a.city;
      _state.text = a.state;
      _pincode.text = a.pincode;
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.saveAddress(
        widget.societyId,
        buildAddressPatch(
            address: _address.text,
            city: _city.text,
            state: _state.text,
            pincode: _pincode.text),
      );
      if (!mounted) return;
      AppFeedback.toast(context, context.t('settings.societyAddressSaved'),
          tone: BadgeTone.success);
      await _reload();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final preview = letterheadAddressLine(
        address: _address.text,
        city: _city.text,
        state: _state.text,
        pincode: _pincode.text);
    return CardSection(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(context.t('settings.societyAddress'),
              icon: Icons.location_on_outlined,
              padding: const EdgeInsets.only(bottom: 4)),
          Text(context.t('settings.societyAddressHint'),
              style: AppText.tiny(context).copyWith(height: 1.4)),
          const SizedBox(height: 12),
          if (_loading)
            Text('…', style: AppText.caption(context))
          else ...[
            if (_name.isNotEmpty) ...[
              Text(_name,
                  style: AppText.bodyMedium(context).copyWith(fontSize: 12)),
              const SizedBox(height: 12)
            ],
            AppTextField(
              label: context.t('superadmin.address'),
              controller: _address,
              hint: context.t('settings.addressPlaceholder'),
              minLines: 3,
              maxLines: 5,
              keyboardType: TextInputType.streetAddress,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: AppTextField(
                        label: context.t('superadmin.city'),
                        controller: _city,
                        hint: context.t('superadmin.city'))),
                const SizedBox(width: 8),
                Expanded(
                    child: AppTextField(
                        label: context.t('superadmin.state'),
                        controller: _state,
                        hint: context.t('superadmin.state'))),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: context.t('superadmin.pincode'),
              controller: _pincode,
              hint: context.t('superadmin.pincode'),
              caps: false,
              keyboardType: TextInputType.number,
              maxLength: 10,
            ),
            const SizedBox(height: 12),
            if (preview.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.secondary, 0.3),
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Text(preview,
                    style: AppText.caption(context).copyWith(fontSize: 11)),
              )
            else
              Text(context.t('settings.societyAddressEmpty'),
                  style: AppText.caption(context).copyWith(fontSize: 11)),
            const SizedBox(height: 12),
            AppButton(
              loading: _saving,
              label: _saving ? '…' : context.t('settings.saveSocietyAddress'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ],
      ),
    );
  }
}
