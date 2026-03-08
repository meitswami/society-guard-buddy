import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Guard, Visitor, ResidentVehicle, BlacklistEntry } from '@/types';

interface AppState {
  // Auth
  currentGuard: Guard | null;
  guards: Guard[];
  login: (id: string, password: string) => boolean;
  logout: () => void;

  // Visitors
  visitors: Visitor[];
  addVisitor: (visitor: Visitor) => void;
  updateVisitor: (id: string, updates: Partial<Visitor>) => void;
  markExit: (id: string) => void;

  // Vehicles
  residentVehicles: ResidentVehicle[];
  addResidentVehicle: (vehicle: ResidentVehicle) => void;
  removeResidentVehicle: (id: string) => void;

  // Blacklist
  blacklist: BlacklistEntry[];
  addToBlacklist: (entry: BlacklistEntry) => void;
  removeFromBlacklist: (id: string) => void;
  isBlacklisted: (phone?: string, vehicleNumber?: string) => boolean;
}

const DEFAULT_GUARDS: Guard[] = [
  { id: 'G001', name: 'Rajesh Kumar', password: 'guard123' },
  { id: 'G002', name: 'Suresh Singh', password: 'guard456' },
  { id: 'G003', name: 'Amit Sharma', password: 'guard789' },
];

export const useStore = create<AppState>()(
  persist(
    (set, get) => ({
      currentGuard: null,
      guards: DEFAULT_GUARDS,
      visitors: [],
      residentVehicles: [],
      blacklist: [],

      login: (id, password) => {
        const guard = get().guards.find(g => g.id === id && g.password === password);
        if (guard) {
          const loggedIn = { ...guard, loginTime: new Date().toISOString() };
          set({ currentGuard: loggedIn });
          return true;
        }
        return false;
      },

      logout: () => {
        const guard = get().currentGuard;
        if (guard) {
          set({ currentGuard: { ...guard, logoutTime: new Date().toISOString() } });
          setTimeout(() => set({ currentGuard: null }), 100);
        }
      },

      addVisitor: (visitor) => set(s => ({ visitors: [visitor, ...s.visitors] })),

      updateVisitor: (id, updates) => set(s => ({
        visitors: s.visitors.map(v => v.id === id ? { ...v, ...updates } : v),
      })),

      markExit: (id) => set(s => ({
        visitors: s.visitors.map(v =>
          v.id === id ? { ...v, exitTime: new Date().toISOString(), vehicleExitTime: v.vehicleNumber ? new Date().toISOString() : undefined } : v
        ),
      })),

      addResidentVehicle: (vehicle) => set(s => ({ residentVehicles: [...s.residentVehicles, vehicle] })),
      removeResidentVehicle: (id) => set(s => ({ residentVehicles: s.residentVehicles.filter(v => v.id !== id) })),

      addToBlacklist: (entry) => set(s => ({ blacklist: [...s.blacklist, entry] })),
      removeFromBlacklist: (id) => set(s => ({ blacklist: s.blacklist.filter(e => e.id !== id) })),

      isBlacklisted: (phone, vehicleNumber) => {
        const bl = get().blacklist;
        return bl.some(e =>
          (phone && e.phone === phone) ||
          (vehicleNumber && e.vehicleNumber === vehicleNumber)
        );
      },
    }),
    { name: 'gate-mgmt-store' }
  )
);
