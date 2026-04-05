import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

type LegalPageLayoutProps = {
  title: string;
  children: ReactNode;
};

const legalLinks = [
  { to: "/privacy", label: "Privacy Policy" },
  { to: "/terms", label: "Terms of Service" },
  { to: "/contact", label: "Contact" },
] as const;

export function LegalPageLayout({ title, children }: LegalPageLayoutProps) {
  return (
    <div className="min-h-screen bg-background text-foreground font-display">
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
          <h1 className="text-lg font-semibold tracking-tight">{title}</h1>
        </div>
      </header>

      <main className="container max-w-3xl py-8 pb-16">{children}</main>

      <footer className="border-t border-border py-6">
        <nav
          className="container flex max-w-3xl flex-wrap gap-x-4 gap-y-2 text-sm text-muted-foreground"
          aria-label="Legal"
        >
          {legalLinks.map(({ to, label }) => (
            <Link key={to} to={to} className="underline-offset-4 hover:text-foreground hover:underline">
              {label}
            </Link>
          ))}
        </nav>
      </footer>
    </div>
  );
}
