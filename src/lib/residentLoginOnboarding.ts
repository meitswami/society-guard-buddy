import Swal from 'sweetalert2';
import { supabase } from '@/integrations/supabase/client';
import { generateFlatPassword } from '@/lib/passwordGenerator';
import { allowsPrimaryMember, allowsResidentLogin, isRestrictedMemberCategory } from '@/lib/memberCategories';
import { getSwalThemeColors, confirmAction } from '@/lib/swal';

export type ResidentLoginPayload = {
  id: string;
  name: string;
  phone: string;
  flatId: string;
  flatNumber: string;
  openFamilyTab?: boolean;
};

type MemberRow = {
  id: string;
  flat_id: string;
  name: string;
  phone: string | null;
  relation: string | null;
  gender: string | null;
  is_primary: boolean | null;
};

export function normalizeLoginPhone(phone: string): string {
  const d = phone.replace(/\D/g, '');
  return d.length <= 10 ? d : d.slice(-10);
}

function swalBase() {
  const theme = getSwalThemeColors();
  return {
    background: theme.background,
    color: theme.color,
    confirmButtonColor: theme.confirmButtonColor,
    cancelButtonColor: theme.cancelButtonColor,
    customClass: { popup: 'rounded-2xl' },
  };
}

const RELATION_OPTIONS_HTML = `
  <optgroup label="Household">
    <option value="owner">Owner</option>
    <option value="spouse">Spouse</option>
    <option value="son">Son</option>
    <option value="daughter">Daughter</option>
    <option value="father">Father</option>
    <option value="mother">Mother</option>
    <option value="family">Family</option>
    <option value="tenant">Tenant</option>
    <option value="other">Other</option>
  </optgroup>
  <optgroup label="Staff / service">
    <option value="cook">Cook</option>
    <option value="maid">Maid</option>
    <option value="washerman">Washerman</option>
    <option value="newspaper">Newspaper</option>
    <option value="driver">Driver</option>
  </optgroup>
`;

async function readFileAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onloadend = () => resolve(String(r.result ?? ''));
    r.onerror = () => reject(new Error('read'));
    r.readAsDataURL(file);
  });
}

async function ensureResidentUserRow(
  flatId: string,
  flatNumber: string,
  phone: string,
  name: string,
  mustChangePassword: boolean,
): Promise<ResidentLoginPayload | null> {
  const normalized = normalizeLoginPhone(phone);
  const { data: existing } = await supabase
    .from('resident_users')
    .select('*')
    .eq('flat_id', flatId)
    .eq('phone', normalized)
    .maybeSingle();
  if (existing) {
    await supabase.from('resident_users').update({ name }).eq('id', existing.id);
    return {
      id: existing.id,
      name,
      phone: normalized,
      flatId: existing.flat_id,
      flatNumber: existing.flat_number,
    };
  }
  const { data: flatMate } = await supabase.from('resident_users').select('password').eq('flat_id', flatId).limit(1).maybeSingle();
  const password = flatMate?.password ?? generateFlatPassword();
  const { data: ins, error } = await supabase
    .from('resident_users')
    .insert({
      flat_id: flatId,
      flat_number: flatNumber,
      name,
      phone: normalized,
      password,
      must_change_password: mustChangePassword,
    })
    .select('*')
    .single();
  if (error || !ins) return null;
  return {
    id: ins.id,
    name: ins.name,
    phone: ins.phone,
    flatId: ins.flat_id,
    flatNumber: ins.flat_number,
  };
}

function pickPrimaryMember(members: MemberRow[]): MemberRow | null {
  const prim = members.find((m) => m.is_primary);
  if (prim) return prim;
  const household = members.filter((m) => allowsPrimaryMember(m.relation));
  return household[0] ?? null;
}

/** First-time primary for an empty flat: name + optional gender. */
async function swalFirstPrimaryName(t: (k: string) => string): Promise<{ name: string; gender: string } | null> {
  const result = await Swal.fire({
    ...swalBase(),
    title: t('login.onboard.firstPrimaryTitle'),
    html: `
      <p class="text-sm text-left mb-3 opacity-90">${t('login.onboard.firstPrimaryBody')}</p>
      <input id="sgb-onb-name" class="swal2-input" placeholder="${t('login.onboard.fullName')}" maxlength="120" />
      <select id="sgb-onb-gender" class="swal2-input" style="margin-top:8px">
        <option value="">${t('login.onboard.genderOptional')}</option>
        <option value="Male">Male</option>
        <option value="Female">Female</option>
        <option value="Other">Other</option>
      </select>
    `,
    focusConfirm: false,
    showCancelButton: true,
    confirmButtonText: t('common.save'),
    cancelButtonText: t('common.cancel'),
    preConfirm: () => {
      const name = (document.getElementById('sgb-onb-name') as HTMLInputElement)?.value?.trim() ?? '';
      if (!name) {
        Swal.showValidationMessage(t('login.onboard.nameRequired'));
        return false;
      }
      const gender = (document.getElementById('sgb-onb-gender') as HTMLSelectElement)?.value ?? '';
      return { name, gender };
    },
  });
  if (!result.isConfirmed || !result.value) return null;
  return result.value as { name: string; gender: string };
}

