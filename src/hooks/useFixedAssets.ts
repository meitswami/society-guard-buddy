import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useStore } from '@/store/useStore';
import {
  createFixedAsset,
  deleteFixedAsset,
  fetchExpenseGroupsForFixedAssets,
  fetchFixedAssets,
  seedStandardAssetTemplates,
  updateFixedAsset,
} from '@/services/fixedAssets/fixedAssetService';
import type { FixedAssetInput } from '@/lib/fixedAssetTypes';

export const fixedAssetQueryKeys = {
  all: (societyId: string) => ['fixed_assets', societyId] as const,
  groups: (societyId: string) => ['fixed_asset_groups', societyId] as const,
};

export function useFixedAssets() {
  const societyId = useStore((s) => s.societyId) ?? '';
  return useQuery({
    queryKey: fixedAssetQueryKeys.all(societyId),
    queryFn: () => fetchFixedAssets(societyId),
    enabled: !!societyId,
  });
}

export function useFixedAssetExpenseGroups() {
  const societyId = useStore((s) => s.societyId) ?? '';
  return useQuery({
    queryKey: fixedAssetQueryKeys.groups(societyId),
    queryFn: () => fetchExpenseGroupsForFixedAssets(societyId),
    enabled: !!societyId,
  });
}

export function useFixedAssetMutations(adminName: string) {
  const societyId = useStore((s) => s.societyId) ?? '';
  const qc = useQueryClient();

  const invalidate = () => {
    if (societyId) qc.invalidateQueries({ queryKey: fixedAssetQueryKeys.all(societyId) });
  };

  const seedTemplates = useMutation({
    mutationFn: () => seedStandardAssetTemplates(societyId, adminName),
    onSuccess: invalidate,
  });

  const create = useMutation({
    mutationFn: (input: FixedAssetInput) => createFixedAsset(societyId, input, adminName),
    onSuccess: invalidate,
  });

  const update = useMutation({
    mutationFn: ({ id, input }: { id: string; input: Partial<FixedAssetInput> }) =>
      updateFixedAsset(societyId, id, input),
    onSuccess: invalidate,
  });

  const remove = useMutation({
    mutationFn: (id: string) => deleteFixedAsset(societyId, id),
    onSuccess: invalidate,
  });

  return { seedTemplates, create, update, remove };
}
