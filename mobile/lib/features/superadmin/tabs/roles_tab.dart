import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/superadmin_models.dart';
import '../logic/role_permissions.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/sa_widgets.dart';
import 'tab_page.dart';

/// Label for a permission key (web admin tab names, `adminNav.*`).
String permLabel(BuildContext context, AdminPerm p) => switch (p) {
      AdminPerm.residentsRw => context.t('adminNav.residents'),
      AdminPerm.guardsRw => context.t('adminNav.guards'),
      AdminPerm.geofenceRw => context.t('adminNav.geofence'),
      AdminPerm.finance => context.t('adminNav.finance'),
      AdminPerm.fixedAssets => context.t('adminNav.fixedAssets'),
      AdminPerm.donations => context.t('adminNav.donations'),
      AdminPerm.splits => context.st('sa.perm.splits'),
      AdminPerm.events => context.t('adminNav.events'),
      AdminPerm.meetings => context.t('adminNav.meetings'),
      AdminPerm.documents => context.t('adminNav.documents'),
      AdminPerm.committee => context.t('adminNav.committee'),
      AdminPerm.polls => context.t('adminNav.polls'),
      AdminPerm.notifications => context.t('adminNav.notify'),
      AdminPerm.parking => context.t('adminNav.parking'),
      AdminPerm.visitor => context.t('adminNav.visitor'),
      AdminPerm.delivery => context.t('adminNav.delivery'),
      AdminPerm.vehicle => context.t('adminNav.vehicles'),
      AdminPerm.blacklist => context.t('adminNav.blacklist'),
      AdminPerm.directory => context.t('adminNav.directory'),
      AdminPerm.quick => context.t('adminNav.quick'),
      AdminPerm.report => context.t('adminNav.reports'),
      AdminPerm.logs => context.t('adminNav.logs'),
      AdminPerm.audit => context.t('adminNav.audit'),
      AdminPerm.settings => context.t('adminNav.settings'),
      AdminPerm.password => context.t('adminNav.password'),
      AdminPerm.biometric => context.t('adminNav.biometric'),
    };

String permGroupLabel(BuildContext context, PermGroup g) => context.st('sa.permGroup.${g.name}');

/// Web Roles tab: per-society role list, add (locked-down defaults), delete — plus
/// rename and the permission matrix (`society_roles.permissions`).
class RolesTab extends StatefulWidget {
  const RolesTab({super.key, required this.ctx});

  final SuperadminTabContext ctx;

  @override
  State<RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<RolesTab> {
  final _newRole = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _newRole.dispose();
    super.dispose();
  }

  Future<void> _addRole(SuperadminConsole console) async {
    final name = _newRole.text.trim();
    if (name.isEmpty) {
      AppFeedback.toast(context, context.t('superadmin.roleNameRequired'), tone: BadgeTone.alert);
      return;
    }
    if (console.selectedSocietyId.isEmpty) {
      AppFeedback.toast(context, context.t('superadmin.selectSocietyFirst'), tone: BadgeTone.alert);
      return;
    }
    setState(() => _adding = true);
    final res = await console.repo.insertRole(console.selectedSocietyId, name);
    if (!mounted) return;
    setState(() => _adding = false);
    if (!res.ok) {
      AppFeedback.toast(
        context,
        res.duplicate
            ? context.t('superadmin.roleDuplicate')
            : ((res.message ?? '').isNotEmpty ? res.message! : context.t('superadmin.roleAddFailed')),
        tone: BadgeTone.alert,
      );
      return;
    }
    _newRole.clear();
    AppFeedback.toast(context, context.t('superadmin.roleAdded'), tone: BadgeTone.success);
    await console.loadAll();
  }

  Future<void> _deleteRole(SuperadminConsole console, SocietyRoleRow r) async {
    final users = console.adminsUsingRole(r.id);
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmDelete'),
      message: [
        r.roleName,
        if (users > 0) context.st('sa.roles.deleteInUse', {'count': users}),
        context.t('swal.confirmDeleteText'),
      ].join('\n\n'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await console.repo.deleteRole(r.id);
      if (mounted) await AppFeedback.success(context, title: context.t('swal.success'), message: context.st('sa.roles.deleted'));
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.st('sa.roles.deleteFailed'), tone: BadgeTone.alert);
    }
    await console.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final console = SuperadminScope.of(context);
    final roles = console.rolesFor(console.selectedSocietyId);
    return SuperadminTabPage(
      ctx: widget.ctx,
      showSocietySelector: true,
      onRefresh: console.loadAll,
      children: [
        SaTabTitle(context.t('superadmin.roles')),
        if (console.selectedSocietyId.isEmpty)
          Text(context.t('superadmin.selectSociety'), style: AppText.body(context).copyWith(color: context.tokens.mutedForeground))
        else ...[
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _newRole,
                  hint: context.t('superadmin.roleName'),
                  caps: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addRole(console),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: context.t('common.add'),
                expand: false,
                loading: _adding,
                onPressed: _adding ? null : () => _addRole(console),
              ),
            ],
          ),
          SaHint(context.st('sa.roles.newRoleHint'), padding: const EdgeInsets.only(top: 6, bottom: 12)),
          for (final r in roles)
            CardSection(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              onTap: () => RolePermissionsPage.open(context, console, r),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.roleName, style: AppText.bodyMedium(context)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            SaTag(
                              context.st('sa.roles.modules', {
                                'on': r.permissions.enabledCount,
                                'total': AdminPerm.values.length,
                              }),
                              primary: true,
                            ),
                            if (r.slug != null && r.slug!.isNotEmpty) SaTag(r.slug!),
                            SaTag(context.st('sa.roles.adminsCount', {'count': console.adminsUsingRole(r.id)})),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.st('sa.roles.editPermissions'),
                    icon: Icon(Icons.tune, size: 18, color: context.tokens.primary),
                    onPressed: () => RolePermissionsPage.open(context, console, r),
                  ),
                  IconButton(
                    tooltip: context.t('common.delete'),
                    icon: Icon(Icons.delete_outline, size: 18, color: context.tokens.destructive),
                    onPressed: () => _deleteRole(console, r),
                  ),
                ],
              ),
            ),
          if (roles.isEmpty) EmptyView(message: context.t('superadmin.noRoles')),
        ],
      ],
    );
  }
}