async function swalNewHouseholdMember(t: (k: string) => string): Promise<{
  name: string;
  relation: string;
  gender: string;
  idPhotoFront?: string;
  idPhotoBack?: string;
  policeVerification?: string;
} | null> {
  const result = await Swal.fire({
    ...swalBase(),
    title: t('login.onboard.newMemberTitle'),
    html: `
      <p class="text-sm text-left mb-2 opacity-90">${t('login.onboard.newMemberBody')}</p>
      <input id="sgb-nm-name" class="swal2-input" placeholder="${t('login.onboard.fullName')}" />
      <select id="sgb-nm-relation" class="swal2-input" style="margin-top:8px">${RELATION_OPTIONS_HTML}</select>
      <select id="sgb-nm-gender" class="swal2-input" style="margin-top:8px">
        <option value="">${t('login.onboard.selectGender')}</option>
        <option value="Male">Male</option>
        <option value="Female">Female</option>
        <option value="Other">Other</option>
      </select>
    `,
    focusConfirm: false,
    showCancelButton: true,
    confirmButtonText: t('common.save'),
    cancelButtonText: t('common.cancel'),
    preConfirm: () => {
      const name = (document.getElementById('sgb-nm-name') as HTMLInputElement)?.value?.trim() ?? '';
      const relation = (document.getElementById('sgb-nm-relation') as HTMLSelectElement)?.value ?? '';
      const gender = (document.getElementById('sgb-nm-gender') as HTMLSelectElement)?.value ?? '';
      if (!name) {
        Swal.showValidationMessage(t('login.onboard.nameRequired'));
        return false;
      }
      if (!relation) {
        Swal.showValidationMessage(t('login.onboard.relationRequired'));
        return false;
      }
      if (!gender) {
        Swal.showValidationMessage(t('login.onboard.genderRequired'));
        return false;
      }
      return { name, relation, gender };
    },
  });
  if (!result.isConfirmed || !result.value) return null;
  const base = result.value as { name: string; relation: string; gender: string };
  if (!isRestrictedMemberCategory(base.relation)) return { ...base };

  const staff = await Swal.fire({
    ...swalBase(),
    title: t('login.onboard.staffExtraTitle'),
    html: `
      <p class="text-xs text-left mb-2 opacity-90">${t('login.onboard.staffExtraBody')}</p>
      <label class="text-xs block text-left mb-1">${t('login.onboard.idFront')}</label>
      <input type="file" id="sgb-nm-idf" accept="image/*" class="swal2-file" />
      <label class="text-xs block text-left mt-2 mb-1">${t('login.onboard.idBackOptional')}</label>
      <input type="file" id="sgb-nm-idb" accept="image/*" class="swal2-file" />
      <select id="sgb-nm-police" class="swal2-input" style="margin-top:8px">
        <option value="pending">Police: Pending</option>
        <option value="submitted">Police: Submitted</option>
        <option value="verified">Police: Verified</option>
      </select>
    `,
    focusConfirm: false,
    showCancelButton: true,
    confirmButtonText: t('common.save'),
    cancelButtonText: t('common.cancel'),
    preConfirm: async () => {
      const fin = (document.getElementById('sgb-nm-idf') as HTMLInputElement)?.files?.[0];
      if (!fin) {
        Swal.showValidationMessage(t('login.onboard.idFrontRequired'));
        return false;
      }
      const fb = (document.getElementById('sgb-nm-idb') as HTMLInputElement)?.files?.[0];
      const idPhotoFront = await readFileAsDataUrl(fin);
      const idPhotoBack = fb ? await readFileAsDataUrl(fb) : '';
      const policeVerification = (document.getElementById('sgb-nm-police') as HTMLSelectElement)?.value ?? 'pending';
      return { idPhotoFront, idPhotoBack, policeVerification };
    },
  });
  if (!staff.isConfirmed || !staff.value) return null;
  const extra = staff.value as { idPhotoFront: string; idPhotoBack: string; policeVerification: string };
  return { ...base, ...extra };
}

