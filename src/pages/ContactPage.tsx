import { Link } from "react-router-dom";
import { Mail, Phone } from "lucide-react";
import { LegalPageLayout } from "@/components/LegalPageLayout";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

const PHONE_DISPLAY = "+91 86194 36041";
const PHONE_E164 = "+918619436041";
const EMAIL = "info@brandzaha.com";

const ContactPage = () => {
  return (
    <LegalPageLayout title="Contact us">
      <div className="space-y-8">
        <p className="text-sm leading-relaxed text-muted-foreground">
          Reach BrandZaha for support, billing, or questions about Society Guard Buddy. We aim to respond
          within reasonable business hours.
        </p>

        <div className="grid gap-4 sm:grid-cols-1">
          <Card className="border-border bg-card">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base font-semibold">
                <Phone className="h-4 w-4 text-primary" aria-hidden />
                Phone
              </CardTitle>
              <CardDescription>Call during business hours or leave a voicemail.</CardDescription>
            </CardHeader>
            <CardContent>
              <a
                href={`tel:${PHONE_E164.replace(/\s/g, "")}`}
                className="text-lg font-medium text-primary underline-offset-4 hover:underline"
              >
                {PHONE_DISPLAY}
              </a>
            </CardContent>
          </Card>

          <Card className="border-border bg-card">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base font-semibold">
                <Mail className="h-4 w-4 text-primary" aria-hidden />
                Email
              </CardTitle>
              <CardDescription>For general inquiries and partnership questions.</CardDescription>
            </CardHeader>
            <CardContent>
              <a
                href={`mailto:${EMAIL}`}
                className="text-lg font-medium text-primary underline-offset-4 hover:underline break-all"
              >
                {EMAIL}
              </a>
            </CardContent>
          </Card>
        </div>

        <p className="text-xs text-muted-foreground">
          See also{" "}
          <Link to="/privacy" className="text-primary underline underline-offset-4 hover:text-primary/90">
            Privacy Policy
          </Link>{" "}
          and{" "}
          <Link to="/terms" className="text-primary underline underline-offset-4 hover:text-primary/90">
            Terms of Service
          </Link>
          .
        </p>
      </div>
    </LegalPageLayout>
  );
};

export default ContactPage;
