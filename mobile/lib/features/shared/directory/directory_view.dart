import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../utils/member_photo.dart';
import '../../../utils/phone_utils.dart';
import 'directory_models.dart';
import 'directory_search.dart';
import 'directory_service.dart';
import 'directory_widgets.dart';
import 'person_avatar.dart';

/// Society directory — port of web `src/pages/DirectoryPage.tsx` (guard + admin:
/// flats & members / visitors) and the resident directory tab of
/// `src/pages/ResidentDashboard.tsx` (`viewerRole: 'resident'`).
///
/// [viewerRole] is `'guard'`, `'resident'` or `'admin'`.
class DirectoryView extends StatefulWidget {
  const DirectoryView({
    super.key,
    required this.societyId,
    required this.viewerRole,
    this.viewerName,
    this.viewerFlatId,
    this.initialQuery,
    this.canEditResidents = false,
    this.onEditFlat,
    this.onOpenFamily,
    this.onOpenVehicles,
  });

  final String societyId;
  final String viewerRole;
  final String? viewerName;

  /// Resident's own flat (highlighted as "My Flat").
  final String? viewerFlatId;

  /// Search text handed over by global search.
  final String? initialQuery;

  /// Admin with Residents access: show an Edit action per flat.
  final bool canEditResidents;
  final ValueChanged<String>? onEditFlat;

  /// Resident "My Flat" shortcuts (web: switch to the Family / Vehicles tabs).
  final VoidCallback? onOpenFamily;
  final VoidCallback? onOpenVehicles;

  bool get isResident => viewerRole == 'resident';

  @override
  State<DirectoryView> createState() => _DirectoryViewState();
}

enum _ViewMode { flats, visitors }

class _DirectoryViewState extends State<DirectoryView> {
  final _service = DirectoryService();
  final _search = TextEditingController();
  DirectoryData _data = DirectoryData.empty;
  bool _loading = true;
  Object? _error;
  String? _expandedId;
  _ViewMode _mode = _ViewMode.flats;

