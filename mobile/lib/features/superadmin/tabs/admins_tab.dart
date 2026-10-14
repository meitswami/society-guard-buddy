import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../utils/password_generator.dart';
import '../data/superadmin_audit.dart';
import '../data/superadmin_models.dart';
import '../logic/role_permissions.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import '../widgets/sa_widgets.dart';
import 'tab_page.dart';

/// Web Admins tab: admins of the selected society (role + society tags), add, delete —
/// plus edit (name / ID / e-mail / society / role) and password reset.
class AdminsTab extends StatefulWidget {
  const AdminsTab({super.key, required this.ctx});

  final SuperadminTabContext ctx;

  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  String _query = '';
  bool _allSocieties = false;

  Future<void> _delete(SuperadminConsole console, AdminRow a) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmDelete'),
      message:
          '${a.name} (${a.adminId})\n${context.t('swal.confirmDeleteText')}',
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await console.repo.deleteAdmin(a.id);
      if (mounted) {
        await AppFeedback.success(context,
            title: context.t('swal.success'),
            message: context.st('sa.admins.deleted'));
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(context, context.st('sa.admins.deleteFailed'),
            tone: BadgeTone.alert);
      }
    }
    await console.loadAll();
  }

  Future<void> _resetPassword(SuperadminConsole console, AdminRow a) async {
    final pw = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ResetPasswordSheet(admin: a),
    );
    if (pw == null || !mounted) return;
    final res = await console.repo.updateAdmin(a.id, {'password': pw});
    if (!mounted) return;
    if (!res.ok) {
      AppFeedback.toast(
          context, res.message ?? context.st('sa.admins.saveFailed'),
          tone: BadgeTone.alert);
      return;
    }
    SuperadminAudit.passwordReset(
      userType: 'admin',
      userId: a.id,
      userName: a.name,
      resetBy: 'superadmin:${widget.ctx.session.username}',
      societyId: a.societyId,
    );
    await console.loadAll();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded,
            color: ctx.tokens.success, size: 44),
        title:
            Text(ctx.t('admin.passwordChanged'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${a.name} · ${a.adminId}', style: AppText.caption(ctx)),
            const SizedBox(height: 8),
            SelectableText(pw,
                style: AppText.mono(ctx, size: 18, weight: FontWeight.w600)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
              onPressed: () => saCopy(ctx, pw),
              icon: const Icon(Icons.content_copy, size: 16),
              label: Text(ctx.st('sa.copy'))),
          TextButton.icon(
            onPressed: () => ExportKit.openWhatsApp(ctx.st(
                'sa.admins.shareCredentials',
                {'id': a.adminId, 'password': pw})),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: Text(ctx.t('mobile.share')),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final console = SuperadminScope.of(context);
    final scoped = _allSocieties
        ? console.admins
        : console.adminsFor(console.selectedSocietyId);
    final list = scoped.where((a) => a.matches(_query)).toList();
    final t = context.tokens;
    return SuperadminTabPage(
      ctx: widget.ctx,
      showSocietySelector: !_allSocieties,
      onRefresh: console.loadAll,
      children: [
        SaTabTitle(
          context.t('superadmin.admins'),
          actions: [
            SaTintButton(
              icon: Icons.add,
              tooltip: context.st('sa.admins.add'),
              onPressed: () => AdminFormPage.open(context, console,
                  defaultSocietyId: console.selectedSocietyId),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                hint: context.st('sa.admins.search'),
                prefixIcon: Icons.search,
                caps: false,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ToggleRow(
          label: context.st('sa.admins.allSocieties'),
          subtitle: context.st('sa.admins.allSocietiesHint'),
          value: _allSocieties,
          onChanged: (v) => setState(() => _allSocieties = v),
        ),
        const SizedBox(height: 8),
        for (final a in list)
          Builder(builder: (context) {
            final role = console.roleById(a.roleId);
            final society = console.societyById(a.societyId);
            return CardSection(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              onTap: () => AdminFormPage.open(context, console, admin: a),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: AppText.bodyMedium(context)),
                        Text(a.adminId,
                            style: AppText.mono(context,
                                size: 12, color: t.mutedForeground)),
                        if (a.email != null && a.email!.isNotEmpty)
                          Text(a.email!, style: AppText.caption(context)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (role != null)
                              SaTag(role.roleName, primary: true),
                            if (a.roleId == null)
                              SaTag(context.st('sa.admins.fullAccess'),
                                  primary: true),
                            if (society != null) SaTag(society.name),
                            if (a.societyId == null)
                              SaTag(context.st('sa.admins.noSociety')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: t.mutedForeground),
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          AdminFormPage.open(context, console, admin: a);
                        case 'password':
                          _resetPassword(console, a);
                        case 'delete':
                          _delete(console, a);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: Text(ctx.st('sa.admins.edit')))),
                      PopupMenuItem(
                        value: 'password',
                        child: ListTile(
                            leading: const Icon(Icons.lock_reset),
                            title: Text(ctx.st('sa.admins.resetPassword'))),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: ctx.tokens.destructive),
                          title: Text(ctx.t('common.delete'),
                              style: TextStyle(color: ctx.tokens.destructive)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        if (list.isEmpty) EmptyView(message: context.t('superadmin.noAdmins')),
      ],
    );
  }
}

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({required this.admin});

  final AdminRow admin;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _pw = TextEditingController(text: generateFlatPassword());
  String _error = '';

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.st('sa.admins.resetPassword'),
                style: AppText.sectionTitle(context)),
            Text('${widget.admin.name} · ${widget.admin.adminId}',
                style: AppText.caption(context)),
            const SizedBox(height: 12),
            AppTextField(
              label: context.t('admin.newPassword'),
              controller: _pw,
              caps: false,
              mono: true,
              suffix: IconButton(
                tooltip: context.st('sa.admins.generate'),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                onPressed: () =>
                    setState(() => _pw.text = generateFlatPassword()),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              SaErrorText(_error)
            ],
            const SizedBox(height: 16),
            AppButton(
              label: context.st('sa.admins.setPassword'),
              icon: Icons.lock_reset,
              onPressed: () {
                final v = _pw.text.trim();
                if (v.length < 4) {
                  setState(() => _error = context.t('admin.passwordTooShort'));
                  return;
                }
                Navigator.pop(context, v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit admin (web `showAdminForm` card; edit is mobile-only).
class AdminFormPage extends StatefulWidget {
  const AdminFormPage(
      {super.key, required this.console, this.admin, this.defaultSocietyId});

  final SuperadminConsole console;
  final AdminRow? admin;
  final String? defaultSocietyId;

  static Future<void> open(BuildContext context, SuperadminConsole console,
          {AdminRow? admin, String? defaultSocietyId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => AdminFormPage(
                console: console,
                admin: admin,
                defaultSocietyId: defaultSocietyId)),
      );

  @override
  State<AdminFormPage> createState() => _AdminFormPageState();
}

class _AdminFormPageState extends State<AdminFormPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.admin?.name ?? '');
  late final TextEditingController _adminId =
      TextEditingController(text: widget.admin?.adminId ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.admin?.email ?? '');
  late final TextEditingController _password = TextEditingController();
  late String _societyId =
      widget.admin?.societyId ?? (widget.defaultSocietyId ?? '');
  late String _roleId = widget.admin?.roleId ?? '';
  bool _saving = false;
  String _error = '';

  bool get _editing => widget.admin != null;

  @override
  void dispose() {
    _name.dispose();
    _adminId.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final console = widget.console;
    final name = _name.text;
    final adminId = _adminId.text;
    final email = _email.text;
    // Web `addAdmin`: name, admin ID, password and society are required.
    if (name.isEmpty ||
        adminId.isEmpty ||
        _societyId.isEmpty ||
        (!_editing && _password.text.isEmpty)) {
      setState(() => _error = context.st('sa.admins.required'));
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    final res = _editing
        ? await console.repo.updateAdmin(widget.admin!.id, {
            'name': name,
            'admin_id': adminId.toUpperCase(),
            'email': email.isEmpty ? null : email,
            'society_id': _societyId,
            'role_id': _roleId.isEmpty ? null : _roleId,
          })
        : await console.repo.insertAdmin(
            name: name,
            adminId: adminId,
            password: _password.text,
            societyId: _societyId,
            roleId: _roleId,
            email: email,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!res.ok) {
      setState(() => _error = res.duplicate
          ? context.st('sa.admins.duplicateId')
          : (res.message ?? context.st('sa.admins.saveFailed')));
      return;
    }
    AppFeedback.toast(
        context,
        _editing
            ? context.st('sa.admins.updated')
            : context.t('superadmin.adminAdded'),
        tone: BadgeTone.success);
    await console.loadAll();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final console = widget.console;
    final roles = console.rolesFor(_societyId);
    final selectedRole = console.roleById(_roleId.isEmpty ? null : _roleId);
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing
              ? context.st('sa.admins.edit')
              : context.st('sa.admins.add'))),
      body: PageContainer(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                    label: context.t('common.name'),
                    hint: context.t('common.name'),
                    controller: _name,
                    caps: false),
                const SizedBox(height: 12),
                AppTextField(
                  label: context.t('admin.adminId'),
                  hint: context.t('admin.adminId'),
                  controller: _adminId,
                  mono: true,
                  caps: false,
                  inputFormatters: const [UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: context.t('superadmin.adminEmail'),
                  hint: context.t('superadmin.adminEmail'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  caps: false,
                ),
                if (!_editing) ...[
                  const SizedBox(height: 12),
                  AppTextField(
                    label: context.t('login.password'),
                    hint: context.t('login.password'),
                    controller: _password,
                    caps: false,
                    suffix: IconButton(
                      tooltip: context.st('sa.admins.generate'),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      onPressed: () => setState(
                          () => _password.text = generateFlatPassword()),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: context.t('superadmin.selectSociety'),
                  items: [for (final s in console.societies) s.id],
                  value: _societyId.isEmpty ? null : _societyId,
                  hint: context.t('superadmin.selectSociety'),
                  labelOf: (id) => console.societyById(id)?.name ?? id,
                  onChanged: (v) => setState(() {
                    _societyId = v ?? '';
                    if (!console
                        .rolesFor(_societyId)
                        .any((r) => r.id == _roleId)) {
                      _roleId = '';
                    }
                  }),
                ),
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: context.t('superadmin.roles'),
                  items: ['', for (final r in roles) r.id],
                  value: _roleId,
                  labelOf: (id) => id.isEmpty
                      ? context.t('superadmin.noRole')
                      : (console.roleById(id)?.roleName ?? id),
                  onChanged: (v) => setState(() => _roleId = v ?? ''),
                ),
                SaHint(
                  selectedRole == null
                      ? context.st('sa.admins.noRoleHint')
                      : context.st('sa.roles.modules', {
                          'on': selectedRole.permissions.enabledCount,
                          'total': AdminPerm.values.length,
                        }),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SaErrorText(_error)
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: AppButton(
                            label: context.t('common.save'),
                            loading: _saving,
                            onPressed: _saving ? null : _save)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.secondary(
                          label: context.t('common.cancel'),
                          onPressed: () => Navigator.of(context).pop()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
