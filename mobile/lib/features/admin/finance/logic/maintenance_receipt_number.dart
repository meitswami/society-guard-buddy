// Mirror of DB `format_maintenance_receipt_number` (receipt numbers are assigned by a trigger;
// the client only displays them).

String formatMaintenanceReceiptNumber(int seq) =>
    'MR-${seq.toString().padLeft(6, '0')}';

/// File-name safe receipt number (web `receiptNumber.replace(/[^\w.-]+/g, '_')`).
String safeReceiptFileToken(String receiptNumber) =>
    receiptNumber.replaceAll(RegExp(r'[^\w.-]+'), '_');
