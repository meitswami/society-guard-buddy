import { generateSecret, generateURI, verifySync } from 'otplib';

const ISSUER = 'Society Guard Buddy';

export function generateTotpSecret(): string {
  return generateSecret();
}

/** otpauth URI for Microsoft Authenticator / Google Authenticator (TOTP). */
export function buildTotpKeyUri(secret: string, username: string): string {
  return generateURI({
    issuer: ISSUER,
    label: username,
    secret,
    algorithm: 'sha1',
    digits: 6,
    period: 30,
  });
}

export function verifyTotpCode(secret: string, token: string): boolean {
  const cleaned = token.replace(/\s/g, '');
  if (!/^\d{6}$/.test(cleaned)) return false;
  const result = verifySync({
    secret,
    token: cleaned,
    algorithm: 'sha1',
    digits: 6,
    period: 30,
    epochTolerance: 30,
  });
  return result.valid;
}

export function totpQrImageUrl(otpauthUri: string, size = 180): string {
  return `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(otpauthUri)}`;
}
