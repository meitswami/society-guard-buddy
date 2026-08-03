import { useState, useEffect, useMemo, useRef } from 'react';
import { Search, X, ArrowRight } from 'lucide-react';
import type { AdminTab } from '@/lib/adminPermissions';
import {
  ADMIN_SEARCH_ROUTES,
  findBestSearchRoute,
  searchRoutesForQuery,
  type AdminSearchRoute,
} from '@/lib/adminNavigation';
import { useLanguage } from '@/i18n/LanguageContext';

interface Props {
  open: boolean;
  onClose: () => void;
  allowedTabs: Set<AdminTab>;
  onNavigate: (tab: AdminTab, query: string) => void;
}

const AdminGlobalSearch = ({ open, onClose, allowedTabs, onNavigate }: Props) => {
  const { t } = useLanguage();
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  const results = useMemo(
    () => searchRoutesForQuery(query, allowedTabs),
    [query, allowedTabs],
  );

  const browseRoutes = useMemo(
    () => ADMIN_SEARCH_ROUTES.filter((r) => allowedTabs.has(r.tab)),
    [allowedTabs],
  );

  const handleSelect = (route: AdminSearchRoute) => {
    onNavigate(route.tab, query.trim());
    onClose();
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const q = query.trim();
    if (!q) return;
    const best = findBestSearchRoute(q, allowedTabs);
    if (best) {
      onNavigate(best.tab, q);
      onClose();
    }
  };

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] bg-black/45 p-4 flex items-start justify-center pt-[max(1rem,env(safe-area-inset-top))]">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-lg bg-card border border-border rounded-xl shadow-2xl overflow-hidden"
      >
        <div className="flex items-center gap-2 p-3 border-b border-border">
          <Search className="w-4 h-4 text-muted-foreground shrink-0" />
          <input
            ref={inputRef}
            type="search"
            className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            placeholder="Search flats, names, reports, audit…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            autoComplete="off"
          />
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg text-muted-foreground hover:text-foreground hover:bg-muted/50"
            aria-label="Close search"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="max-h-[min(60vh,420px)] overflow-y-auto p-2">
          {query.trim() ? (
            results.length === 0 ? (
              <p className="text-xs text-muted-foreground text-center py-8">
                No matching module. Try flat number, name, or report keyword.
              </p>
            ) : (
              <ul className="space-y-1">
                {results.map((route) => (
                  <li key={route.tab}>
                    <button
                      type="button"
                      onClick={() => handleSelect(route)}
                      className="w-full flex items-center justify-between gap-2 px-3 py-2.5 rounded-lg hover:bg-primary/10 text-left group"
                    >
                      <div>
                        <p className="text-sm font-medium">{t(route.labelKey)}</p>
                        <p className="text-[10px] text-muted-foreground">Searches: {route.hint}</p>
                      </div>
                      <ArrowRight className="w-4 h-4 text-muted-foreground group-hover:text-primary shrink-0" />
                    </button>
                  </li>
                ))}
              </ul>
            )
          ) : (
            <>
              <p className="text-[10px] uppercase tracking-wider text-muted-foreground px-2 py-1">
                Jump to module
              </p>
              <ul className="space-y-0.5">
                {browseRoutes.map((route) => (
                  <li key={route.tab}>
                    <button
                      type="button"
                      onClick={() => handleSelect(route)}
                      className="w-full flex items-center justify-between gap-2 px-3 py-2 rounded-lg hover:bg-muted/50 text-left text-sm"
                    >
                      <span>{t(route.labelKey)}</span>
                      <span className="text-[10px] text-muted-foreground">{route.hint}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>

        {query.trim() && results.length > 0 && (
          <div className="border-t border-border p-2">
            <button type="submit" className="btn-primary w-full text-xs py-2">
              Go to best match with &ldquo;{query.trim()}&rdquo;
            </button>
          </div>
        )}
      </form>
    </div>
  );
};

export default AdminGlobalSearch;
