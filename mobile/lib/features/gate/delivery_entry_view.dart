import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/gate_actor.dart';
import '../../core/ui/ui.dart';
import 'data/gate_logic.dart';
import 'data/gate_store.dart';
import 'gate_i18n.dart';
import 'widgets/photo_capture.dart';

/// Delivery / service entry — web `src/pages/DeliveryEntryPage.tsx`: Delivery | Service tabs,
/// company / service type pills, person name, phone, flat, optional vehicle, person photos.
class DeliveryEntryView extends StatefulWidget {
  const DeliveryEntryView({super.key, required this.actor, this.onDone});

  final GateActor actor;
  final VoidCallback? onDone;

  @override
  State<DeliveryEntryView> createState() => _DeliveryEntryViewState();
}

class _DeliveryEntryViewState extends State<DeliveryEntryView> {
  late final GateStore _store = GateStore.of(widget.actor.societyId);
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _flat = TextEditingController();
  final _vehicle = TextEditingController();

  bool _isDelivery = true;
  String _company = 'Amazon';
  List<String> _photos = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _flat, _vehicle]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setTab(bool delivery) => setState(() {
        _isDelivery = delivery;
        _company = delivery ? 'Amazon' : 'Housekeeping';
      });

  Future<void> _submit() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final flat = _flat.text.trim();
    if (name.isEmpty || phone.isEmpty || flat.isEmpty) {
      AppFeedback.toast(context, context.gt('gate.delivery.required'),
          tone: BadgeTone.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await _store.addVisitor(buildDeliveryEntry(
        isDelivery: _isDelivery,
        name: name,
        phone: phone,
        company: _company,
        flatNumber: flat,
        vehicleNumber: _vehicle.text,
        personPhotos: _photos,
        guardId: widget.actor.actorId,
        guardName: widget.actor.actorName,
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.toast(context, context.gt('gate.saveFailed'),
            tone: BadgeTone.alert);
      }
      return;
    }
    if (!mounted) return;
    for (final c in [_name, _phone, _flat, _vehicle]) {
      c.clear();
    }
    setState(() {
      _saving = false;
      _company = _isDelivery ? 'Amazon' : 'Housekeeping';
      _photos = const [];
    });
    final done = widget.onDone;
    if (done != null) Future.delayed(const Duration(milliseconds: 1600), done);
    await AppFeedback.success(context,
        title: context.t('swal.success'),
        message: context.t('swal.deliveryRegistered'));
  }

  @override
  Widget build(BuildContext context) {
    final options = _isDelivery
        ? [
            for (final c in kDeliveryCompanies)
              (value: c, label: c == 'Other' ? context.t('purpose.other') : c)
          ]
        : [
            for (final s in kServiceTypes)
              (value: s.value, label: context.tr(s.value, s.hi))
          ];
    return PageContainer(
      children: [
        PageHeader(
          icon: Icons.local_shipping_outlined,
          title: context.t('delivery.title'),
          subtitle: context.t('delivery.subtitle'),
          bottomSpacing: 24,
        ),
        Row(
          children: [
            Expanded(
                child: _TabButton(
                    label: context.t('delivery.tab.delivery'),
                    selected: _isDelivery,
                    onTap: () => _setTab(true))),
            const SizedBox(width: 8),
            Expanded(
                child: _TabButton(
                    label: context.t('delivery.tab.service'),
                    selected: !_isDelivery,
                    onTap: () => _setTab(false))),
          ],
        ),
        const SizedBox(height: 24),
        FieldLabel(_isDelivery
            ? context.t('delivery.company')
            : context.t('delivery.serviceType')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              PillChoice(
                  label: o.label,
                  selected: _company == o.value,
                  onTap: () => setState(() => _company = o.value)),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
            label: context.t('delivery.personName'),
            required: true,
            controller: _name,
            hint: context.t('delivery.personName')),
        const SizedBox(height: 16),
        AppTextField(
          label: context.t('common.phone'),
          required: true,
          controller: _phone,
          hint: context.t('common.phone'),
          keyboardType: TextInputType.phone,
          mono: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: context.t('visitor.flatNumber'),
          required: true,
          controller: _flat,
          hint: context.gt('gate.visitor.flatPlaceholder'),
          mono: true,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: context.t('delivery.vehicleOptional'),
          controller: _vehicle,
          hint: context.gt('gate.visitor.vehiclePlaceholder'),
          mono: true,
        ),
        const SizedBox(height: 16),
        PhotoCapture(
            photos: _photos,
            onChanged: (p) => setState(() => _photos = p),
            maxPhotos: 2,
            label: context.t('delivery.personPhoto')),
        const SizedBox(height: 24),
        AppButton(
            label: context.t('visitor.logEntry'),
            icon: Icons.photo_camera_outlined,
            loading: _saving,
            onPressed: _submit),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.primary : t.secondary,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? t.primaryForeground : t.secondaryForeground),
          ),
        ),
      ),
    );
  }
}
