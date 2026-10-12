import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/ui/ui.dart';
import '../admin/core/admin_module.dart';
import 'core/comms_i18n.dart';
import 'data/geofence_math.dart';
import 'data/notification_media_storage.dart';
import 'data/settings_repository.dart';

/// Admin → Geofence. Port of web `GeofenceSetup`: capture the device GPS position, edit
/// latitude / longitude, radius 50–2000 m, save (update or insert `geofence_settings`) or clear.
class AdminGeofenceModule extends StatefulWidget {
  const AdminGeofenceModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminGeofenceModule> createState() => _AdminGeofenceModuleState();
}

class _AdminGeofenceModuleState extends State<AdminGeofenceModule> {
  final _repo = const SettingsRepository();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  GeofenceRow? _existing;
  bool _hasPoint = false;
  int _radius = kGeofenceDefaultRadius;
  double? _accuracy;
  bool _loading = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final g = await _repo.loadGeofence(widget.ctx.societyId);
      if (!mounted) return;
      setState(() {
        _existing = g;
        if (g != null) {
          _lat.text = '${g.latitude}';
          _lng.text = '${g.longitude}';
          _radius = g.radiusMeters;
          _hasPoint = true;
        }
      });
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    }
  }

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          await AppFeedback.error(context,
              title: context.t('admin.locationError'),
              message: context.ct('comms.geo.serviceOff'));
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        final open = await AppFeedback.confirm(
          context,
          title: context.t('admin.locationError'),
          message: context.ct('comms.geo.permission'),
          confirmLabel: context.ct('comms.geo.openSettings'),
          cancelLabel: context.t('common.cancel'),
        );
        if (open) await Geolocator.openAppSettings();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      if (!mounted) return;
      setState(() {
        _lat.text = '${pos.latitude}';
        _lng.text = '${pos.longitude}';
        _accuracy = pos.accuracy;
        _hasPoint = true;
      });
    } catch (e) {
      if (mounted) {
        await AppFeedback.error(context,
            title: context.t('admin.locationError'),
            message: '${context.t('admin.locationError')}: $e');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _save() async {
    final lat = parseCoordinate(_lat.text);
    final lng = parseCoordinate(_lng.text);
    if (!isValidLatitude(lat) || !isValidLongitude(lng)) {
      AppFeedback.toast(context, context.ct('comms.geo.invalid'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _loading = true);
    try {
      await _repo.saveGeofence(
        societyId: widget.ctx.societyId,
        existingId: _existing?.id,
        latitude: lat!,
        longitude: lng!,
        radius: _radius,
        setBy: widget.ctx.adminName,
      );
      await _loadExisting();
      if (mounted)
        await AppFeedback.success(context,
            title: context.t('swal.success'),
            message: context.t('admin.geofenceSaved'));
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context,
            context.ct('comms.geo.saveFailed', {'error': commsErrorMessage(e)}),
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    final g = _existing;
    if (g == null) return;
    final ok = await AppFeedback.confirm(
      context,
      title: context.ct('comms.geo.clearTitle'),
      message: context.ct('comms.geo.clearText'),
      confirmLabel: context.ct('comms.geo.clearYes'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.deleteGeofence(widget.ctx.societyId, g.id);
      if (!mounted) return;
      setState(() {
        _existing = null;
        _hasPoint = false;
        _lat.clear();
        _lng.clear();
        _radius = kGeofenceDefaultRadius;
        _accuracy = null;
      });
      await AppFeedback.success(context,
          title: context.ct('comms.geo.cleared'),
          message: context.ct('comms.geo.removed'));
    } catch (e) {
      if (mounted)
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final g = _existing;
    return PageContainer(
      onRefresh: _loadExisting,
      children: [
        PageHeader(
            title: context.t('admin.geofence'),
            subtitle: context.t('admin.geofenceSubtitle'),
            icon: Icons.location_on_outlined),
        CardSection(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('admin.currentLocation'),
                  style: AppText.sectionTitle(context)),
              const SizedBox(height: 12),
              if (g != null) ...[
                Text(
                    context.ct('comms.geo.latLng', {
                      'lat': formatCoordinate(g.latitude),
                      'lng': formatCoordinate(g.longitude)
                    }),
                    style: AppText.caption(context)),
                const SizedBox(height: 6),
                Text(
                    context.ct('comms.geo.radiusLine', {
                      'label': context.t('admin.radius'),
                      'm': g.radiusMeters
                    }),
                    style: AppText.caption(context)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                      value: 1,
                      minHeight: 8,
                      color: t.success,
                      backgroundColor: AppTokens.tint(t.success, 0.2)),
                ),
                const SizedBox(height: 8),
                Text('✅ ${context.t('admin.geofenceActive')}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: t.success)),
              ] else
                Text('⚠️ ${context.t('admin.noGeofence')}',
                    style: AppText.caption(context)),
            ],
          ),
        ),
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                icon: Icons.navigation_outlined,
                loading: _capturing,
                label: _capturing
                    ? context.t('admin.capturing')
                    : context.t('admin.captureLocation'),
                onPressed: _capturing ? null : _capture,
              ),
              if (_accuracy != null) ...[
                const SizedBox(height: 6),
                Text(
                    context.ct('comms.geo.accuracy', {'m': _accuracy!.round()}),
                    textAlign: TextAlign.center,
                    style: AppText.tiny(context)),
              ],
              if (_hasPoint) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: context.ct('comms.geo.lat'),
                        controller: _lat,
                        caps: false,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: context.ct('comms.geo.lng'),
                        controller: _lng,
                        caps: false,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('${context.t('admin.radius')} (${_radius}m)',
                    style: AppText.caption(context)),
                Slider(
                  value: _radius.toDouble().clamp(kGeofenceMinRadius.toDouble(),
                      kGeofenceMaxRadius.toDouble()),
                  min: kGeofenceMinRadius.toDouble(),
                  max: kGeofenceMaxRadius.toDouble(),
                  divisions: (kGeofenceMaxRadius - kGeofenceMinRadius) ~/
                      kGeofenceRadiusStep,
                  label: '${_radius}m',
                  onChanged: (v) =>
                      setState(() => _radius = snapGeofenceRadius(v)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${kGeofenceMinRadius}m',
                        style: AppText.tiny(context)),
                    Text('${kGeofenceMaxRadius}m',
                        style: AppText.tiny(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        icon: Icons.save_outlined,
                        loading: _loading,
                        label: _loading ? '...' : context.t('common.save'),
                        onPressed: _loading ? null : _save,
                      ),
                    ),
                    if (g != null) ...[
                      const SizedBox(width: 8),
                      IconPillButton(
                        icon: Icons.delete_outline,
                        tooltip: context.t('common.delete'),
                        color: t.destructive,
                        background: AppTokens.tint(t.destructive, 0.10),
                        onPressed: _clear,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
