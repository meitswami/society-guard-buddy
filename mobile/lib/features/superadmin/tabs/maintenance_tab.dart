import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../logic/backup_export.dart';
import '../superadmin_console.dart';
import '../superadmin_i18n.dart';
import 'tab_page.dart';

/// Web Maintenance tab: `backup-export` (all societies, complete DB, selected society,
/// e-mail backup) and the Danger Zone "Clear All Data & Go Production".
class MaintenanceTab extends StatefulWidget {
  const MaintenanceTab({super.key, required this.ctx});

  final SuperadminTabContext ctx;

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  bool _exporting = false;
  bool _clearing = false;
  BackupSummary? _last;
  String? _lastFile;

  Future<void> _export(SuperadminConsole console,
      {String? societyId,
      bool completeDb = false,
      bool sendEmail = false}) async {
    setState(() => _exporting = true);
    final res = await console.repo.backupExport(
        societyId: societyId, completeDb: completeDb, sendEmail: sendEmail);
    if (!mounted) return;
    try {
      if (res.error != null) {
        AppFeedback.toast(context, res.error!,
            tone: BadgeTone.alert, duration: const Duration(seconds: 6));
        return;
      }
      final data = res.data ?? const {};
      if (sendEmail) {
        final emailed = data['emailed'] == true;
        final note = data['email_note']?.toString();
        if (emailed) {
          AppFeedback.toast(context, context.st('sa.maint.emailed'),
              tone: BadgeTone.success);
        } else {
          AppFeedback.toast(
            context,
            (note != null && note.isNotEmpty)
                ? note
                : context.st('sa.maint.notEmailed'),
            tone: BadgeTone.alert,
            duration: const Duration(seconds: 6),
          );
        }
        setState(() => _last = BackupSummary.fromMetadata(data['metadata'],
            bytes: (data['byte_length'] as num?)?.toInt()));
        return;
      }
      final backup = data['backup'];
      if (backup == null) {
        AppFeedback.toast(context, context.st('sa.maint.unexpected'),
            tone: BadgeTone.alert, duration: const Duration(seconds: 6));
        return;
      }
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final bytes = Uint8List.fromList(utf8.encode(json));
      final name = backupDownloadFileName(
        completeDb: completeDb,
        societyName: console.societyById(societyId)?.name,
        serverFilename: data['filename'],
      );
      setState(() {
        _last = BackupSummary.fromMetadata(
            backup is Map ? backup['metadata'] : null,
            bytes: bytes.length);
        _lastFile = name;
      });
      await ExportKit.shareBytes(bytes, name, mimeType: 'application/json');
      if (mounted) {
        AppFeedback.toast(context, context.st('sa.maint.downloaded'),
            tone: BadgeTone.success);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, describeBackupExportNetworkError('$e'),
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clearAll(SuperadminConsole console) async {
    final confirmed = await AppFeedback.confirm(
      context,
      title: '⚠️ ${context.st('sa.maint.clearTitle')}',
      message: context.st('sa.maint.clearText'),
      confirmLabel: context.st('sa.maint.clearConfirm'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    // Mobile safety net: type CLEAR (a single tap would wipe every society's data).
    final typed = await AppFeedback.prompt(
      context,
      title: context.st('sa.maint.typeClearTitle'),
      message: context.st('sa.maint.typeClearText'),
      hint: 'CLEAR',
      confirmLabel: context.st('sa.maint.clearConfirm'),
    );
    if (!mounted || typed == null) return;
    if (typed.trim().toUpperCase() != 'CLEAR') {
      AppFeedback.toast(context, context.st('sa.maint.typeClearMismatch'),
          tone: BadgeTone.warning);
      return;
    }
    setState(() => _clearing = true);
    try {
      await console.repo.clearAllData();
      await console.loadAll();
      if (mounted) {
        await AppFeedback.success(context,
            title: context.t('swal.success'),
            message: context.st('sa.maint.cleared'));
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '${context.st('sa.maint.clearFailed')} $e',
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Widget _mono(String s) => Text(s,
      style: AppText.mono(context,
          size: 10, color: context.tokens.mutedForeground));

  @override
  Widget build(BuildContext context) {
    final console = SuperadminScope.of(context);
    final t = context.tokens;
    final selected = console.selectedSociety;
    return SuperadminTabPage(
      ctx: widget.ctx,
      showSocietySelector: true,
      onRefresh: console.loadAll,
      children: [
        SaTabTitle(context.st('sa.maint.title'), icon: Icons.storage_outlined),
        CardSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(context.st('sa.maint.backupTitle'),
                  icon: Icons.cloud_download_outlined),
              Text(context.st('sa.maint.backupText'),
                  style: AppText.caption(context)),
              const SizedBox(height: 12),
              AppButton(
                label: _exporting
                    ? context.st('sa.maint.exporting')
                    : context.st('sa.maint.exportAll'),
                icon: Icons.cloud_download_outlined,
                onPressed: _exporting ? null : () => _export(console),
              ),
              const SizedBox(height: 8),
              AppButton.secondary(
                label: _exporting
                    ? context.st('sa.maint.exporting')
                    : context.st('sa.maint.exportComplete'),
                icon: Icons.storage_outlined,
                onPressed: _exporting
                    ? null
                    : () => _export(console, completeDb: true),
              ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                AppButton.secondary(
                  label:
                      context.st('sa.maint.exportOne', {'name': selected.name}),
                  icon: Icons.cloud_download_outlined,
                  onPressed: _exporting
                      ? null
                      : () => _export(console, societyId: selected.id),
                ),
              ],
              const SizedBox(height: 8),
              AppButton(
                variant: AppButtonVariant.ghost,
                label: context.st('sa.maint.emailNow'),
                icon: Icons.mail_outline,
                dense: true,
                onPressed:
                    _exporting ? null : () => _export(console, sendEmail: true),
              ),
              if (_exporting) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator()
              ],
              if (_last != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.tint(t.success, 0.08),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    border: Border.all(color: AppTokens.tint(t.success, 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.st('sa.maint.lastExport'),
                          style: AppText.fieldLabel(context)),
                      if (_lastFile != null) _mono(_lastFile!),
                      KeyValueRow(context.st('sa.maint.society'),
                          _last!.societyName ?? ''),
                      KeyValueRow(context.st('sa.maint.tables'),
                          '${_last!.totalTables ?? '—'}'),
                      KeyValueRow(
                          context.st('sa.maint.records'),
                          _last!.totalRecords == null
                              ? '—'
                              : Fmt.number(_last!.totalRecords)),
                      if (_last!.bytes != null)
                        KeyValueRow(context.st('sa.maint.size'),
                            formatBytes(_last!.bytes!)),
                      if (_last!.exportedAt != null)
                        KeyValueRow(context.st('sa.maint.exportedAt'),
                            Fmt.dateTimeFull(_last!.exportedAt)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTokens.tint(t.warning, 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTokens.tint(t.warning, 0.3)),
                ),
                child: Text(context.st('sa.maint.deployHint'),
                    style:
                        TextStyle(fontSize: 10, height: 1.4, color: t.warning)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTokens.tint(t.muted, 0.5),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 12, color: t.mutedForeground),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(context.st('sa.maint.autoBackupHint'),
                            style:
                                AppText.tiny(context).copyWith(height: 1.4))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CardSection(
          borderColor: AppTokens.tint(t.destructive, 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(context.st('sa.maint.dangerZone'),
                  icon: Icons.warning_amber_rounded, iconColor: t.destructive),
              Text(context.st('sa.maint.dangerText'),
                  style: AppText.caption(context)),
              const SizedBox(height: 16),
              AppButton.destructive(
                label: context.st('sa.maint.clearButton'),
                icon: Icons.delete_outline,
                loading: _clearing,
                onPressed: _clearing ? null : () => _clearAll(console),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
