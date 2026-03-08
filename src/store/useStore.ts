import { create } from 'zustand';
import { supabase } from '@/integrations/supabase/client';
import type { Guard, Visitor, ResidentVehicle, BlacklistEntry } from '@/types';

interface AppState {
  // Auth
  currentGuard: Guard | null;
  guards: Guard[];
  shiftId: string | null;
  login: (id: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
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

  // Theme
  theme: 'dark' | 'light' | 'system';
  setTheme: (theme: 'dark' | 'light' | 'system') => void;
}

export const useStore = create<AppState>()((set, get) => ({
  currentGuard: null,
  guards: [],
  shiftId: null,
  visitors: [],
  residentVehicles: [],
  blacklist: [],
  theme: (localStorage.getItem('gate-theme') as 'dark' | 'light' | 'system') || 'system',

  loadGuards: async () => {
    const { data } = await supabase.from('guards').select('*');
    if (data) {
      set({
        guards: data.map(g => ({
          id: g.guard_id,
          name: g.name,
          password: g.password,
        })),
      });
    }
  },

  login: async (id, password) => {
    const guards = get().guards;
    const guard = guards.find(g => g.id === id && g.password === password);
    if (guard) {
      const loggedIn = { ...guard, loginTime: new Date().toISOString() };
      // Record shift
      const { data } = await supabase.from('guard_shifts').insert({
        guard_id: guard.id,
        guard_name: guard.name,
        login_time: new Date().toISOString(),
      }).select().single();
      set({ currentGuard: loggedIn, shiftId: data?.id || null });
      return true;
    }
    return false;
  },

  logout: async () => {
    const { shiftId } = get();
    if (shiftId) {
      await supabase.from('guard_shifts').update({
        logout_time: new Date().toISOString(),
      }).eq('id', shiftId);
    }
    set({ currentGuard: null, shiftId: null });
  },

  loadVisitors: async () => {
    const { data } = await supabase.from('visitors').select('*').order('entry_time', { ascending: false });
    if (data) {
      set({
        visitors: data.map(v => ({
          id: v.id,
          name: v.name,
          phone: v.phone,
          documentType: v.document_type as Visitor['documentType'],
          documentNumber: v.document_number || '',
          documentPhoto: v.document_photo || undefined,
          visitorPhotos: v.visitor_photos || [],
          flatNumber: v.flat_number,
          purpose: v.purpose,
          entryTime: v.entry_time,
          exitTime: v.exit_time || undefined,
          guardId: v.guard_id,
          guardName: v.guard_name,
          category: v.category as Visitor['category'],
          company: v.company || undefined,
          vehicleNumber: v.vehicle_number || undefined,
          vehiclePhoto: v.vehicle_photo || undefined,
          vehicleEntryTime: v.vehicle_entry_time || undefined,
          vehicleExitTime: v.vehicle_exit_time || undefined,
          isBlacklisted: v.is_blacklisted || false,
        })),
      });
    }
  },

  addVisitor: async (visitor) => {
    await supabase.from('visitors').insert({
      name: visitor.name,
      phone: visitor.phone,
      document_type: visitor.documentType,
      document_number: visitor.documentNumber || null,
      document_photo: visitor.documentPhoto || null,
      visitor_photos: visitor.visitorPhotos,
      flat_number: visitor.flatNumber,
      purpose: visitor.purpose,
      entry_time: visitor.entryTime,
      guard_id: visitor.guardId,
      guard_name: visitor.guardName,
      category: visitor.category,
      company: visitor.company || null,
      vehicle_number: visitor.vehicleNumber || null,
      vehicle_entry_time: visitor.vehicleEntryTime || null,
    });
    // Reload from DB
    get().loadVisitors();
  },

  updateVisitor: (id, updates) => set(s => ({
    visitors: s.visitors.map(v => v.id === id ? { ...v, ...updates } : v),
  })),

  markExit: async (id) => {
    const now = new Date().toISOString();
    const visitor = get().visitors.find(v => v.id === id);
    await supabase.from('visitors').update({
      exit_time: now,
      vehicle_exit_time: visitor?.vehicleNumber ? now : null,
    }).eq('id', id);
    set(s => ({
      visitors: s.visitors.map(v =>
        v.id === id ? { ...v, exitTime: now, vehicleExitTime: v.vehicleNumber ? now : undefined } : v
      ),
    }));
  },

  loadResidentVehicles: async () => {
    const { data } = await supabase.from('resident_vehicles').select('*');
    if (data) {
      set({
        residentVehicles: data.map(v => ({
          id: v.id,
          flatNumber: v.flat_number,
          residentName: v.resident_name,
          vehicleNumber: v.vehicle_number,
          vehicleType: v.vehicle_type as ResidentVehicle['vehicleType'],
          vehiclePhoto: v.vehicle_photo || undefined,
        })),
      });
    }
  },

  addResidentVehicle: async (vehicle) => {
    await supabase.from('resident_vehicles').insert({
      flat_number: vehicle.flatNumber,
      resident_name: vehicle.residentName,
      vehicle_number: vehicle.vehicleNumber,
      vehicle_type: vehicle.vehicleType,
    });
    get().loadResidentVehicles();
  },

  removeResidentVehicle: async (id) => {
    await supabase.from('resident_vehicles').delete().eq('id', id);
    set(s => ({ residentVehicles: s.residentVehicles.filter(v => v.id !== id) }));
  },

  loadBlacklist: async () => {
    const { data } = await supabase.from('blacklist').select('*').order('added_at', { ascending: false });
    if (data) {
      set({
        blacklist: data.map(e => ({
          id: e.id,
          type: e.type as BlacklistEntry['type'],
          name: e.name || undefined,
          phone: e.phone || undefined,
          vehicleNumber: e.vehicle_number || undefined,
          reason: e.reason,
          addedAt: e.added_at,
          addedBy: e.added_by,
        })),
      });
    }
  },

  addToBlacklist: async (entry) => {
    await supabase.from('blacklist').insert({
      type: entry.type,
      name: entry.name || null,
      phone: entry.phone || null,
      vehicle_number: entry.vehicleNumber || null,
      reason: entry.reason,
      added_by: entry.addedBy,
    });
    get().loadBlacklist();
  },

  removeFromBlacklist: async (id) => {
    await supabase.from('blacklist').delete().eq('id', id);
    set(s => ({ blacklist: s.blacklist.filter(e => e.id !== id) }));
  },

  isBlacklisted: (phone, vehicleNumber) => {
    const bl = get().blacklist;
    return bl.some(e =>
      (phone && e.phone === phone) ||
      (vehicleNumber && e.vehicleNumber === vehicleNumber)
    );
  },

  toggleTheme: () => {
    const newTheme = get().theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('gate-theme', newTheme);
    set({ theme: newTheme });
  },
}));