/// Permission matrix for one role (web `AdminPanelPermissions` keys incl. fixed_assets /
/// documents), with presets from the seeded roles, rename, and the resulting admin tabs.
class RolePermissionsPage extends StatefulWidget {
  const RolePermissionsPage({super.key, required this.console, required this.role});

  final SuperadminConsole console;
  final SocietyRoleRow role;

  static Future<void> open(BuildContext context, SuperadminConsole console, SocietyRoleRow role) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RolePermissionsPage(console: console, role: role)));

  @override
  State<RolePermissionsPage> createState() => _RolePermissionsPageState();
}

class _RolePermissionsPageState extends State<RolePermissionsPage> {
  late RolePermissions _perms = widget.role.permissions;
  late final RolePermissions _initial = widget.role.permissions;
  late final TextEditingController _name = TextEditingController(text: widget.role.roleName);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty => !_perms.sameAs(_initial) || _name.text.trim() != widget.role.roleName;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppFeedback.toast(context, context.t('superadmin.roleNameRequired'), tone: BadgeTone.alert);
      return;
    }
    setState(() => _saving = true);
    final res = await widget.console.repo.updateRole(
      widget.role.id,
      roleName: name != widget.role.roleName ? name : null,
      permissions: _perms,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.ok) {
      AppFeedback.toast(
        context,
        res.duplicate ? context.t('superadmin.roleDuplicate') : (res.message ?? context.st('sa.roles.saveFailed')),
        tone: BadgeTone.alert,
      );
      return;
    }
    AppFeedback.toast(context, context.st('sa.roles.saved'), tone: BadgeTone.success);
    await widget.console.loadAll();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _applyPreset() async {
    final picked = await showModalBottomSheet<RolePermissions>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: Text(ctx.st('sa.roles.presetFull')),
              onTap: () => Navigator.pop(ctx, RolePermissions.full),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(ctx.st('sa.roles.presetNew')),
              subtitle: Text(ctx.st('sa.roles.presetNewHint')),
              onTap: () => Navigator.pop(ctx, RolePermissions.newCustom),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(ctx.st('sa.roles.presetNone')),
              onTap: () => Navigator.pop(ctx, RolePermissions.all(false)),
            ),
            for (final tpl in kSeededRoleTemplates.skip(1))
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(ctx.tr(tpl.nameEn, tpl.nameHi)),
                subtitle: Text(ctx.st('sa.roles.presetSeeded')),
                onTap: () => Navigator.pop(ctx, tpl.permissions),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _perms = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final society = widget.console.societyById(widget.role.societyId);
    final tabs = allowedAdminTabs(_perms);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await AppFeedback.confirm(
          context,
          title: context.st('sa.unsavedTitle'),
          message: context.st('sa.unsavedText'),
        );
        if (leave && context.mounted) {
          setState(() => _perms = _initial);
          _name.text = widget.role.roleName;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.st('sa.roles.permissionsTitle')),
          actions: [
            TextButton.icon(
              onPressed: _applyPreset,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(context.st('sa.roles.presets')),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppButton(
              label: context.t('common.save'),
              icon: Icons.check,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
        body: PageContainer(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (society != null) Text(society.name, style: AppText.caption(context)),
            const SizedBox(height: 8),
            AppTextField(
              label: context.st('sa.roles.roleName'),
              controller: _name,
              caps: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            NoticeBanner(
              tone: BadgeTone.info,
              icon: Icons.info_outline,
              message: context.st('sa.roles.matrixHint', {'on': _perms.enabledCount, 'total': AdminPerm.values.length}),
            ),
            const SizedBox(height: 12),
            for (final entry in kPermGroups.entries) ...[
              CardSection(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(permGroupLabel(context, entry.key), style: AppText.sectionTitle(context))),
                        TextButton(
                          onPressed: () {
                            final allOn = entry.value.every((p) => _perms[p]);
                            setState(() {
                              for (final p in entry.value) {
                                _perms = _perms.withValue(p, !allOn);
                              }
                            });
                          },
                          child: Text(entry.value.every((p) => _perms[p]) ? context.st('sa.roles.noneInGroup') : context.st('sa.roles.allInGroup')),
                        ),
                      ],
                    ),
                    for (final p in entry.value)
                      ToggleRow(
                        label: permLabel(context, p),
                        subtitle: switch (p) {
                          AdminPerm.residentsRw || AdminPerm.guardsRw || AdminPerm.geofenceRw => context.st('sa.perm.rwHint'),
                          AdminPerm.splits => context.st('sa.perm.splitsHint'),
                          _ => p.key,
                        },
                        value: _perms[p],
                        onChanged: (v) => setState(() => _perms = _perms.withValue(p, v)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(context.st('sa.roles.visibleTabs'), style: AppText.fieldLabel(context)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tab in tabs) SaTag(tab, primary: tab != 'overview' && tab != 'tour')],
            ),
            const SizedBox(height: 8),
            Text(context.st('sa.roles.appliesNextLogin'), style: AppText.tiny(context).copyWith(color: t.mutedForeground)),
          ],
        ),
      ),
    );
  }
}
