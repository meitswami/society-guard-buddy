import { useState } from 'react';
import { useStore } from '@/store/useStore';
import type { ResidentVehicle } from '@/types';
import { Car, Plus, Search, Trash2 } from 'lucide-react';

const VEHICLE_TYPES = [
  { value: 'car', label: 'Car' },
  { value: 'bike', label: 'Bike' },
  { value: 'delivery', label: 'Delivery' },
  { value: 'other', label: 'Other' },
] as const;

const VehiclePage = () => {
  const { residentVehicles, addResidentVehicle, removeResidentVehicle } = useStore();
  const [showAdd, setShowAdd] = useState(false);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState({ flatNumber: '', residentName: '', vehicleNumber: '', vehicleType: 'car' as ResidentVehicle['vehicleType'] });

  const filtered = residentVehicles.filter(v =>
    v.vehicleNumber.toLowerCase().includes(search.toLowerCase()) ||
    v.flatNumber.toLowerCase().includes(search.toLowerCase()) ||
    v.residentName.toLowerCase().includes(search.toLowerCase())
  );

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.flatNumber || !form.residentName || !form.vehicleNumber) return;
    await addResidentVehicle({
      id: `RV${Date.now()}`,
      ...form,
      vehicleNumber: form.vehicleNumber.toUpperCase(),
    });
    setForm({ flatNumber: '', residentName: '', vehicleNumber: '', vehicleType: 'car' });
    setShowAdd(false);
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <Car className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">Vehicles</h1>
            <p className="text-xs text-muted-foreground">Resident vehicle registry</p>
          </div>
        </div>
        <button onClick={() => setShowAdd(!showAdd)} className="btn-primary text-xs px-3 py-2 flex items-center gap-1">
          <Plus className="w-3.5 h-3.5" /> Add
        </button>
      </div>

      {showAdd && (
        <form onSubmit={handleAdd} className="card-section mb-4 flex flex-col gap-3">
          <div className="grid grid-cols-2 gap-3">
            <input className="input-field font-mono" placeholder="Flat No." value={form.flatNumber} onChange={e => setForm(f => ({ ...f, flatNumber: e.target.value }))} />
            <input className="input-field" placeholder="Resident Name" value={form.residentName} onChange={e => setForm(f => ({ ...f, residentName: e.target.value }))} />
          </div>
          <input className="input-field font-mono uppercase" placeholder="Vehicle Number" value={form.vehicleNumber} onChange={e => setForm(f => ({ ...f, vehicleNumber: e.target.value.toUpperCase() }))} />
          <div className="flex gap-2">
            {VEHICLE_TYPES.map(t => (
              <button
                key={t.value}
                type="button"
                className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-all ${form.vehicleType === t.value ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
                onClick={() => setForm(f => ({ ...f, vehicleType: t.value }))}
              >
                {t.label}
              </button>
            ))}
          </div>
          <button type="submit" className="btn-primary text-sm">Save Vehicle</button>
        </form>
      )}

      {/* Search */}
      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input
          className="input-field pl-9"
          placeholder="Search by vehicle no., flat, name..."
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {/* List */}
      <div className="flex flex-col gap-2">
        {filtered.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">No vehicles registered</p>
        ) : (
          filtered.map(v => (
            <div key={v.id} className="card-section flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center">
                <Car className="w-5 h-5 text-muted-foreground" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-mono font-semibold">{v.vehicleNumber}</p>
                <p className="text-xs text-muted-foreground">
                  Flat {v.flatNumber} · {v.residentName} · {v.vehicleType}
                </p>
              </div>
              <button
                onClick={() => removeResidentVehicle(v.id)}
                className="p-2 text-muted-foreground hover:text-destructive"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default VehiclePage;
