import { Link } from "react-router-dom";
import { useLanguage } from "@/i18n/LanguageContext";

const linkClass =
  "min-w-0 break-words px-1 py-0.5 text-center text-muted-foreground underline-offset-2 hover:text-foreground hover:underline";

export function LoginFooter() {
  const { t } = useLanguage();

  return (
    <footer className="absolute bottom-0 left-0 right-0 z-10 border-t border-border/60 bg-background/95 px-3 pt-3 backdrop-blur supports-[backdrop-filter]:bg-background/80 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      <div className="mx-auto flex w-full max-w-xl flex-col items-center gap-2">
        <nav
          className="mx-auto flex w-full max-w-xl flex-wrap items-center justify-center gap-y-1 text-[10px] leading-tight sm:grid sm:max-w-2xl sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)_auto_minmax(0,1fr)] sm:items-center sm:justify-items-center sm:gap-y-0 sm:text-xs"
          aria-label="Legal"
        >
          <Link to="/privacy" className={linkClass}>
            {t("login.footerPrivacy")}
          </Link>
          <span className="mx-0.5 shrink-0 text-border sm:mx-0" aria-hidden>
            |
          </span>
          <Link to="/terms" className={linkClass}>
            {t("login.footerTerms")}
          </Link>
          <span className="mx-0.5 shrink-0 text-border sm:mx-0" aria-hidden>
            |
          </span>
          <Link to="/contact" className={linkClass}>
            {t("login.footerContact")}
          </Link>
        </nav>
        <p className="text-center text-[10px] text-muted-foreground sm:text-[11px]">{t("app.footer")}</p>
      </div>
    </footer>
  );
}