  Map<String, List<PeopleMember>> _byFlat = const {};
  Map<String, List<PeopleVehicle>> _byNumber = const {};
  List<VisitorDirectoryEntry> _visitorDir = const [];

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) _search.text = q;
    _load();
  }

  @override
  void didUpdateWidget(covariant DirectoryView old) {
    super.didUpdateWidget(old);
    if (widget.initialQuery != old.initialQuery &&
        (widget.initialQuery ?? '').trim().isNotEmpty) {
      _search.text = widget.initialQuery!.trim();
    }
    if (widget.societyId != old.societyId ||
        widget.viewerRole != old.viewerRole) {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data.flats.isEmpty;
      _error = null;
    });
    try {
      final data = widget.isResident
          ? await _service.loadResidentDirectory(widget.societyId)
          : await _service.loadStaffDirectory(widget.societyId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _byFlat = membersByFlatId(data.members);
        _byNumber = vehiclesByFlatNumber(data.vehicles);
        _visitorDir = buildVisitorDirectory(data.visitors);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSearch(String _) => setState(() {});

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _data.flats.isEmpty) return ErrorView(onRetry: _load);
    return widget.isResident ? _buildResident(context) : _buildStaff(context);
  }

  // ---- Guard / admin -------------------------------------------------------
  Widget _buildStaff(BuildContext context) {
    final t = context.tokens;
    final query = _search.text;
    final flats = _mode == _ViewMode.flats
        ? filterDirectoryFlats(
            flats: _data.flats,
            membersByFlat: _byFlat,
            vehiclesByFlat: _byNumber,
            query: query)
        : const <PeopleFlat>[];
    final visitors = _mode == _ViewMode.visitors
        ? filterVisitorDirectory(_visitorDir, query)
        : const <VisitorDirectoryEntry>[];
    final count = _mode == _ViewMode.flats ? flats.length : visitors.length;

    final header = <Widget>[
      PageHeader(
        icon: Icons.contacts_outlined,
        title: context.t('directory.title'),
        subtitle: _mode == _ViewMode.flats
            ? context.tr(
                '${_data.flats.length} flats', '${_data.flats.length} फ्लैट')
            : '${_visitorDir.length} ${context.t('directory.registeredVisitors')}',
        bottomSpacing: 16,
      ),
      Row(
        children: [
          Expanded(
            child: _ModeButton(
              icon: Icons.home_outlined,
              label: context.tr('Flats & Members', 'फ्लैट और सदस्य'),
              selected: _mode == _ViewMode.flats,
              onTap: () => setState(() {
                _mode = _ViewMode.flats;
                _expandedId = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              icon: Icons.groups_outlined,
              label: context.t('dashboard.visitors'),
              selected: _mode == _ViewMode.visitors,
              onTap: () => setState(() {
                _mode = _ViewMode.visitors;
                _expandedId = null;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      DirectorySearchField(
          controller: _search,
          hint: context.t('directory.searchPlaceholder'),
          onChanged: _onSearch),
      const SizedBox(height: 16),
      if (widget.canEditResidents &&
          widget.onEditFlat != null &&
          _mode == _ViewMode.flats)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            TextSpan(style: AppText.caption(context), children: [
              TextSpan(text: context.tr('Tap ', 'फ्लैट पर ')),
              TextSpan(
                text: context.tr('Edit', 'संपादित करें'),
                style:
                    TextStyle(fontWeight: FontWeight.w500, color: t.foreground),
              ),
              TextSpan(
                text: context.tr(
                  ' on a flat to manage members, vehicles, and flat details.',
                  ' दबाकर सदस्य, वाहन और फ्लैट विवरण प्रबंधित करें।',
                ),
              ),
            ]),
          ),
        ),
      if (count == 0)
        EmptyView(
          message: _mode == _ViewMode.flats
              ? context.tr('No flats found', 'कोई फ्लैट नहीं मिला')
              : context.t('directory.noVisitors'),
        ),
    ];

    return LazyListPage(
      onRefresh: _load,
      header: header,
      itemCount: count,
      itemBuilder: (context, i) => _mode == _ViewMode.flats
          ? _staffFlatCard(context, flats[i], query)
          : _visitorCard(context, visitors[i]),
    );
  }

  Widget _staffFlatCard(BuildContext context, PeopleFlat flat, String query) {
    final t = context.tokens;
    final expanded = _expandedId == flat.id;
    final members = _byFlat[flat.id] ?? const [];
    final vehicles = _byNumber[flat.flatNumber] ?? const [];
    final hits = directoryNameHits(members, query);
    return CardSection(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expandedId = expanded ? null : flat.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _FlatIcon(
                    background: flat.isOccupied
                        ? AppTokens.tint(t.primary, 0.1)
                        : t.muted,
                    iconColor: flat.isOccupied ? t.primary : t.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(flat.flatNumber,
                                style: AppText.mono(context,
                                    size: 14, weight: FontWeight.w600)),
                            if (flat.wing != null)
                              TagChip(context.tr(
                                  'Wing ${flat.wing}', 'विंग ${flat.wing}')),
                            if (!flat.isOccupied)
                              TagChip.warning(
                                  context, context.tr('Vacant', 'खाली')),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${flat.ownerName ?? context.tr('No owner', 'कोई मालिक नहीं')} · '
                          '${context.tr('${members.length} members', '${members.length} सदस्य')} · '
                          '${context.tr('${vehicles.length} vehicles', '${vehicles.length} वाहन')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(context),
                        ),
                        NameHitChips(members: hits),
                      ],
                    ),
                  ),
                  if (widget.canEditResidents && widget.onEditFlat != null)
                    TintIconButton(
                      icon: Icons.edit_outlined,
                      filled: false,
                      padding: 6,
                      tooltip: context.tr('Edit flat ${flat.flatNumber}',
                          'फ्लैट ${flat.flatNumber} संपादित करें'),
                      onPressed: () => widget.onEditFlat!(flat.id),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: t.mutedForeground),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.border))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TwoColGrid(children: [
                    InfoPair(context.tr('Floor', 'मंज़िल'), flat.floor ?? '-'),
                    InfoPair(context.tr('Type', 'प्रकार'),
                        _capitalize(flat.flatType)),
                    if (flat.intercom != null)
                      InfoPair(
                          context.tr('Intercom', 'इंटरकॉम'), flat.intercom!,
                          mono: true),
                    if (flat.ownerPhone != null)
                      _PhoneLink(phone: flat.ownerPhone!),
                  ]),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TinyLabel(context.tr('Members (${members.length})',
                        'सदस्य (${members.length})')),
                    const SizedBox(height: 6),
                    for (final m in members)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _StaffMemberRow(member: m)),
                  ],
                  if (vehicles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    TinyLabel(context.tr('Vehicles (${vehicles.length})',
                        'वाहन (${vehicles.length})')),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final v in vehicles)
                        VehicleChip(
                            number: v.vehicleNumber, type: v.vehicleType),
                    ]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _visitorCard(BuildContext context, VisitorDirectoryEntry e) {
    final t = context.tokens;
    final v = e.latest;
    final key = 'visitor:${v.phone}';
    final expanded = _expandedId == key;
    final photo = v.visitorPhotos.isNotEmpty ? v.visitorPhotos.first : null;
    final provider = memberPhotoProvider(photo);
    return CardSection(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expandedId = expanded ? null : key),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: t.secondary, shape: BoxShape.circle),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: provider != null
                        ? Image(
                            image: provider,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            gaplessPlayback: true)
                        : Text(
                            v.name.isEmpty
                                ? '?'
                                : v.name.characters.first.toUpperCase(),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: t.mutedForeground),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sectionTitle(context)),
                        Text(v.phone,
                            style: AppText.mono(context,
                                size: 12, color: t.mutedForeground)),
                      ],
                    ),
                  ),
                  Text('${e.totalVisits}x',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: t.primary)),
                  const SizedBox(width: 8),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: t.mutedForeground),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.border))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (v.visitorPhotos.isNotEmpty) ...[
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in v.visitorPhotos)
                        ImageThumb(
                            src: p,
                            width: 80,
                            height: 80,
                            radius: AppTokens.radiusSm),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  TwoColGrid(children: [
                    InfoPair(context.t('common.flat'), v.flatNumber),
                    InfoPair(context.t('directory.category'),
                        _capitalize(v.category)),
                    InfoPair(
                      context.t('directory.document'),
                      '${v.documentType}${v.documentNumber.isNotEmpty ? ' — ${v.documentNumber}' : ''}',
                    ),
                    InfoPair(context.t('visitor.purpose'), v.purpose),
                    if (v.vehicleNumber != null)
                      InfoPair(context.t('blacklist.vehicle'), v.vehicleNumber!,
                          mono: true),
                    InfoPair(context.t('directory.firstVisit'),
                        Fmt.date(e.firstVisit)),
                    InfoPair(context.t('directory.lastVisit'),
                        Fmt.date(v.entryTime)),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- Resident -------------------------------------------------------------
  Widget _buildResident(BuildContext context) {
    final t = context.tokens;
    final query = _search.text;
    final flats = filterResidentDirectoryFlats(
        flats: _data.flats,
        membersByFlat: _byFlat,
        vehiclesByFlat: _byNumber,
        query: query);
    final header = <Widget>[
      PageHeader(
        icon: Icons.contacts_outlined,
        title: context.t('resident.directory'),
        subtitle: context.tr(
            '${_data.flats.length} flats', '${_data.flats.length} फ्लैट'),
        bottomSpacing: 16,
      ),
      DirectorySearchField(
        controller: _search,
        hint: context.tr(
            'Search flats, names, phone...', 'फ्लैट, नाम, फोन खोजें...'),
        onChanged: _onSearch,
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(style: AppText.tiny(context), children: [
          TextSpan(
              text: context.tr('${flats.length} flats · Expand ',
                  '${flats.length} फ्लैट · अपना घर प्रबंधित करने के लिए ')),
          TextSpan(
            text: context.tr('My Flat', 'मेरा फ्लैट'),
            style: TextStyle(fontWeight: FontWeight.w500, color: t.primary),
          ),
          TextSpan(text: context.tr(' to manage your household', ' खोलें')),
        ]),
      ),
      const SizedBox(height: 12),
      if (flats.isEmpty)
        EmptyView(message: context.tr('No flats found', 'कोई फ्लैट नहीं मिला')),
    ];
    return LazyListPage(
      onRefresh: _load,
      header: header,
      itemCount: flats.length,
      itemBuilder: (context, i) => _residentFlatCard(context, flats[i], query),
    );
  }

  Widget _residentFlatCard(
      BuildContext context, PeopleFlat flat, String query) {
    final t = context.tokens;
    final isMine = flat.id == widget.viewerFlatId;
    final expanded = _expandedId == flat.id;
    final members = _byFlat[flat.id] ?? const [];
    final vehicles = _byNumber[flat.flatNumber] ?? const [];
    final hits = residentNameHits(members, query);
    return CardSection(
      padding: EdgeInsets.zero,
      borderColor: isMine ? AppTokens.tint(t.primary, 0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expandedId = expanded ? null : flat.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _FlatIcon(
                    background: AppTokens.tint(t.primary, isMine ? 0.2 : 0.1),
                    iconColor: isMine ? t.primary : t.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(flat.flatNumber,
                                style: AppText.mono(context,
                                    size: 14, weight: FontWeight.w600)),
                            if (isMine)
                              TagChip.primary(
                                  context, context.tr('My Flat', 'मेरा फ्लैट')),
                            if (flat.wing != null)
                              TagChip(context.tr(
                                  'Wing ${flat.wing}', 'विंग ${flat.wing}')),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${flat.ownerName ?? context.tr('No owner', 'कोई मालिक नहीं')} · '
                          '${context.tr('${members.length} members', '${members.length} सदस्य')} · '
                          '${context.tr('${vehicles.length} vehicles', '${vehicles.length} वाहन')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(context),
                        ),
                        NameHitChips(members: hits, showOverflow: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.border))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMine &&
                      (widget.onOpenFamily != null ||
                          widget.onOpenVehicles != null))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        if (widget.onOpenFamily != null)
                          AppButton(
                            label: context.tr('Manage family & staff',
                                'परिवार और स्टाफ़ प्रबंधित करें'),
                            icon: Icons.groups_outlined,
                            dense: true,
                            expand: false,
                            onPressed: widget.onOpenFamily,
                          ),
                        if (widget.onOpenVehicles != null)
                          AppButton.secondary(
                            label: context.tr(
                                'Manage vehicles', 'वाहन प्रबंधित करें'),
                            icon: Icons.directions_car_outlined,
                            dense: true,
                            expand: false,
                            onPressed: widget.onOpenVehicles,
                          ),
                      ]),
                    ),
                  for (final m in members)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MemberTile(
                        member: m,
                        subtitle: [
                          _capitalize(m.relation),
                          if (m.age != null) '${m.age}y',
                          if (m.phone != null) '📱${m.phone}',
                        ].join(' · '),
                      ),
                    ),
                  if (vehicles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final v in vehicles)
                          VehicleChip(number: v.vehicleNumber),
                      ]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _capitalize(String s) => s.replaceAllMapped(
    RegExp(r'(^|[\s\-_/(])(\p{L})', unicode: true),
    (m) => '${m[1]}${m[2]!.toUpperCase()}');

