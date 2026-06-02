import { Calendar, UtensilsCrossed } from 'lucide-react';
import EventManager from '@/components/EventManager';
import ExpenseSplitter from '@/components/ExpenseSplitter';
import type { AdminTab } from '@/lib/adminPermissions';

type Props = {
  adminName?: string;
  onNavigateTab?: (tab: AdminTab) => void;
};

/**
 * Single module: calendar events + food/catering costs split by family headcount.
 * All other society payments → Finance → Record Payment.
 */
const EventsModule = ({ adminName = 'Admin', onNavigateTab }: Props) => {
  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
          <Calendar className="w-5 h-5 text-blue-500" />
        </div>
        <div>
          <h1 className="page-title">Events &amp; food expenses</h1>
          <p className="text-xs text-muted-foreground leading-snug">
            Functions, RSVPs, contributions, and <span className="text-foreground">food / catering</span> split by
            adults &amp; kids per flat.
          </p>
        </div>
      </div>

      <div className="card-section p-3 mb-4 border-primary/20 bg-primary/5">
        <p className="text-xs text-foreground leading-relaxed">
          <UtensilsCrossed className="w-3.5 h-3.5 inline mr-1 text-primary align-text-bottom" />
          Record food and catering for an event below. For electricity,
          vendors, repairs, salaries, or other society payments, use{' '}
          {onNavigateTab ? (
            <button
              type="button"
              className="text-primary underline font-medium"
              onClick={() => onNavigateTab('finance')}
            >
              Finance → Record Payment
            </button>
          ) : (
            <span className="font-medium">Finance → Record Payment</span>
          )}
          .
        </p>
      </div>

      <section className="mb-6">
        <h2 className="text-sm font-semibold mb-2 flex items-center gap-2">
          <Calendar className="w-4 h-4 text-blue-500" />
          Events &amp; contributions
        </h2>
        <EventManager adminName={adminName} embedded />
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-2 flex items-center gap-2">
          <UtensilsCrossed className="w-4 h-4 text-orange-500" />
          Food expenses (split by family)
        </h2>
        <ExpenseSplitter
          adminName={adminName}
          foodOnly
          embedded
          onOpenFinance={onNavigateTab ? () => onNavigateTab('finance') : undefined}
        />
      </section>
    </div>
  );
};

export default EventsModule;
