import { useState } from 'react';
import {
  Landmark,
  Target,
  Eye,
  ClipboardList,
  Scale,
  ChevronDown,
  ChevronUp,
  Lightbulb,
  Users,
  ShieldCheck,
  BookOpen,
} from 'lucide-react';

/* ─── Governance Framework Data ─── */

interface Section {
  id: string;
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  content: {
    heading: string;
    points: string[];
  }[];
}

const sections: Section[] = [
  {
    id: 'principal',
    icon: <Landmark className="w-4 h-4" />,
    title: 'Principal',
    subtitle: 'Who governs and the authority structure',
    content: [
      {
        heading: 'Governing Authority',
        points: [
          'The Managing Committee (MC) is the principal governing body elected by the General Body of members.',
          'MC acts as a fiduciary — managing society assets, funds, and operations on behalf of all members.',
          'All decisions must be traceable to either MC resolution, General Body resolution, or bye-law authority.',
          'The Treasurer is the custodian of funds; the Secretary is the custodian of records.',
        ],
      },
      {
        heading: 'Accountability Chain',
        points: [
          'General Body → Managing Committee → Office Bearers → Admin Staff → Guards/Vendors.',
          'Every financial transaction must have an identifiable recorder (admin) and approver (office bearer).',
          'This app enforces accountability by logging who recorded, verified, or rejected each entry.',
          'Audit trail in this section provides non-repudiation — actions cannot be denied after the fact.',
        ],
      },
    ],
  },
  {
    id: 'purpose',
    icon: <Target className="w-4 h-4" />,
    title: 'Purpose',
    subtitle: 'Why this system exists and what it solves',
    content: [
      {
        heading: 'Core Purpose',
        points: [
          'Transparent financial management — every rupee collected and spent is recorded and visible.',
          'Eliminate manual register errors — digital records prevent overwriting, backdating, and loss.',
          'Real-time audit capability — detect discrepancies immediately, not months later.',
          'Member trust — residents can see where their maintenance money goes.',
        ],
      },
      {
        heading: 'Problems Addressed',
        points: [
          'Double-entry of maintenance (same flat credited twice) — detected by Duplicate Alarms above.',
          'Negative cash/bank balance — flagged by Internal Audit with root cause and fix steps.',
          'Unverified payments sitting for weeks — audit flags pending entries > 7 days.',
          'Mismatch between what was recorded vs what is reported — cross-checked automatically.',
          'Lack of accountability — every action is logged with user, timestamp, IP, and device.',
        ],
      },
    ],
  },
  {
    id: 'vision',
    icon: <Eye className="w-4 h-4" />,
    title: 'Vision',
    subtitle: 'Where the society management is headed',
    content: [
      {
        heading: 'Short-Term Vision (Current Year)',
        points: [
          'Zero manual registers — all financial and visitor records are digital.',
          '100% maintenance collection tracked with receipt-level detail.',
          'Every expense has a head, receipt photo, and approval trail.',
          'Monthly auto-generated financial reports sent to all members.',
        ],
      },
      {
        heading: 'Long-Term Vision',
        points: [
          'Fully self-auditing system — anomalies detected and flagged in real-time without human intervention.',
          'Predictive budgeting — based on historical expense patterns, forecast next quarter's needs.',
          'Paperless AGM — resolutions, voting, minutes all digital with e-signatures.',
          'Integrated vendor management — payments to vendors tracked end-to-end with GST compliance.',
          'Member self-service — residents view their ledger, download receipts, raise disputes online.',
        ],
      },
    ],
  },
  {
    id: 'planning',
    icon: <ClipboardList className="w-4 h-4" />,
    title: 'Planning & Structure',
    subtitle: 'How the project is organized and maintained',
    content: [
      {
        heading: 'Project Structure',
        points: [
          'Finance Module: Maintenance charges → Payments → Ledger entries → Period reports.',
          'Audit Module: Security logs + Finance alarms + Self-audit engine + Governance guide.',
          'Resident Portal: View committee, pay maintenance, see notices, raise complaints.',
          'Guard Module: Visitor entry/exit, vehicle tracking, geofence, biometric attendance.',
          'Admin Panel: All modules + user management + society settings.',
        ],
      },
      {
        heading: 'Data Flow & Integrity',
        points: [
          'Every payment creates both a maintenance_payment record AND a finance_entry (ledger).',
          'finance_entry_allocations break down per-flat amounts for multi-flat recordings.',
          'Expense entries (separate_entry) reduce the balance; receipt entries increase it.',
          'Period reports compute: Opening Balance + Receipts − Expenses = Closing Balance.',
          'The Self-Audit button cross-verifies these relationships and flags any break in the chain.',
        ],
      },
      {
        heading: 'Collaboration Guidelines',
        points: [
          'Admin records day-to-day transactions (receipts, expenses, visitor logs).',
          'Treasurer reviews and verifies — especially bank entries and large amounts.',
          'Secretary ensures meeting minutes reference financial decisions.',
          'Committee members can view reports but cannot modify financial records.',
          'Residents view their own payment history and society-level summaries.',
        ],
      },
    ],
  },
  {
    id: 'policy',
    icon: <Scale className="w-4 h-4" />,
    title: 'Policy & Compliance',
    subtitle: 'Rules, standards, and issue resolution',
    content: [
      {
        heading: 'Financial Policies',
        points: [
          'All cash receipts must be recorded on the same day they are collected.',
          'Bank/UPI receipts must be verified against bank statement within 48 hours.',
          'No expense above ₹5,000 without prior MC approval (documented in meeting minutes).',
          'Petty cash limit: ₹2,000 maximum without receipt photo.',
          'Monthly reconciliation: Cash in hand + Bank balance must match system closing balance.',
          'Any negative balance is a policy violation — must be rectified within 24 hours of detection.',
        ],
      },
      {
        heading: 'Audit Policies',
        points: [
          'Internal self-audit must be run at least once per month by the Treasurer.',
          'All "Critical" findings must be resolved before the next General Body meeting.',
          '"Warning" findings must be documented with an action plan within 7 days.',
          'Duplicate entries must be deleted (not just rejected) to prevent reporting inflation.',
          'Orphaned payments (no ledger link) must be re-recorded properly or documented as legacy.',
        ],
      },
      {
        heading: 'Common Policy Issues & Resolution',
        points: [
          'Issue: Resident claims payment but no record exists → Check bank statement, ask for screenshot, record with note.',
          'Issue: Negative cash balance → Run self-audit, identify mistagged payment method, correct it.',
          'Issue: Committee member questions expense → Show finance_entry with receipt photo and approval trail.',
          'Issue: Guard recorded wrong flat for visitor → Edit in visitor log, add correction note in audit.',
          'Issue: Two admins recorded same payment → Duplicate alarm will flag it; delete the later entry.',
          'Issue: Maintenance amount changed mid-month → Update charge definition; existing payments remain at old amount (this is correct).',
        ],
      },
      {
        heading: 'Regulatory Compliance',
        points: [
          'Maharashtra Co-operative Societies Act / State Housing Society Act compliance.',
          'Books of accounts must be maintained as per Section 79/80 of the Act.',
          'Annual audit by certified auditor — this system provides digital-ready data export.',
          'Income Tax: Society income above threshold requires ITR filing — period reports support this.',
          'GST: If society turnover exceeds limit, vendor payments must track GST — expense heads support this.',
        ],
      },
    ],
  },
];

