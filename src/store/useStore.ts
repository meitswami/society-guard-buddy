import { create } from 'zustand';
import { supabase } from '@/integrations/supabase/client';
import type { Guard, Visitor, ResidentVehicle, BlacklistEntry, Flat, Member } from '@/types';
import { clearPersistedSession, writePersistedSession } from '@/lib/appSession';

interface AppState {
  // Auth
  currentGuard: Guard | null;
  guards: Guard[];
  shiftId: string | null;
  societyId: string | null;
  setSocietyId: (id: string | null) => void;
  login: (id: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
  hydrateGuardSession: (session: { societyId: string; shiftId: string; guardId: string }) => Promise<boolean>;
  loadGuards: () => Promise<void>;

  // Visitors
  visitors: Visitor[];
  loadVisitors: () => Promise<void>;
  addVisitor: (visitor: Visitor) => Promise<void>;
  updateVisitor: (id: string, updates: Partial<Visitor>) => void;
  markExit: (id: string) => Promise<void>;

  // Vehicles
  residentVehicles: ResidentVehicle[];
  loadResidentVehicles: () => Promise<void>;
  addResidentVehicle: (vehicle: ResidentVehicle) => Promise<void>;
  removeResidentVehicle: (id: string) => Promise<void>;

  // Blacklist
  blacklist: BlacklistEntry[];
  loadBlacklist: () => Promise<void>;
  addToBlacklist: (entry: BlacklistEntry) => Promise<void>;
  removeFromBlacklist: (id: string) => Promise<void>;
  isBlacklisted: (phone?: string, vehicleNumber?: string) => boolean;

  // Flats & Members
  flats: Flat[];
  members: Member[];
  loadFlats: () => Promise<void>;
  loadMembers: () => Promise<void>;

  // Data management
  clearAllData: () => Promise<void>;

  // Theme
  theme: 'dark' | 'light' | 'system';
  setTheme: (theme: 'dark' | 'light' | 'system') => void;
}

export const useStore = create<AppState>()((set, get) => ({
  currentGuard: null,
  guards: [],
  shiftId: null,
  societyId: null,
  visitors: [],
  residentVehicles: [],
  blacklist: [],
  flats: [],
  members: [],
  theme: (localStorage.getItem('gate-theme') as 'dark' | 'light' | 'system') || 'system',

  setSocietyId: (id) =>
    set({
      societyId: id,
      guards: [],
      visitors: [],
      residentVehicles: [],
      blacklist: [],
      flats: [],
      members: [],
    }),

  loadGuards: async () => {
    const sid = get().societyId;
    if (!sid) {
      set({ guards: [] });
      return;
    }
    const query = supabase.from('guards').select('*').eq('society_id', sid);
    const { data } = await query;
    if (data) {
      set({ guards: data.map(g => ({ id: g.guard_id, name: g.name, password: g.password })) });
    }
  },

  login: async (id, password) => {
    const guards = get().guards;
    const guard = guards.find(g => g.id === id && g.password === password);
    if (guard) {
      const loggedIn = { ...guard, loginTime: new Date().toISOString() };
      const sid = get().societyId;
      const { data } = await supabase.from('guard_shifts').insert({
        guard_id: guard.id, guard_name: guard.name, login_time: new Date().toISOString(), society_id: sid,
      }).select().single();
      set({ currentGuard: loggedIn, shiftId: data?.id || null });
      if (sid && data?.id) {
        writePersistedSession({ v: 1, role: 'guard', societyId: sid, shiftId: data.id, guardId: guard.id });
      }
      return true;
    }
    return false;
  },

  hydrateGuardSession: async (session) => {
    set({ societyId: session.societyId });
    await get().loadGuards();
    const { data: shift } = await supabase
      .from('guard_shifts')
      .select('id, guard_id, login_time, logout_time')
      .eq('id', session.shiftId)
      .maybeSingle();
    if (!shift || shift.logout_time) {
      clearPersistedSession();
      set({ currentGuard: null, shiftId: null, societyId: null });
      return false;
    }
    const guard = get().guards.find((g) => g.id === shift.guard_id);
    if (!guard) {
      clearPersistedSession();
      set({ currentGuard: null, shiftId: null, societyId: null });
      return false;
    }
    set({
      currentGuard: { ...guard, loginTime: shift.login_time ?? undefined },
      shiftId: shift.id,
    });
    return true;
  },

  logout: async () => {
    const { shiftId } = get();
    if (shiftId) {
      await supabase.from('guard_shifts').update({ logout_time: new Date().toISOString() }).eq('id', shiftId);
    }
    clearPersistedSession();
    set({ currentGuard: null, shiftId: null, societyId: null });
  },

  loadVisitors: async () => {
    const sid = get().societyId;
    if (!sid) {
      set({ visitors: [] });
      return;
    }
    const { data } = await supabase
      .from('visitors')
      .select('*')
      .eq('society_id', sid)
      .order('entry_time', { ascending: false });
    if (data) {
      set({
        visitors: data.map(v => ({
          id: v.id, societyId: v.society_id || undefined, name: v.name, phone: v.phone,
          documentType: v.document_type as Visitor['documentType'],
          documentNumber: v.document_number || '', documentPhoto: v.document_photo || undefined,
          visitorPhotos: v.visitor_photos || [], flatNumber: v.flat_number,
          purpose: v.purpose, entryTime: v.entry_time, exitTime: v.exit_time || undefined,
          guardId: v.guard_id, guardName: v.guard_name,
          category: v.category as Visitor['category'], company: v.company || undefined,
          vehicleNumber: v.vehicle_number || undefined, vehiclePhoto: v.vehicle_photo || undefined,
          vehicleEntryTime: v.vehicle_entry_time || undefined, vehicleExitTime: v.vehicle_exit_time || undefined,
          isBlacklisted: v.is_blacklisted || false,
        })),
      });
    }
  },

  addVisitor: async (visitor) => {
    const sid = get().societyId;
    if (!sid) return;
    await supabase.from('visitors').insert({
      society_id: sid,
      name: visitor.name, phone: visitor.phone, document_type: visitor.documentType,
      document_number: visitor.documentNumber || null, document_photo: visitor.documentPhoto || null,
      visitor_photos: visitor.visitorPhotos, flat_number: visitor.flatNumber, purpose: visitor.purpose,
      entry_time: visitor.entryTime, guard_id: visitor.guardId, guard_name: visitor.guardName,
      category: visitor.category, company: visitor.company || null,
      vehicle_number: visitor.vehicleNumber || null, vehicle_entry_time: visitor.vehicleEntryTime || null,
    });
    get().loadVisitors();
  },

  updateVisitor: (id, updates) => set(s => ({
    visitors: s.visitors.map(v => v.id === id ? { ...v, ...updates } : v),
  })),

  markExit: async (id) => {
    const now = new Date().toISOString();
    const sid = get().societyId;
    const visitor = get().visitors.find(v => v.id === id);
    let q = supabase.from('visitors').update({
      exit_time: now, vehicle_exit_time: visitor?.vehicleNumber ? now : null,
    }).eq('id', id);
    if (sid) q = q.eq('society_id', sid);
    await q;
    set(s => ({
      visitors: s.visitors.map(v =>
        v.id === id ? { ...v, exitTime: now, vehicleExitTime: v.vehicleNumber ? now : undefined } : v
      ),
    }));
  },

  loadResidentVehicles: async () => {
    const sid = get().societyId;
    if (!sid) {
      set({ residentVehicles: [] });
      return;
    }
    const query = supabase.from('resident_vehicles').select('*').eq('society_id', sid);
    const { data } = await query;
    if (data) {
      set({
        residentVehicles: data.map(v => ({
          id: v.id, societyId: v.society_id || undefined, flatNumber: v.flat_number, residentName: v.resident_name,
          vehicleNumber: v.vehicle_number, vehicleType: v.vehicle_type as ResidentVehicle['vehicleType'],
          vehiclePhoto: v.vehicle_photo || undefined, flatId: v.flat_id || undefined,
          memberId: v.member_id || undefined,
          vehicleColor: v.vehicle_color || undefined,
          vehicleDisplayName: v.vehicle_display_name || undefined,
        })),
      });
    }
  },

  addResidentVehicle: async (vehicle) => {
    const sid = get().societyId;
    if (!sid) return;
    await supabase.from('resident_vehicles').insert({
      society_id: sid,
      flat_number: vehicle.flatNumber, resident_name: vehicle.residentName,
      vehicle_number: vehicle.vehicleNumber, vehicle_type: vehicle.vehicleType,
      flat_id: vehicle.flatId || null,
    });
    get().loadResidentVehicles();
  },

  removeResidentVehicle: async (id) => {
    const sid = get().societyId;
    let q = supabase.from('resident_vehicles').delete().eq('id', id);
    if (sid) q = q.eq('society_id', sid);
    await q;
    set(s => ({ residentVehicles: s.residentVehicles.filter(v => v.id !== id) }));
  },

  loadBlacklist: async () => {
    const sid = get().societyId;
    if (!sid) {
      set({ blacklist: [] });
      return;
    }
    const { data } = await supabase.from('blacklist').select('*').eq('society_id', sid).order('added_at', { ascending: false });
    if (data) {
      set({
        blacklist: data.map(e => ({
          id: e.id, societyId: e.society_id || undefined, type: e.type as BlacklistEntry['type'], name: e.name || undefined,
          phone: e.phone || undefined, vehicleNumber: e.vehicle_number || undefined,
          reason: e.reason, addedAt: e.added_at, addedBy: e.added_by,
        })),
      });
    }
  },

  addToBlacklist: async (entry) => {
    const sid = get().societyId;
    if (!sid) return;
    await supabase.from('blacklist').insert({
      society_id: sid,
      type: entry.type, name: entry.name || null, phone: entry.phone || null,
      vehicle_number: entry.vehicleNumber || null, reason: entry.reason, added_by: entry.addedBy,
    });
    get().loadBlacklist();
  },

  removeFromBlacklist: async (id) => {
    const sid = get().societyId;
    let q = supabase.from('blacklist').delete().eq('id', id);
    if (sid) q = q.eq('society_id', sid);
    await q;
    set(s => ({ blacklist: s.blacklist.filter(e => e.id !== id) }));
  },

  isBlacklisted: (phone, vehicleNumber) => {
    const bl = get().blacklist;
    return bl.some(e => (phone && e.phone === phone) || (vehicleNumber && e.vehicleNumber === vehicleNumber));
  },

  loadFlats: async () => {
    const sid = get().societyId;
    if (!sid) {
      set({ flats: [] });
      return;
    }
    const query = supabase.from('flats').select('*').eq('society_id', sid).order('flat_number');
    const { data } = await query;
    if (data) {
      set({
        flats: data.map(f => ({
          id: f.id, flatNumber: f.flat_number, floor: f.floor, wing: f.wing,
          flatType: f.flat_type || 'residential', ownerName: f.owner_name || undefined,
          ownerPhone: f.owner_phone || undefined, intercom: f.intercom || undefined,
          isOccupied: f.is_occupied ?? true,
          ownerLivesHere: (f as any).owner_lives_here ?? true,
          tenantHouseholdType: (f as any).tenant_household_type ?? undefined,
        })),
      });
    }
  },

  loadMembers: async () => {
    const sid = get().societyId;
    if (!sid) {
      set({ members: [] });
      return;
    }
    let query = supabase.from('members').select('*').order('is_primary', { ascending: false });
    if (sid) {
      const { data: flatData } = await supabase.from('flats').select('id').eq('society_id', sid);
      if (flatData) {
        const flatIds = flatData.map(f => f.id);
        if (flatIds.length > 0) {
          query = query.in('flat_id', flatIds);
        } else {
          set({ members: [] });
          return;
        }
      }
    }
    const { data } = await query;
    if (data) {
      set({
        members: data.map(m => ({
          id: m.id, flatId: m.flat_id, name: m.name, phone: m.phone || undefined,
          relation: m.relation || 'owner', age: m.age || undefined, gender: m.gender || undefined,
          photo: m.photo || undefined, isPrimary: m.is_primary ?? false,
          idPhotoFront: m.id_photo_front || undefined,
          idPhotoBack: m.id_photo_back || undefined,
          policeVerification: m.police_verification || undefined,
          spouseName: m.spouse_name || undefined,
          dateJoining: m.date_joining || undefined,
          dateLeave: m.date_leave || undefined,
          householdGroup: (m as any).household_group ?? undefined,
        })),
      });
    }
  },

  clearAllData: async () => {
    await supabase.from('visitors').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await supabase.from('blacklist').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await supabase.from('resident_vehicles').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await supabase.from('members').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await supabase.from('flats').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await supabase.from('guard_shifts').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    get().loadVisitors();
    get().loadBlacklist();
    get().loadResidentVehicles();
    get().loadFlats();
    get().loadMembers();
  },

  setTheme: (theme) => {
    localStorage.setItem('gate-theme', theme);
    set({ theme });
  },
}));