/**
 * After OTP verifies `phone`, completes resident login for the chosen flat
 * (member linking, SWAL prompts, resident_users row).
 */
export async function completeResidentOtpOnboarding(
  phoneRaw: string,
  flatId: string,
  flatNumber: string,
  t: (key: string) => string,
): Promise<ResidentLoginPayload | null> {
  const phone = normalizeLoginPhone(phoneRaw);

  const { data: existingUser } = await supabase
    .from('resident_users')
    .select('*')
    .eq('flat_id', flatId)
    .eq('phone', phone)
    .maybeSingle();
  if (existingUser) {
    return {
      id: existingUser.id,
      name: existingUser.name,
      phone: existingUser.phone,
      flatId: existingUser.flat_id,
      flatNumber: existingUser.flat_number,
    };
  }

  const { data: memberRows } = await supabase.from('members').select('*').eq('flat_id', flatId);
  const members = (memberRows ?? []) as MemberRow[];

  if (members.length === 0) {
    const first = await swalFirstPrimaryName(t);
    if (!first) return null;
    const { error: mErr } = await supabase.from('members').insert({
      flat_id: flatId,
      name: first.name,
      phone,
      relation: 'owner',
      gender: first.gender || null,
      is_primary: true,
    });
    if (mErr) {
      await Swal.fire({ ...swalBase(), icon: 'error', title: t('login.onboard.saveFailed'), text: mErr.message });
      return null;
    }
    await supabase.from('flats').update({ owner_name: first.name, is_occupied: true }).eq('id', flatId);
    const row = await ensureResidentUserRow(flatId, flatNumber, phone, first.name, true);
    if (!row) {
      await Swal.fire({ ...swalBase(), icon: 'error', title: t('login.onboard.saveFailed') });
      return null;
    }
    return { ...row, openFamilyTab: true };
  }

  const primary = pickPrimaryMember(members);
  if (!primary) {
    await Swal.fire({ ...swalBase(), icon: 'error', title: t('login.onboard.noPrimaryTitle'), text: t('login.onboard.noPrimaryBody') });
    return null;
  }

  const primaryPhone = primary.phone ? normalizeLoginPhone(primary.phone) : '';

  if (primaryPhone && primaryPhone === phone) {
    const row = await ensureResidentUserRow(flatId, flatNumber, phone, primary.name, false);
    return row;
  }

  if (!primary.phone || !primaryPhone) {
    const ok = await confirmAction(
      t('login.onboard.claimPrimaryTitle').replace('{name}', primary.name),
      t('login.onboard.claimPrimaryBody'),
      t('swal.yes'),
      t('swal.no'),
    );
    if (ok) {
      const { error: uErr } = await supabase.from('members').update({ phone }).eq('id', primary.id);
      if (uErr) {
        await Swal.fire({ ...swalBase(), icon: 'error', title: t('login.onboard.saveFailed'), text: uErr.message });
        return null;
      }
      const row = await ensureResidentUserRow(flatId, flatNumber, phone, primary.name, false);
      return row;
    }
  }

  const nm = await swalNewHouseholdMember(t);
  if (!nm) return null;

  const restricted = isRestrictedMemberCategory(nm.relation);
  const payload: Record<string, unknown> = {
    flat_id: flatId,
    name: nm.name,
    phone,
    relation: nm.relation,
    gender: nm.gender || null,
    is_primary: false,
  };
  if (restricted) {
    payload.id_photo_front = nm.idPhotoFront ?? null;
    payload.id_photo_back = nm.idPhotoBack || null;
    payload.police_verification = nm.policeVerification ?? 'pending';
  } else {
    payload.id_photo_front = null;
    payload.id_photo_back = null;
    payload.police_verification = null;
  }

  const { error: insErr } = await supabase.from('members').insert(payload);
  if (insErr) {
    await Swal.fire({ ...swalBase(), icon: 'error', title: t('login.onboard.saveFailed'), text: insErr.message });
    return null;
  }

  if (!allowsResidentLogin(nm.relation)) {
    await Swal.fire({
      ...swalBase(),
      icon: 'info',
      title: t('login.onboard.staffNoAppTitle'),
      text: t('login.onboard.staffNoAppBody'),
    });
    return null;
  }

  const row = await ensureResidentUserRow(flatId, flatNumber, phone, nm.name, false);
  if (!row) {
    await Swal.fire({ ...swalBase(), icon: 'error', title: t('login.onboard.saveFailed') });
    return null;
  }
  return row;
}
