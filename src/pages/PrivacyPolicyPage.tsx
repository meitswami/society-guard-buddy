import { Link } from "react-router-dom";
import { LegalPageLayout } from "@/components/LegalPageLayout";

const PrivacyPolicyPage = () => {
  return (
    <LegalPageLayout title="Privacy Policy">
      <div className="space-y-6 text-sm leading-relaxed text-muted-foreground">
        <p className="text-foreground">
          <strong className="font-medium text-foreground">Last updated:</strong> April 5, 2026
        </p>
        <p>
          BrandZaha (“we,” “us,” or “our”) operates Kutumbika (the “Service”). This Privacy Policy
          describes how we collect, use, and share information when you use our websites, mobile applications,
          and related services.
        </p>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">1. Information we collect</h2>
          <ul className="list-disc space-y-2 pl-5">
            <li>
              <span className="text-foreground">Account and profile data:</span> such as name, phone number,
              email (if provided), society or building identifiers, and role (for example guard, resident, or
              administrator).
            </li>
            <li>
              <span className="text-foreground">Operational data:</span> visitor and vehicle logs, directory
              information you or your society chooses to store, photos or notes captured as part of entry
              workflows, and similar records needed to run the Service.
            </li>
            <li>
              <span className="text-foreground">Device and technical data:</span> device type, operating
              system, app version, push notification tokens, and diagnostic or security logs.
            </li>
          </ul>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">2. How we use information</h2>
          <p>We use information to:</p>
          <ul className="list-disc space-y-2 pl-5">
            <li>Provide, maintain, and improve the Service;</li>
            <li>Authenticate users, enforce access controls, and protect against fraud or abuse;</li>
            <li>Send service-related messages (including security alerts and, where enabled, push notifications);</li>
            <li>Comply with law and respond to lawful requests.</li>
          </ul>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">3. Sharing</h2>
          <p>
            We may share information with service providers who assist us (for example hosting, authentication,
            messaging, or analytics), strictly as needed to operate the Service. We may disclose information if
            required by law or to protect rights, safety, and security. Societies or administrators may access
            data submitted within their own deployment according to their policies.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">4. Retention</h2>
          <p>
            We retain information for as long as necessary to provide the Service, meet legal obligations,
            resolve disputes, and enforce our agreements. Retention periods may depend on your society’s
            configuration and applicable law.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">5. Security</h2>
          <p>
            We implement reasonable technical and organizational measures designed to protect information.
            No method of transmission or storage is completely secure; use the Service at your own risk
            alongside your organization’s policies.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">6. Your choices</h2>
          <p>
            Depending on your region, you may have rights to access, correct, delete, or restrict processing
            of your personal information, or to object to certain processing. Contact us using the details on
            the Contact page. We may need to verify your request.
          </p>
          <p>
            For account deletion instructions, see{" "}
            <Link to="/delete-account" className="text-primary underline underline-offset-4 hover:text-primary/90">
              Delete Account
            </Link>.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">7. Children</h2>
          <p>
            The Service is not directed at children under 13 (or the minimum age in your jurisdiction). We do
            not knowingly collect personal information from children.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">8. International transfers</h2>
          <p>
            If you use the Service from outside the country where our systems are located, your information
            may be transferred and processed in other countries where laws may differ.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">9. Changes</h2>
          <p>
            We may update this Privacy Policy from time to time. We will post the updated version and revise
            the “Last updated” date. Continued use of the Service after changes constitutes acceptance unless
            law requires otherwise.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">10. Contact</h2>
          <p>
            Questions about this policy: see our{" "}
            <Link to="/contact" className="text-primary underline underline-offset-4 hover:text-primary/90">
              Contact
            </Link>{" "}
            page.
          </p>
        </section>
      </div>
    </LegalPageLayout>
  );
};

export default PrivacyPolicyPage;
