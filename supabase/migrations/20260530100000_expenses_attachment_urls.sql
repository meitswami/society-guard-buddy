-- Add attachment_urls jsonb column to expenses for multiple file uploads
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS attachment_urls jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.expenses.attachment_urls IS 'JSON array of URLs for bills, receipts, images, and documents attached to this expense.';
