-- Directory contact channels: email + notify opt-in on members;
-- society-level email/WhatsApp toggles for bills and due reminders.

ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS notify_whatsapp boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_email boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.members.email IS 'Directory email for notices, meetings, bills, and receipts.';
COMMENT ON COLUMN public.members.whatsapp_phone IS 'Directory WhatsApp for notices, meetings, bills, receipts, and emergency alerts; falls back to phone when null.';
COMMENT ON COLUMN public.members.notify_whatsapp IS 'When false, skip WhatsApp despatch for this member.';
COMMENT ON COLUMN public.members.notify_email IS 'When false, skip email despatch for this member.';

ALTER TABLE public.finance_reminder_settings
  ADD COLUMN IF NOT EXISTS auto_issue_email boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reminder_whatsapp boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reminder_email boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.finance_reminder_settings.auto_issue_email IS 'Send monthly bill notice by email to directory contacts.';
COMMENT ON COLUMN public.finance_reminder_settings.reminder_whatsapp IS 'Send overdue reminders by WhatsApp to directory contacts.';
COMMENT ON COLUMN public.finance_reminder_settings.reminder_email IS 'Send overdue reminders by email to directory contacts.';