class _ModeButton extends StatelessWidget {
  const _ModeButton(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.primaryForeground : t.secondaryForeground;
    return Material(
      color: selected ? t.primary : t.secondary,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatIcon extends StatelessWidget {
  const _FlatIcon({required this.background, required this.iconColor});

  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Icon(Icons.home_outlined, size: 20, color: iconColor),
    );
  }
}

class _PhoneLink extends StatelessWidget {
  const _PhoneLink({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => ExportKit.call(phone),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_outlined, size: 12, color: t.mutedForeground),
          const SizedBox(width: 4),
          Flexible(
              child: Text(phone,
                  style: AppText.mono(context,
                      size: 12, weight: FontWeight.w600, color: t.primary))),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile(
      {required this.member, required this.subtitle, this.trailing});

  final PeopleMember member;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppTokens.tint(t.secondary, 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(
        children: [
          PersonAvatar(
              name: member.name,
              photo: member.photo,
              size: PersonAvatarSize.xs),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: member.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: t.foreground)),
                    if (member.isPrimary)
                      TextSpan(
                          text: ' ★',
                          style: TextStyle(fontSize: 9, color: t.primary)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppText.tiny(context)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Guard / admin member row with call, WhatsApp and email actions.
class _StaffMemberRow extends StatelessWidget {
  const _StaffMemberRow({required this.member});

  final PeopleMember member;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = member;
    final parts = <String>[
      _capitalize(m.relation),
      if (m.age != null) '${m.age}y',
      if (m.gender != null) _capitalize(m.gender!),
      if (m.whatsappPhone != null) 'WA ${m.whatsappPhone}',
      if (m.email != null) m.email!,
    ];
    final waPhone = m.whatsappPhone ?? m.phone;
    return _MemberTile(
      member: m,
      subtitle: parts.join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.phone != null)
            _MiniAction(
                icon: Icons.phone_outlined,
                color: t.primary,
                tooltip: context.tr('Call', 'कॉल'),
                onTap: () => ExportKit.call(m.phone!)),
          if (waPhone != null)
            _MiniAction(
              icon: Icons.chat_outlined,
              color: t.success,
              tooltip: 'WhatsApp',
              onTap: () =>
                  ExportKit.openUrl('https://wa.me/${waMeDigits(waPhone)}'),
            ),
          if (m.email != null)
            _MiniAction(
                icon: Icons.mail_outline,
                color: t.primary,
                tooltip: context.tr('Email', 'ईमेल'),
                onTap: () => ExportKit.email(m.email!)),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction(
      {required this.icon,
      required this.color,
      required this.onTap,
      required this.tooltip});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 15, color: color)),
      ),
    );
  }
}
