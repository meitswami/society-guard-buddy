import { useState, useMemo } from 'react';
import { useStore } from '@/store/useStore';
import { BookUser, Search, ChevronDown, ChevronUp, FileText, Home, Users, Car, Phone } from 'lucide-react';
import { format } from 'date-fns';
import { useLanguage } from '@/i18n/LanguageContext';

type ViewMode = 'flats' | 'visitors';

const DirectoryPage = () => {
  const { visitors, flats, members, residentVehicles } = useStore();
  const { t } = useLanguage();
  const [search, setSearch] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>('flats');

  // === FLATS VIEW ===
  const filteredFlats = useMemo(() => {
    if (!search.trim()) return flats;
    const q = search.toLowerCase();
    return flats.filter(f =>
      f.flatNumber.toLowerCase().includes(q) ||
      (f.ownerName && f.ownerName.toLowerCase().includes(q)) ||
      (f.wing && f.wing.toLowerCase().includes(q)) ||
      (f.ownerPhone && f.ownerPhone.includes(q))
    );
  }, [flats, search]);

  const getMembersForFlat = (flatId: string) => members.filter(m => m.flatId === flatId);
  const getVehiclesForFlat = (flatNumber: string) => residentVehicles.filter(v => v.flatNumber === flatNumber);

  // === VISITORS VIEW ===
  const visitorDirectory = useMemo(() => {
    const phoneMap = new Map<string, { latest: typeof visitors[0]; totalVisits: number; firstVisit: string }>();
    visitors.forEach(v => {
      const existing = phoneMap.get(v.phone);
      if (existing) {
        existing.totalVisits++;
        if (v.entryTime > existing.latest.entryTime) existing.latest = v;
        if (v.entryTime < existing.firstVisit) existing.firstVisit = v.entryTime;
      } else {
        phoneMap.set(v.phone, { latest: v, totalVisits: 1, firstVisit: v.entryTime });
      }
    });
    return Array.from(phoneMap.values()).sort((a, b) => b.latest.entryTime.localeCompare(a.latest.entryTime));
  }, [visitors]);

  const filteredVisitors = useMemo(() => {
    if (!search.trim()) return visitorDirectory;
    const q = search.toLowerCase();
    return visitorDirectory.filter(e =>
      e.latest.name.toLowerCase().includes(q) || e.latest.phone.includes(q) ||
      e.latest.flatNumber.toLowerCase().includes(q) || (e.latest.vehicleNumber && e.latest.vehicleNumber.toLowerCase().includes(q))
    );
  }, [visitorDirectory, search]);

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BookUser className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('directory.title')}</h1>
            <p className="text-xs text-muted-foreground">
              {viewMode === 'flats' ? `${flats.length} flats` : `${visitorDirectory.length} ${t('directory.registeredVisitors')}`}
            </p>
          </div>
        </div>
      </div>

      {/* View toggle */}
      <div className="flex gap-2 mb-4">
        <button onClick={() => setViewMode('flats')}
          className={`flex-1 py-2 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${viewMode === 'flats' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
          <Home className="w-3.5 h-3.5" /> Flats & Members
        </button>
        <button onClick={() => setViewMode('visitors')}
          className={`flex-1 py-2 rounded-lg text-xs font-medium transition-all flex items-center justify-center gap-1.5 ${viewMode === 'visitors' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
          <Users className="w-3.5 h-3.5" /> {t('dashboard.visitors')}
        </button>
      </div>

      <div className="relative mb-4">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input className="input-field pl-9" placeholder={t('directory.searchPlaceholder')} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      {/* === FLATS VIEW === */}
      {viewMode === 'flats' && (
        filteredFlats.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-12">No flats found</p>
        ) : (
          <div className="flex flex-col gap-2">
            {filteredFlats.map(flat => {
              const isExpanded = expandedId === flat.id;
              const flatMembers = getMembersForFlat(flat.id);
              const flatVehicles = getVehiclesForFlat(flat.flatNumber);
              return (
                <div key={flat.id} className="card-section">
                  <button type="button" className="w-full flex items-center gap-3 text-left" onClick={() => setExpandedId(isExpanded ? null : flat.id)}>
                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${flat.isOccupied ? 'bg-primary/10' : 'bg-muted'}`}>
                      <Home className={`w-5 h-5 ${flat.isOccupied ? 'text-primary' : 'text-muted-foreground'}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="text-sm font-semibold font-mono">{flat.flatNumber}</p>
                        {flat.wing && <span className="text-[10px] bg-secondary px-1.5 py-0.5 rounded text-secondary-foreground">Wing {flat.wing}</span>}
                        {!flat.isOccupied && <span className="text-[10px] bg-warning/20 px-1.5 py-0.5 rounded text-warning">Vacant</span>}
                      </div>
                      <p className="text-xs text-muted-foreground truncate">{flat.ownerName || 'No owner'} · {flatMembers.length} members · {flatVehicles.length} vehicles</p>
                    </div>
                    <div className="flex-shrink-0">
                      {isExpanded ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
                    </div>
                  </button>

                  {isExpanded && (
                    <div className="mt-3 pt-3 border-t border-border space-y-3">
                      {/* Flat info */}
                      <div className="grid grid-cols-2 gap-2 text-xs">
                        <div><span className="text-muted-foreground">Floor:</span><span className="ml-1 font-medium">{flat.floor || '-'}</span></div>
                        <div><span className="text-muted-foreground">Type:</span><span className="ml-1 font-medium capitalize">{flat.flatType}</span></div>
                        {flat.intercom && <div><span className="text-muted-foreground">Intercom:</span><span className="ml-1 font-mono font-medium">{flat.intercom}</span></div>}
                        {flat.ownerPhone && (
                          <div className="flex items-center gap-1">
                            <Phone className="w-3 h-3 text-muted-foreground" />
                            <a href={`tel:${flat.ownerPhone}`} className="font-mono font-medium text-primary">{flat.ownerPhone}</a>
                          </div>
                        )}
                      </div>

                      {/* Members */}
                      {flatMembers.length > 0 && (
                        <div>
                          <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium mb-1.5">Members ({flatMembers.length})</p>
                          <div className="space-y-1.5">
                            {flatMembers.map(m => (
                              <div key={m.id} className="flex items-center gap-2 bg-secondary/50 rounded-lg px-2.5 py-1.5">
                                <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-[10px] font-bold text-primary flex-shrink-0">
                                  {m.name.charAt(0)}
                                </div>
                                <div className="flex-1 min-w-0">
                                  <p className="text-xs font-medium truncate">
                                    {m.name}
                                    {m.isPrimary && <span className="ml-1 text-[9px] text-primary">★</span>}
                                  </p>
                                  <p className="text-[10px] text-muted-foreground capitalize">
                                    {m.relation}{m.age ? ` · ${m.age}y` : ''}{m.gender ? ` · ${m.gender}` : ''}
                                  </p>
                                </div>
                                {m.phone && (
                                  <a href={`tel:${m.phone}`} className="text-primary">
                                    <Phone className="w-3 h-3" />
                                  </a>
                                )}
                              </div>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* Vehicles */}
                      {flatVehicles.length > 0 && (
                        <div>
                          <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium mb-1.5">Vehicles ({flatVehicles.length})</p>
                          <div className="flex flex-wrap gap-1.5">
                            {flatVehicles.map(v => (
                              <span key={v.id} className="flex items-center gap-1 bg-secondary/50 rounded-lg px-2.5 py-1.5 text-xs">
                                <Car className="w-3 h-3 text-muted-foreground" />
                                <span className="font-mono font-medium">{v.vehicleNumber}</span>
                                <span className="text-[10px] text-muted-foreground capitalize">({v.vehicleType})</span>
                              </span>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )
      )}

      {/* === VISITORS VIEW === */}
      {viewMode === 'visitors' && (
        filteredVisitors.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-12">{t('directory.noVisitors')}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {filteredVisitors.map(({ latest: v, totalVisits, firstVisit }) => {
              const isExpanded = expandedId === v.phone;
              return (
                <div key={v.phone} className="card-section">
                  <button type="button" className="w-full flex items-center gap-3 text-left" onClick={() => setExpandedId(isExpanded ? null : v.phone)}>
                    <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center flex-shrink-0 overflow-hidden">
                      {v.visitorPhotos.length > 0 ? <img src={v.visitorPhotos[0]} alt={v.name} className="w-full h-full object-cover" />
                        : <span className="text-sm font-bold text-muted-foreground">{v.name.charAt(0).toUpperCase()}</span>}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold truncate">{v.name}</p>
                      <p className="text-xs font-mono text-muted-foreground">{v.phone}</p>
                    </div>
                    <div className="text-right flex-shrink-0 flex items-center gap-2">
                      <span className="text-[10px] text-primary font-medium">{totalVisits}x</span>
                      {isExpanded ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
                    </div>
                  </button>
                  {isExpanded && (
                    <div className="mt-3 pt-3 border-t border-border">
                      {v.visitorPhotos.length > 0 && (
                        <div className="flex gap-2 mb-3 flex-wrap">
                          {v.visitorPhotos.map((p, i) => <img key={i} src={p} alt={`Photo ${i + 1}`} className="w-20 h-20 rounded-lg object-cover border border-border" />)}
                        </div>
                      )}
                      <div className="grid grid-cols-2 gap-2 text-xs">
                        <div><span className="text-muted-foreground">{t('common.flat')}:</span><span className="ml-1 font-medium">{v.flatNumber}</span></div>
                        <div><span className="text-muted-foreground">{t('directory.category')}:</span><span className="ml-1 font-medium capitalize">{v.category}</span></div>
                        <div><span className="text-muted-foreground">{t('directory.document')}:</span><span className="ml-1 font-medium">{v.documentType} {v.documentNumber && `— ${v.documentNumber}`}</span></div>
                        <div><span className="text-muted-foreground">{t('visitor.purpose')}:</span><span className="ml-1 font-medium">{v.purpose}</span></div>
                        {v.vehicleNumber && <div><span className="text-muted-foreground">{t('blacklist.vehicle')}:</span><span className="ml-1 font-mono font-medium">{v.vehicleNumber}</span></div>}
                        <div><span className="text-muted-foreground">{t('directory.firstVisit')}:</span><span className="ml-1 font-medium">{format(new Date(firstVisit), 'dd MMM yyyy')}</span></div>
                        <div><span className="text-muted-foreground">{t('directory.lastVisit')}:</span><span className="ml-1 font-medium">{format(new Date(v.entryTime), 'dd MMM yyyy')}</span></div>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )
      )}
    </div>
  );
};

export default DirectoryPage;
