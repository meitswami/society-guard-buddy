export interface Guard {
  id: string;
  name: string;
  password: string;
  loginTime?: string;
  logoutTime?: string;
}

export interface Visitor {
  id: string;
  name: string;
  phone: string;
  documentType: 'aadhaar' | 'driving_license' | 'passport' | 'other';
  documentNumber: string;
  documentPhoto?: string;
  visitorPhotos: string[];
  flatNumber: string;
  purpose: string;
  entryTime: string;
  exitTime?: string;
  guardId: string;
  guardName: string;
  category: 'visitor' | 'delivery' | 'service';
  company?: string;
  vehicleNumber?: string;
  vehiclePhoto?: string;
  vehicleEntryTime?: string;
  vehicleExitTime?: string;
  isBlacklisted?: boolean;
}

export interface ResidentVehicle {
  id: string;
  flatNumber: string;
  residentName: string;
  vehicleNumber: string;
  vehicleType: 'car' | 'bike' | 'delivery' | 'other';
  vehiclePhoto?: string;
  flatId?: string;
}

export interface BlacklistEntry {
  id: string;
  type: 'visitor' | 'vehicle';
  name?: string;
  phone?: string;
  vehicleNumber?: string;
  reason: string;
  addedAt: string;
  addedBy: string;
}

export interface Flat {
  id: string;
  flatNumber: string;
  floor?: string;
  wing?: string;
  flatType: string;
  ownerName?: string;
  ownerPhone?: string;
  intercom?: string;
  isOccupied: boolean;
}

export interface Member {
  id: string;
  flatId: string;
  name: string;
  phone?: string;
  relation: string;
  age?: number;
  gender?: string;
  photo?: string;
  isPrimary: boolean;
}

export type TabType = 'dashboard' | 'visitor' | 'vehicle' | 'delivery' | 'logs' | 'quick' | 'directory' | 'blacklist' | 'report' | 'settings';
