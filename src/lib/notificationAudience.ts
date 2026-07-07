/** Whether a notification row is visible to a resident (flat / person / society-wide). */
export function notificationVisibleToResident(
  row: { target_type?: string | null; target_id?: string | null },
  resident: { id: string; name: string },
  flatNumber: string,
): boolean {
  const targetType = String(row.target_type ?? '');
  const targetId = String(row.target_id ?? '').trim();
  if (targetType === 'all') return true;
  if (targetType === 'flat') {
    if (targetId === flatNumber) return true;
    if (targetId.includes(',')) {
      return targetId.split(',').map((s) => s.trim()).includes(flatNumber);
    }
  }
  if (targetType === 'user') {
    if (targetId === resident.id) return true;
    if (targetId === resident.name) return true;
    if (targetId.includes(',')) {
      const parts = targetId.split(',').map((s) => s.trim());
      return parts.includes(resident.id) || parts.includes(resident.name);
    }
  }
  return false;
}

export const NOTIFICATION_TYPE_LABELS: Record<string, string> = {
  general: 'Notice',
  payment_reminder: 'Payment',
  event: 'Event',
  event_reminder: 'Reminder',
  poll: 'Poll',
  alert: 'Alert',
};
