import { Link } from "react-router-dom";
import { LegalPageLayout } from "@/components/LegalPageLayout";

const TermsOfServicePage = () => {
  return (
    <LegalPageLayout title="Terms of Service">
      <div className="space-y-6 text-sm leading-relaxed text-muted-foreground">
        <p className="text-foreground">
          <strong className="font-medium text-foreground">Last updated:</strong> April 5, 2026
        </p>
        <p>
          These Terms of Service (“Terms”) govern your access to and use of Kutumbika (the
          “Service”), provided by BrandZaha (“we,” “us,” or “our”). By using the Service, you agree to these
          Terms. If you do not agree, do not use the Service.
        </p>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">1. The Service</h2>
          <p>
            Kutumbika offers tools for residential societies and related workflows, such as visitor
            management, logs, and associated features. Features may change over time. We do not guarantee
            uninterrupted or error-free operation.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">2. Eligibility and accounts</h2>
          <p>
            You must have authority to use the Service on behalf of yourself or your organization. You are
            responsible for safeguarding credentials and for all activity under your account. Notify us
            promptly of unauthorized use via the contact details on our Contact page.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">3. Acceptable use</h2>
          <p>You agree not to:</p>
          <ul className="list-disc space-y-2 pl-5">
            <li>Violate applicable law or third-party rights;</li>
            <li>Attempt to gain unauthorized access to the Service, other accounts, or underlying systems;</li>
            <li>Interfere with or disrupt the Service or its infrastructure;</li>
            <li>Use the Service to harass, harm, or mislead others, or to collect data without proper basis;</li>
            <li>Reverse engineer, scrape, or automate the Service in violation of these Terms or our technical policies.</li>
          </ul>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">4. Societies and administrators</h2>
          <p>
            Where the Service is deployed for a society or building, administrators may configure policies,
            access roles, and data practices. Their instructions may affect how your information is processed.
            Separate agreements between you and your society may also apply.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">5. Intellectual property</h2>
          <p>
            The Service, including software, branding, and documentation, is owned by us or our licensors. We
            grant you a limited, non-exclusive, non-transferable right to use the Service according to these
            Terms. You retain rights in content you submit; you grant us a license to host, process, and
            display that content as needed to operate the Service.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">6. Disclaimers</h2>
          <p>
            THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE,” WITHOUT WARRANTIES OF ANY KIND, WHETHER
            EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
            NON-INFRINGEMENT, TO THE MAXIMUM EXTENT PERMITTED BY LAW.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">7. Limitation of liability</h2>
          <p>
            TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL,
            SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, OR GOODWILL, ARISING
            FROM YOUR USE OF THE SERVICE. OUR AGGREGATE LIABILITY FOR ANY CLAIM RELATING TO THE SERVICE SHALL
            NOT EXCEED THE GREATER OF (A) THE AMOUNTS YOU PAID US FOR THE SERVICE IN THE TWELVE MONTHS BEFORE
            THE CLAIM OR (B) ONE HUNDRED INDIAN RUPEES, IF NO FEES APPLIED.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">8. Indemnity</h2>
          <p>
            You will defend and indemnify us and our affiliates against claims, damages, losses, and expenses
            (including reasonable legal fees) arising from your misuse of the Service, your content, or your
            violation of these Terms or applicable law.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">9. Suspension and termination</h2>
          <p>
            We may suspend or terminate access to the Service for breach of these Terms, risk to security, or
            legal requirements. Provisions that by their nature should survive will survive termination.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">10. Governing law</h2>
          <p>
            These Terms are governed by the laws of India, without regard to conflict-of-law principles.
            Courts in India shall have exclusive jurisdiction, subject to mandatory consumer protections where
            applicable.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">11. Changes</h2>
          <p>
            We may modify these Terms by posting an updated version. Material changes may be communicated
            through the Service or other reasonable means. Continued use after the effective date constitutes
            acceptance unless law requires otherwise.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-base font-semibold text-foreground">12. Contact</h2>
          <p>
            For questions about these Terms, visit our{" "}
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

export default TermsOfServicePage;
