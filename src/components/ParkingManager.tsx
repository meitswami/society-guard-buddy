import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Car, Plus, Trash2, Edit } from 'lucide-react';
import { toast } from 'sonner';

const ParkingManager = () => {
  const [spaces, setSpaces] = useState<any[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [sf, setSf] = useState({ space_number: '', space_type: 'car', floor_level: '', allocated_flat_number: '', allocated_vehicle_number: '', notes: '' });

  useEffect(() => { loadAll(); }, []);
  const loadAll = async () => {
    const [s, f] = await Promise.all([
      supabase.from('parking_spaces').select('*').order('space_number'),
      supabase.from('flats').select('flat_number, id').order('flat_number'),
    ]);
    if (s.data) setSpaces(s.data);
    if (f.data) setFlats(f.data);
  };

  const addSpace = async () => {
    if (!sf.space_number) return;
    const flat = flats.find(f => f.flat_number === sf.allocated_flat_number);
    await supabase.from('parking_spaces').insert([{
      space_number: sf.space_number, space_type: sf.space_type, floor_level: sf.floor_level || null,
      is_allocated: !!sf.allocated_flat_number,
      allocated_flat_id: flat?.id || null, allocated_flat_number: sf.allocated_flat_number || null,
      allocated_vehicle_number: sf.allocated_vehicle_number || null, notes: sf.notes || null,
    }]);
    setSf({ space_number: '', space_type: 'car', floor_level: '', allocated_flat_number: '', allocated_vehicle_number: '', notes: '' });
    setShowForm(false); toast.success('Parking space added'); loadAll();
  };

  const deleteSpace = async (id: string) => {
    await supabase.from('parking_spaces').delete().eq('id', id);
    toast.success('Space removed'); loadAll();
  };

  const deallocate = async (id: string) => {
    await supabase.from('parking_spaces').update({
      is_allocated: false, allocated_flat_id: null, allocated_flat_number: null, allocated_vehicle_number: null,
    }).eq('id', id);
    toast.success('Space deallocated'); loadAll();
  };

  const allocated = spaces.filter(s => s.is_allocated);
  const available = spaces.filter(s => !s.is_allocated);

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
          <Car className="w-5 h-5 text-blue-500" />
        </div>
        <div>
          <h1 className="page-title">Parking Management</h1>
          <p className="text-xs text-muted-foreground">{allocated.length} allocated · {available.length} available</p>
        </div>
      </div>

      <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
        <Plus className="w-4 h-4" /> Add Parking Space
      </button>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input className="input-field" placeholder="Space Number (e.g. P-101)" value={sf.space_number} onChange={e => setSf({...sf, space_number: e.target.value})} />
          <select className="input-field" value={sf.space_type} onChange={e => setSf({...sf, space_type: e.target.value})}>
            <option value="car">🚗 Car</option>
            <option value="bike">🏍️ Bike</option>
            <option value="visitor">👤 Visitor</option>
          </select>
          <input className="input-field" placeholder="Floor/Level (e.g. B1)" value={sf.floor_level} onChange={e => setSf({...sf, floor_level: e.target.value})} />
          <select className="input-field" value={sf.allocated_flat_number} onChange={e => setSf({...sf, allocated_flat_number: e.target.value})}>
            <option value="">Not Allocated</option>
            {flats.map(f => <option key={f.id} value={f.flat_number}>Flat {f.flat_number}</option>)}
          </select>
          {sf.allocated_flat_number && (
            <input className="input-field" placeholder="Vehicle Number" value={sf.allocated_vehicle_number} onChange={e => setSf({...sf, allocated_vehicle_number: e.target.value})} />
          )}
          <textarea className="input-field" placeholder="Notes" value={sf.notes} onChange={e => setSf({...sf, notes: e.target.value})} />
          <button onClick={addSpace} className="btn-primary">Add Space</button>
        </div>
      )}

      {allocated.length > 0 && (
        <>
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">Allocated ({allocated.length})</p>
          <div className="space-y-2 mb-4">
            {allocated.map(s => (
              <div key={s.id} className="card-section p-3 flex justify-between items-center">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-mono font-bold text-sm">{s.space_number}</span>
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary">{s.space_type}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">Flat {s.allocated_flat_number} · {s.allocated_vehicle_number || 'No vehicle'}</p>
                  {s.floor_level && <p className="text-[10px] text-muted-foreground">Floor: {s.floor_level}</p>}
                </div>
                <div className="flex gap-1">
                  <button onClick={() => deallocate(s.id)} className="p-1.5 rounded bg-amber-500/10 text-amber-600 text-xs">Free</button>
                  <button onClick={() => deleteSpace(s.id)} className="p-1.5 rounded bg-destructive/10 text-destructive"><Trash2 className="w-3 h-3" /></button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      {available.length > 0 && (
        <>
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">Available ({available.length})</p>
          <div className="space-y-2">
            {available.map(s => (
              <div key={s.id} className="card-section p-3 flex justify-between items-center">
                <div>
                  <span className="font-mono font-bold text-sm">{s.space_number}</span>
                  <span className="text-[10px] ml-2 px-1.5 py-0.5 rounded bg-green-500/20 text-green-600">{s.space_type} · Available</span>
                  {s.floor_level && <p className="text-[10px] text-muted-foreground">Floor: {s.floor_level}</p>}
                </div>
                <button onClick={() => deleteSpace(s.id)} className="p-1.5 rounded bg-destructive/10 text-destructive"><Trash2 className="w-3 h-3" /></button>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
};

export default ParkingManager;
