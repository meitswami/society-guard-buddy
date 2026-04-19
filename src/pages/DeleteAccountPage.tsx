import { LegalPageLayout } from "@/components/LegalPageLayout";
import { Link } from "react-router-dom";

const SUPPORT_EMAIL = "info@brandzaha.com";
const SUPPORT_PHONE = "+91 86194 36041";

const DeleteAccountPage = () => {
  return (
    <LegalPageLayout title="Delete Account">
      <div className="space-y-6 text-sm leading-relaxed text-muted-foreground">
        <p className="text-foreground">
          <strong className="font-medium text-foreground">Last updated:</strong> April 14, 2026
        </p>
        <p>
          This page is for account deletion requests for <span className="text-foreground font-medium">Kutumbika</span>
          {" "}by <span className="text-foreground font-medium">BrandZaha</span>.
        </p>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-foreground">How to request account deletion</h2>
          <ol className="list-decimal space-y-1 pl-5">
            <li>Open the app and sign in using your registered account.</li>
            <li>Go to your profile/settings screen and choose account deletion request, or contact your society administrator.</li>
            <li>
              If you cannot access the app, submit a request from the{" "}
              <Link to="/contact" className="text-primary underline underline-offset-4 hover:text-primary/90">
                Contact
              </Link>{" "}
              page with your registered phone number and society/flat details.
            </li>
            <li>
              You can also email{" "}
              <a href={`mailto:${SUPPORT_EMAIL}`} className="text-primary underline underline-offset-4 hover:text-primary/90">
                {SUPPORT_EMAIL}
              </a>{" "}
              or call{" "}
              <a href="tel:+918619436041" className="text-primary underline underline-offset-4 hover:text-primary/90">
                {SUPPORT_PHONE}
              </a>.
            </li>
          </ol>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-foreground">What data is deleted</h2>
          <ul className="list-disc space-y-1 pl-5">
            <li>Account profile details linked to your login (for example name, phone, role, and login mapping).</li>
            <li>Push notification token registrations for your account/device.</li>
            <li>Any account-specific settings and access entries tied directly to your user record.</li>
          </ul>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-foreground">What data may be retained</h2>
          <ul className="list-disc space-y-1 pl-5">
            <li>
              Society operational records (for example visitor approvals, guard logs, payment records, and audit/security logs)
              may be retained as required by society policy or legal obligations.
            </li>
            <li>Backups may retain deleted data for a limited period before permanent purge.</li>
          </ul>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-foreground">Deletion timeline</h2>
          <p>
            We typically process verified deletion requests within 7-30 days. Some legal/audit data may be retained longer where
            required by law.
          </p>
        </section>
      </div>
    </LegalPageLayout>
  );
};

export default DeleteAccountPage;
