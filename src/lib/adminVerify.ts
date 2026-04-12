import { supabase } from '@/integrations/supabase/client';

export async function verifyAdminPassword(adminId: string, password: string): Promise<boolean> {
  const trimmed = password.trim();
  if (!trimmed) return false;
  const { data, error } = await supabase
    .from('admins')
    .select('id')
    .eq('id', adminId)
    .eq('password', trimmed)
    .maybeSingle();
  if (error) {
    console.error('verifyAdminPassword', error);
    return false;
  }
  return !!data;
}
