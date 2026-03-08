import { useState } from 'react';
import { useStore } from '@/store/useStore';
import type { Visitor } from '@/types';
import { Truck, Camera } from 'lucide-react';
import PhotoCapture from '@/components/PhotoCapture';

const COMPANIES = ['Amazon', 'Flipkart', 'Swiggy', 'Zomato', 'BigBasket', 'Blinkit', 'Dunzo', 'Other'];
const SERVICE_TYPES = ['Housekeeping', 'Electrician', 'Plumber', 'Carpenter', 'Painter', 'AC Service', 'Other'];

const DeliveryEntryPage = () => {
  const { addVisitor, currentGuard } = useStore();
  const [tab, setTab] = useState<'delivery' | 'service'>('delivery');
  const [success, setSuccess] = useState(false);

  const [form, setForm] = useState({
    name: '',
    phone: '',
    company: 'Amazon',
    flatNumber: '',
    vehicleNumber: '',
  });
  const [personPhotos, setPersonPhotos] = useState<string[]>([]);

  const update = (field: string, value: string) => setForm(f => ({ ...f, [field]: value }));

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.phone || !form.flatNumber) return;

    const entry: Visitor = {
      id: `D${Date.now()}`,
      name: form.name,
      phone: form.phone,
      documentType: 'other',
      documentNumber: '',
      visitorPhotos: personPhotos,
      flatNumber: form.flatNumber,
      purpose: tab === 'delivery' ? `Delivery - ${form.company}` : `Service - ${form.company}`,
      entryTime: new Date().toISOString(),
      guardId: currentGuard?.id || '',
      guardName: currentGuard?.name || '',
      category: tab === 'delivery' ? 'delivery' : 'service',
      company: form.company,
      vehicleNumber: form.vehicleNumber || undefined,
      vehicleEntryTime: form.vehicleNumber ? new Date().toISOString() : undefined,
    };

    addVisitor(entry);
    setSuccess(true);
    setForm({ name: '', phone: '', company: tab === 'delivery' ? 'Amazon' : 'Housekeeping', flatNumber: '', vehicleNumber: '' });
    setPersonPhotos([]);
    setTimeout(() => setSuccess(false), 2000);
  };

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Truck className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">Delivery / Service</h1>
          <p className="text-xs text-muted-foreground">Quick entry for deliveries & staff</p>
        </div>
      </div>

      {/* Tab */}
      <div className="flex gap-2 mb-6">
        <button
          className={`flex-1 py-2 rounded-lg text-sm font-medium transition-all ${tab === 'delivery' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
          onClick={() => { setTab('delivery'); setForm(f => ({ ...f, company: 'Amazon' })); }}
        >
          Delivery
        </button>
        <button
          className={`flex-1 py-2 rounded-lg text-sm font-medium transition-all ${tab === 'service' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
          onClick={() => { setTab('service'); setForm(f => ({ ...f, company: 'Housekeeping' })); }}
        >
          Service
        </button>
      </div>

      {success && (
        <div className="card-section border-success/30 mb-4 text-center">
          <p className="text-success text-sm font-semibold">✓ Entry logged successfully</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">
            {tab === 'delivery' ? 'Company' : 'Service Type'}
          </label>
          <div className="flex flex-wrap gap-2">
            {(tab === 'delivery' ? COMPANIES : SERVICE_TYPES).map(c => (
              <button
                key={c}
                type="button"
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${form.company === c ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
                onClick={() => update('company', c)}
              >
                {c}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Name *</label>
          <input className="input-field" placeholder="Person name" value={form.name} onChange={e => update('name', e.target.value)} />
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Phone *</label>
          <input className="input-field font-mono" type="tel" maxLength={10} placeholder="Phone number" value={form.phone} onChange={e => update('phone', e.target.value.replace(/\D/g, ''))} />
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Flat / House No. *</label>
          <input className="input-field font-mono" placeholder="e.g. 604" value={form.flatNumber} onChange={e => update('flatNumber', e.target.value)} />
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Vehicle Number (optional)</label>
          <input className="input-field font-mono uppercase" placeholder="e.g. MH02AB1234" value={form.vehicleNumber} onChange={e => update('vehicleNumber', e.target.value.toUpperCase())} />
        </div>

        {/* Photo Capture */}
        <PhotoCapture photos={personPhotos} onChange={setPersonPhotos} maxPhotos={2} label="Person Photo" />

        <button type="submit" className="btn-primary flex items-center justify-center gap-2 mt-2">
          <Camera className="w-4 h-4" />
          Log Entry
        </button>
      </form>
    </div>
  );
};

export default DeliveryEntryPage;
