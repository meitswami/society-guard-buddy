import { Link } from 'react-router-dom';
import {
  ArrowLeft,
  Eye,
  Target,
  ClipboardList,
  Landmark,
  Scale,
  Users,
  ShieldCheck,
  IndianRupee,
  Bell,
  Car,
  Calendar,
  Vote,
  Split,
  Lightbulb,
  Rocket,
  Heart,
  Globe,
  Layers,
  ArrowRight,
} from 'lucide-react';

const AboutPage = () => {
  return (
    <div className="min-h-screen bg-background text-foreground font-display">
      {/* Header */}
      <header className="sticky top-0 z-10 border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80">
        <div className="container flex max-w-3xl items-center gap-3 py-4">
          <Link
            to="/"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4 shrink-0" aria-hidden />
            Home
          </Link>
          <span className="text-border">|</span>
          <h1 className="text-lg font-semibold tracking-tight">About Kutumbika</h1>
        </div>
      </header>

      <main className="container max-w-3xl py-8 pb-16 space-y-12">
        {/* Hero */}
        <section className="text-center space-y-3">
          <h2 className="text-2xl font-bold tracking-tight">Kutumbika</h2>
          <p className="text-lg text-primary font-medium italic">Parivaar Jaisi Society</p>
          <p className="text-sm text-muted-foreground max-w-xl mx-auto">
            A complete digital ecosystem for housing societies — bringing transparency, accountability,
            and community together under one roof.
          </p>
        </section>

        {/* ─── VISION ─── */}
        <section className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <Eye className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h2 className="text-xl font-bold">Our Vision</h2>
              <p className="text-xs text-muted-foreground">Where we're headed</p>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-border p-4 space-y-2 bg-card">
              <div className="flex items-center gap-2">
                <Rocket className="w-4 h-4 text-primary" />
                <h3 className="text-sm font-semibold">Immediate Goals</h3>
              </div>
              <ul className="space-y-1.5 text-xs text-muted-foreground">
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Zero manual registers — every transaction is digital and auditable</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>100% maintenance collection tracked with receipt-level detail</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Every expense has a head, receipt photo, and approval trail</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Monthly auto-generated financial reports sent to all members</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Real-time security — visitor logs, guard attendance, geofencing</li>
              </ul>
            </div>

            <div className="rounded-xl border border-border p-4 space-y-2 bg-card">
              <div className="flex items-center gap-2">
                <Globe className="w-4 h-4 text-primary" />
                <h3 className="text-sm font-semibold">Long-Term Vision</h3>
              </div>
              <ul className="space-y-1.5 text-xs text-muted-foreground">
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Fully self-auditing system — anomalies detected in real-time</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Predictive budgeting based on historical expense patterns</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Paperless AGM — resolutions, voting, minutes with e-signatures</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Integrated vendor management with GST compliance</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Multi-society federation — shared vendors, benchmarking</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>AI-powered insights — spending anomalies, maintenance predictions</li>
              </ul>
            </div>
          </div>

          <div className="rounded-xl border border-primary/20 bg-primary/5 p-4">
            <p className="text-xs text-foreground leading-relaxed">
              <strong className="text-primary">Our north star:</strong> Every society member — from the newest resident to the
              longest-serving committee member — should have complete visibility into how their society operates,
              where their money goes, and confidence that the system is fair, transparent, and accountable.
            </p>
          </div>
        </section>

        {/* ─── PURPOSE ─── */}
        <section className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <Target className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h2 className="text-xl font-bold">Purpose</h2>
              <p className="text-xs text-muted-foreground">Why this project exists</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="rounded-xl border border-border p-4 space-y-3 bg-card">
              <h3 className="text-sm font-semibold flex items-center gap-2">
                <Heart className="w-4 h-4 text-primary" /> Core Purpose
              </h3>
              <div className="grid gap-3 sm:grid-cols-2">
                {[
                  { icon: <IndianRupee className="w-4 h-4" />, title: 'Financial Transparency', desc: 'Every rupee collected and spent is recorded, visible, and auditable by all members.' },
                  { icon: <ShieldCheck className="w-4 h-4" />, title: 'Accountability', desc: 'Every action is logged with who, when, and from where — non-repudiation by design.' },
                  { icon: <Users className="w-4 h-4" />, title: 'Community Trust', desc: 'Residents see where their money goes. Committee decisions are documented and traceable.' },
                  { icon: <Lightbulb className="w-4 h-4" />, title: 'Error Elimination', desc: 'Digital records prevent overwriting, backdating, loss, and the human errors of manual registers.' },
                ].map((item, i) => (
                  <div key={i} className="flex items-start gap-2">
                    <div className="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0 mt-0.5">
                      {item.icon}
                    </div>
                    <div>
                      <p className="text-xs font-semibold">{item.title}</p>
                      <p className="text-[11px] text-muted-foreground">{item.desc}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="rounded-xl border border-border p-4 space-y-3 bg-card">
              <h3 className="text-sm font-semibold flex items-center gap-2">
                <Scale className="w-4 h-4 text-primary" /> Problems We Solve
              </h3>
              <ul className="space-y-2 text-xs text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="text-destructive font-bold">✗</span>
                  <span><strong className="text-foreground">Double-entry of maintenance</strong> — same flat credited twice → detected by automated duplicate alarms</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-destructive font-bold">✗</span>
                  <span><strong className="text-foreground">Negative cash/bank balance</strong> — expenses exceed receipts → flagged with root cause and fix steps</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-destructive font-bold">✗</span>
                  <span><strong className="text-foreground">Unverified payments</strong> — sitting for weeks without review → audit flags pending entries &gt; 7 days</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-destructive font-bold">✗</span>
                  <span><strong className="text-foreground">Recording vs reporting mismatch</strong> — what was entered ≠ what is shown → cross-checked automatically</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-destructive font-bold">✗</span>
                  <span><strong className="text-foreground">Lack of accountability</strong> — "who did what?" is unanswerable → every action logged with user, time, IP, device</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-destructive font-bold">✗</span>
                  <span><strong className="text-foreground">Paper-based visitor logs</strong> — lost, illegible, no search → digital with photo, time, flat, and approval chain</span>
                </li>
              </ul>
            </div>
          </div>
        </section>

        {/* ─── PLANNING & STRUCTURE ─── */}
        <section className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <ClipboardList className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h2 className="text-xl font-bold">Planning & Project Structure</h2>
              <p className="text-xs text-muted-foreground">How the system is organized</p>
            </div>
          </div>

          {/* Module map */}
          <div className="rounded-xl border border-border p-4 space-y-4 bg-card">
            <h3 className="text-sm font-semibold flex items-center gap-2">
              <Layers className="w-4 h-4 text-primary" /> System Modules
            </h3>
            <div className="grid gap-3 sm:grid-cols-2">
              {[
                { icon: <IndianRupee className="w-3.5 h-3.5" />, name: 'Finance', desc: 'Receipt types → Record receipt/payment → Transactions → Totals → Reminders' },
                { icon: <ShieldCheck className="w-3.5 h-3.5" />, name: 'Audit & Governance', desc: 'Security logs, duplicate alarms, self-audit engine, governance framework' },
                { icon: <Users className="w-3.5 h-3.5" />, name: 'Resident Portal', desc: 'View committee, pay maintenance, notices, complaints, directory' },
                { icon: <Landmark className="w-3.5 h-3.5" />, name: 'Guard Module', desc: 'Visitor entry/exit, vehicle tracking, geofence, biometric attendance' },
                { icon: <Calendar className="w-3.5 h-3.5" />, name: 'Meetings', desc: 'GBM/AGM/EC, attendees, decisions, documents, publish & notify' },
                { icon: <Vote className="w-3.5 h-3.5" />, name: 'Polls & Elections', desc: 'Standard polls, MC elections with ranked ballots, result banners' },
                { icon: <Bell className="w-3.5 h-3.5" />, name: 'Notifications', desc: 'FCM push, in-app center, targeted delivery, read receipts' },
                { icon: <Split className="w-3.5 h-3.5" />, name: 'Expense Splitter', desc: 'Group expenses, per-flat splits, settlement tracking' },
                { icon: <Car className="w-3.5 h-3.5" />, name: 'Parking & Vehicles', desc: 'Slot allocation, resident vehicles, visitor parking' },
                { icon: <Scale className="w-3.5 h-3.5" />, name: 'Admin Panel', desc: 'All modules + user management + society settings + RBAC' },
              ].map((mod, i) => (
                <div key={i} className="flex items-start gap-2 p-2 rounded-lg bg-muted/30">
                  <div className="w-6 h-6 rounded bg-primary/10 flex items-center justify-center flex-shrink-0 mt-0.5">
                    {mod.icon}
                  </div>
                  <div>
                    <p className="text-xs font-semibold">{mod.name}</p>
                    <p className="text-[10px] text-muted-foreground">{mod.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Data flow */}
          <div className="rounded-xl border border-border p-4 space-y-3 bg-card">
            <h3 className="text-sm font-semibold flex items-center gap-2">
              <ArrowRight className="w-4 h-4 text-primary" /> Data Flow & Integrity
            </h3>
            <div className="space-y-2 text-xs text-muted-foreground">
              <div className="flex items-center gap-2 flex-wrap">
                {['Payment Recorded', 'maintenance_payment', 'finance_entry', 'allocations', 'Period Report'].map((step, i, arr) => (
                  <span key={i} className="flex items-center gap-1">
                    <span className="px-2 py-1 rounded bg-primary/10 text-primary text-[10px] font-medium">{step}</span>
                    {i < arr.length - 1 && <ArrowRight className="w-3 h-3 text-muted-foreground" />}
                  </span>
                ))}
              </div>
              <ul className="space-y-1 mt-2">
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Every payment creates both a payment record AND a ledger entry</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Allocations break down per-flat amounts for multi-flat recordings</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Period reports compute: Opening + Receipts − Expenses = Closing</li>
                <li className="flex items-start gap-2"><span className="text-primary">•</span>Self-Audit cross-verifies these relationships and flags any break</li>
              </ul>
            </div>
          </div>

          {/* Collaboration */}
          <div className="rounded-xl border border-border p-4 space-y-3 bg-card">
            <h3 className="text-sm font-semibold flex items-center gap-2">
              <Users className="w-4 h-4 text-primary" /> Collaboration & Roles
            </h3>
            <div className="overflow-x-auto">
              <table className="w-full text-xs">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-2 pr-3 font-semibold text-foreground">Role</th>
                    <th className="text-left py-2 font-semibold text-foreground">Responsibilities</th>
                  </tr>
                </thead>
                <tbody className="text-muted-foreground">
                  <tr className="border-b border-border/50">
                    <td className="py-2 pr-3 font-medium text-foreground">Admin</td>
                    <td className="py-2">Records day-to-day transactions, manages visitors, guards, and notices</td>
                  </tr>
                  <tr className="border-b border-border/50">
                    <td className="py-2 pr-3 font-medium text-foreground">Treasurer</td>
                    <td className="py-2">Reviews and verifies payments, runs monthly self-audit, reconciles bank</td>
                  </tr>
                  <tr className="border-b border-border/50">
                    <td className="py-2 pr-3 font-medium text-foreground">Secretary</td>
                    <td className="py-2">Manages meetings, ensures minutes reference financial decisions</td>
                  </tr>
                  <tr className="border-b border-border/50">
                    <td className="py-2 pr-3 font-medium text-foreground">Committee</td>
                    <td className="py-2">Views reports, approves large expenses, participates in decisions</td>
                  </tr>
                  <tr>
                    <td className="py-2 pr-3 font-medium text-foreground">Residents</td>
                    <td className="py-2">View payment history, society summaries, raise complaints, vote in polls</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* Tech architecture */}
          <div className="rounded-xl border border-border p-4 space-y-3 bg-card">
            <h3 className="text-sm font-semibold">Technology Stack</h3>
            <div className="flex flex-wrap gap-2">
              {[
                'React 18', 'TypeScript', 'Vite', 'Tailwind CSS', 'shadcn/ui',
                'Zustand', 'Supabase', 'PostgreSQL', 'Row Level Security',
                'Edge Functions', 'jsPDF', 'Capacitor', 'FCM', 'WebAuthn',
              ].map((tech) => (
                <span key={tech} className="px-2 py-1 rounded-full bg-muted text-[10px] font-medium text-muted-foreground">
                  {tech}
                </span>
              ))}
            </div>
          </div>
        </section>

        {/* ─── PRINCIPLES ─── */}
        <section className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <Landmark className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h2 className="text-xl font-bold">Guiding Principles</h2>
              <p className="text-xs text-muted-foreground">Values that drive every decision</p>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            {[
              { title: 'Transparency First', desc: 'Every financial transaction, every decision, every action is visible to those it affects. No hidden ledgers.' },
              { title: 'Accountability by Design', desc: 'The system does not just record - it enforces. Who did what, when, and from where is always answerable.' },
              { title: 'Member-Centric', desc: 'Built for residents, not just administrators. Self-service, visibility, and participation are core features.' },
              { title: 'Data Integrity', desc: 'Cross-verification at every layer. Recording must match reporting. Discrepancies are flagged, not hidden.' },
              { title: 'Simplicity', desc: 'Mobile-first, minimal clicks. A guard with basic smartphone skills can operate the gate module.' },
              { title: 'Compliance Ready', desc: 'Designed to meet Co-operative Societies Act requirements, IT filing needs, and GST tracking.' },
            ].map((p, i) => (
              <div key={i} className="rounded-xl border border-border p-4 bg-card">
                <p className="text-sm font-semibold text-foreground">{p.title}</p>
                <p className="text-xs text-muted-foreground mt-1">{p.desc}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Footer CTA */}
        <section className="text-center space-y-3 pt-4">
          <p className="text-xs text-muted-foreground">
            Built with ❤️ by <strong className="text-foreground">MCSPL</strong> · Copyright © 2026
          </p>
          <div className="flex items-center justify-center gap-3">
            <Link to="/privacy" className="text-xs text-primary hover:underline">Privacy</Link>
            <span className="text-border">·</span>
            <Link to="/terms" className="text-xs text-primary hover:underline">Terms</Link>
            <span className="text-border">·</span>
            <Link to="/contact" className="text-xs text-primary hover:underline">Contact</Link>
          </div>
        </section>
      </main>
    </div>
  );
};

export default AboutPage;
