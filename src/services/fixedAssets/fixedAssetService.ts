import { supabase } from '@/integrations/supabase/client';
import {
  STANDARD_SOCIETY_ASSET_TEMPLATES,
  type FixedAsset,
  type FixedAssetInput,
} from '@/lib/fixedAssetTypes';

export async function fetchFixedAssets(societyId: string): Promise<FixedAsset[]> {
  const { data, error } = await supabase
    .from('fixed_assets')
    .select('*')
    .eq('society_id', societyId)
    .order('sub_head')
    .order('asset_name');
  if (error) throw error;
  return (data ?? []) as FixedAsset[];
}

export async function seedStandardAssetTemplates(societyId: string, createdBy: string): Promise<number> {
  const { data: existing } = await supabase
    .from('fixed_assets')
    .select('template_key')
    .eq('society_id', societyId)
    .not('template_key', 'is', null);

  const existingKeys = new Set((existing ?? []).map((r) => r.template_key).filter(Boolean));

  const toInsert = STANDARD_SOCIETY_ASSET_TEMPLATES.filter((t) => !existingKeys.has(t.template_key)).map((t) => ({
    society_id: societyId,
    asset_name: t.asset_name,
    description: t.description,
    major_head: 'FIXED ASSETS',
    sub_head: t.sub_head,
    source_type: 'builder_handover' as const,
    status: 'placeholder' as const,
    location: t.location_hint,
    template_key: t.template_key,
    warranty_period_months: t.default_warranty_months ?? null,
    amc_period_months: t.default_amc_months ?? null,
    created_by: createdBy,
  }));

  if (toInsert.length === 0) return 0;

  const { error } = await supabase.from('fixed_assets').insert(toInsert);
  if (error) throw error;
  return toInsert.length;
}

export async function createFixedAsset(
  societyId: string,
  input: FixedAssetInput,
  createdBy: string,
): Promise<FixedAsset> {
  const { data, error } = await supabase
    .from('fixed_assets')
    .insert({
      society_id: societyId,
      ...input,
      major_head: input.major_head ?? 'FIXED ASSETS',
      source_type: input.source_type ?? 'manual',
      status: input.status ?? 'active',
      created_by: createdBy,
    })
    .select()
    .single();
  if (error) throw error;
  return data as FixedAsset;
}

export async function updateFixedAsset(
  societyId: string,
  id: string,
  input: Partial<FixedAssetInput>,
): Promise<FixedAsset> {
  const { data, error } = await supabase
    .from('fixed_assets')
    .update(input)
    .eq('id', id)
    .eq('society_id', societyId)
    .select()
    .single();
  if (error) throw error;
  return data as FixedAsset;
}

export async function deleteFixedAsset(societyId: string, id: string): Promise<void> {
  const { error } = await supabase.from('fixed_assets').delete().eq('id', id).eq('society_id', societyId);
  if (error) throw error;
}

export async function fetchExpenseGroupsForFixedAssets(societyId: string) {
  const { data, error } = await supabase
    .from('expense_groups')
    .select('id, name, major_head, description')
    .eq('society_id', societyId)
    .eq('group_kind', 'general')
    .order('name');
  if (error) throw error;
  return (data ?? []).filter(
    (g) => (g.major_head ?? '').trim() === 'FIXED ASSETS' || /asset|equipment|lift|dg|softener|softner|gym|garden|cctv|fire|boring|play/i.test(g.name),
  );
}
