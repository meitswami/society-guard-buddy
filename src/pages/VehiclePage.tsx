import { useState } from 'react';
import { useStore } from '@/store/useStore';
import type { ResidentVehicle } from '@/types';
import { Car, Plus, Search, Trash2 } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import { confirmAction } from '@/lib/swal';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { toast } from 'sonner';

const VEHICLE_TYPES = [
  { value: 'car', label: 'Car' },
  { value: 'bike', label: 'Bike' },
  { value: 'delivery', label: 'Delivery' },
  { value: 'other', label: 'Other' },
] as const;

const VehiclePage = () => {
  const { residentVehicles, addResidentVehicle, removeResidentVehicle, flats, members } = useStore();
  const { t } = useLanguage();
  const [showAdd, setShowAdd] = useState(false);
  const [search, setSearch] = useState('');
  const [selectedFlats, setSelectedFlats] = useState<string[]>([]);
  const [form, setForm] = useState({
    vehicleNumber: '',
    vehicleType: 'car' as ResidentVehicle['vehicleType'],
  });

  const filtered = residentVehicles.filter(v =>
    v.vehicleNumber.toLowerCase().includes(search.toLowerCase()) ||
    v.flatNumber.toLowerCase().includes(search.toLowerCase()) ||
    v.residentName.toLowerCase().includes(search.toLowerCase())
  );

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedFlats.length === 0) {
      toast.error('Select at least one flat');
      return;
    }
    if (!form.vehicleNumber.trim()) return;

    const vnum = form.vehicleNumber.toUpperCase();
    for (const flatNumber of selectedFlats) {
      const flat = flats.find(f => f.flatNumber === flatNumber);
      if (!flat) continue;
      const primary = members.find(m => m.flatId === flat.id && m.isPrimary);
      const residentName = primary?.name?.trim() || flat.ownerName?.trim() || '';
      if (!residentName) {
        toast.error(
          `${t('vehicle.residentName') || 'Resident'}: flat ${flatNumber} (add owner or primary member)`
        );
        return;
      }
      await addResidentVehicle({
        id: `RV${Date.now()}-${flatNumber}`,
        flatNumber,
        residentName,
        vehicleNumber: vnum,
        vehicleType: form.vehicleType,
        flatId: flat.id,
      });
    }

    const count = selectedFlats.length;
    setForm({ vehicleNumber: '', vehicleType: 'car' });
    setSelectedFlats([]);
    setShowAdd(false);
    toast.success(count > 1 ? `Vehicles saved for ${count} flats` : t('vehicle.saveVehicle'));
  };

  const handleRemove = async (id: string) => {
    const confirmed = await confirmAction(t('swal.confirmDelete'), t('swal.confirmDeleteText'), t('swal.yes'), t('swal.no'));
    if (confirmed) await removeResidentVehicle(id);
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <Car className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('vehicle.title')}</h1>
            <p className="text-xs text-muted-foreground">{t('vehicle.subtitle')}</p>
          </div>
        </div>
        <button onClick={() => setShowAdd(!showAdd)} className="btn-primary text-xs px-3 py-2 flex items-center gap-1">
          <Plus className="w-3.5 h-3.5" /> {t('common.add')}
        </button>
      </div>

      {showAdd && (
        <form onSubmit={handleAdd} className="card-section mb-4 flex flex-col gap-3">
          <FlatMultiSelect
            flats={flats
              .filter(f => f.isOccupied)
              .map(f => {
                const primary = members.find(m => m.flatId === f.id && m.isPrimary)?.name?.trim();
                return {
                  id: f.id,
                  flat_number: f.flatNumber,
                  subtitle: primary || f.ownerName?.trim() || undefined,
                };
              })}
            selected={selectedFlats}
            onChange={setSelectedFlats}
            label={t('vehicle.flatNo')}
          />
          <input className="input-field font-mono uppercase" placeholder={t('visitor.vehicleNumber')} value={form.vehicleNumber}
            onChange={e => setForm(f => ({ ...f, vehicleNumber: e.target.value.toUpperCase() }))} />
          <div className="flex gap-2">
            {VEHICLE_TYPES.map(vt => (
              <button key={vt.value} type="button"
                className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-all ${form.vehicleType === vt.value ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
                onClick={() => setForm(f => ({ ...f, vehicleType: vt.value }))}>{vt.label}</button>
            ))}
          </div>
          <button type="submit" className="btn-primary text-sm">{t('vehicle.saveVehicle')}</button>
        </form>
      )}

      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input className="input-field pl-9" placeholder={t('vehicle.searchPlaceholder')} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      <div className="flex flex-col gap-2">
        {filtered.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">{t('vehicle.noVehicles')}</p>
        ) : (
          filtered.map(v => (
            <div key={v.id} className="card-section flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center">
                <Car className="w-5 h-5 text-muted-foreground" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-mono font-semibold">{v.vehicleNumber}</p>
                <p className="text-xs text-muted-foreground">{t('common.flat')} {v.flatNumber} · {v.residentName} · {v.vehicleType}</p>
              </div>
              <button onClick={() => handleRemove(v.id)} className="p-2 text-muted-foreground hover:text-destructive">
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