/* ─── Component ─── */

const SocietyGovernanceGuide = () => {
  const [expandedSection, setExpandedSection] = useState<string | null>(null);

  return (
    <div className="space-y-3">
      {/* Header */}
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
          <BookOpen className="w-4 h-4 text-primary" />
        </div>
        <div>
          <h3 className="text-sm font-semibold">Society Governance Framework</h3>
          <p className="text-[10px] text-muted-foreground">
            Principal · Purpose · Vision · Planning · Policy
          </p>
        </div>
      </div>

      {/* Sections */}
      {sections.map((section) => (
        <div
          key={section.id}
          className="card-section overflow-hidden"
        >
          <button
            type="button"
            className="w-full p-3 flex items-center gap-3 text-left hover:bg-muted/30 transition-colors"
            onClick={() => setExpandedSection(expandedSection === section.id ? null : section.id)}
          >
            <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
              {section.icon}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold">{section.title}</p>
              <p className="text-[10px] text-muted-foreground">{section.subtitle}</p>
            </div>
            {expandedSection === section.id ? (
              <ChevronUp className="w-4 h-4 text-muted-foreground flex-shrink-0" />
            ) : (
              <ChevronDown className="w-4 h-4 text-muted-foreground flex-shrink-0" />
            )}
          </button>

          {expandedSection === section.id && (
            <div className="px-3 pb-3 space-y-3 border-t border-border pt-3">
              {section.content.map((block, bIdx) => (
                <div key={bIdx}>
                  <p className="text-xs font-semibold text-primary mb-1.5 flex items-center gap-1">
                    <Lightbulb className="w-3 h-3" /> {block.heading}
                  </p>
                  <ul className="space-y-1.5">
                    {block.points.map((point, pIdx) => (
                      <li key={pIdx} className="text-xs text-foreground flex items-start gap-2">
                        <span className="text-primary mt-0.5 flex-shrink-0">•</span>
                        <span>{point}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          )}
        </div>
      ))}

      {/* Quick reference footer */}
      <div className="card-section p-3 bg-muted/30">
        <div className="flex items-start gap-2">
          <ShieldCheck className="w-4 h-4 text-primary mt-0.5 flex-shrink-0" />
          <div>
            <p className="text-xs font-medium">How to use this section</p>
            <p className="text-[10px] text-muted-foreground mt-0.5">
              This governance guide serves as a reference for committee members and admins.
              Share it during AGMs, onboarding new committee members, or when resolving disputes.
              The policies above should be adopted via MC resolution and communicated to all members.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SocietyGovernanceGuide;
