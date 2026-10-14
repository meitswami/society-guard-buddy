/// Pure helpers for the Maintenance tab's `backup-export` calls
/// (web `handleExportBackup` / `describeBackupExportInvokeError`).
library;

/// Request body the web sends to `backup-export`.
Map<String, dynamic> backupExportBody(
        {String? societyId, bool completeDb = false, bool sendEmail = false}) =>
    {
      'society_id': societyId,
      'complete_db': completeDb,
      'send_email': sendEmail,
    };

/// File name for a manual download: the server's `filename` when it ends with `.json`,
/// otherwise `<backup|complete_database>_<Society_Name>_<yyyy-mm-dd>.json` (UTC date, like
/// `new Date().toISOString().split('T')[0]`).
String backupDownloadFileName({
  required bool completeDb,
  String? societyName,
  Object? serverFilename,
  DateTime? now,
}) {
  if (serverFilename is String && serverFilename.endsWith('.json')) {
    return serverFilename;
  }
  final socName = completeDb
      ? 'CompleteDatabase'
      : ((societyName != null && societyName.isNotEmpty)
          ? societyName
          : 'AllSocieties');
  final date =
      (now ?? DateTime.now()).toUtc().toIso8601String().split('T').first;
  final prefix = completeDb ? 'complete_database' : 'backup';
  return '${prefix}_${socName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$date.json';
}

/// Web `describeBackupExportInvokeError` for an HTTP failure of the edge function.
String describeBackupExportHttpError(int status, {String? serverMessage}) {
  if (status == 404) {
    return 'Edge Function backup-export was not found (404). Deploy it to this Supabase project: run `supabase functions deploy backup-export` from the repo, or use Dashboard → Edge Functions → Deploy.';
  }
  if (status == 401 || status == 403) {
    return 'Calling backup-export was rejected (401/403). Ensure supabase/config.toml has [functions.backup-export] verify_jwt = false, then run `supabase link` and `supabase functions deploy backup-export`.';
  }
  if (serverMessage != null && serverMessage.trim().isNotEmpty) {
    return serverMessage.trim();
  }
  return 'Edge function error ($status)';
}

/// Web wording for transport failures (function unreachable / not deployed).
String describeBackupExportNetworkError(String message) {
  final m = message.trim();
  final lower = m.toLowerCase();
  if (lower.contains('failed host lookup') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('fetch') ||
      lower.contains('network')) {
    return '$m If backup-export returns 404, the function is not deployed to this project.';
  }
  return m.isEmpty ? 'Backup export failed' : m;
}

/// Short summary of `backup.metadata` for the result card.
class BackupSummary {
  const BackupSummary(
      {this.societyName,
      this.totalTables,
      this.totalRecords,
      this.exportedAt,
      this.bytes});

  final String? societyName;
  final int? totalTables;
  final int? totalRecords;
  final String? exportedAt;
  final int? bytes;

  static int? _int(Object? v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  factory BackupSummary.fromMetadata(Object? metadata, {int? bytes}) {
    final m = metadata is Map ? metadata : const {};
    return BackupSummary(
      societyName: m['society_name']?.toString(),
      totalTables: _int(m['total_tables']),
      totalRecords: _int(m['total_records']),
      exportedAt: m['exported_at']?.toString(),
      bytes: bytes,
    );
  }
}

/// Human readable byte size (`12.4 MB`).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
