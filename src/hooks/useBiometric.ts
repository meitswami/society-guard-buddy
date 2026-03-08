import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';

function bufferToBase64(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)));
}

function base64ToBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

export function useBiometric() {
  const [loading, setLoading] = useState(false);

  const isAvailable = useCallback(async (): Promise<boolean> => {
    if (!window.PublicKeyCredential) return false;
    try {
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    } catch { return false; }
  }, []);

  const register = useCallback(async (userType: string, userId: string, userName: string): Promise<boolean> => {
    setLoading(true);
    try {
      const challenge = crypto.getRandomValues(new Uint8Array(32));
      const credential = await navigator.credentials.create({
        publicKey: {
          challenge,
          rp: { name: 'Evergreen Heights', id: window.location.hostname },
          user: {
            id: new TextEncoder().encode(userId),
            name: userName,
            displayName: userName,
          },
          pubKeyCredParams: [{ alg: -7, type: 'public-key' }, { alg: -257, type: 'public-key' }],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required',
          },
          timeout: 60000,
        },
      }) as PublicKeyCredential;

      if (!credential) return false;

      const response = credential.response as AuthenticatorAttestationResponse;
      const credentialId = bufferToBase64(credential.rawId);
      const publicKey = bufferToBase64(response.attestationObject);

      // Delete old credentials for this user
      await supabase.from('biometric_credentials').delete()
        .eq('user_type', userType).eq('user_id', userId);

      const { error } = await supabase.from('biometric_credentials').insert({
        user_type: userType,
        user_id: userId,
        credential_id: credentialId,
        public_key: publicKey,
      });

      return !error;
    } catch (e) {
      console.error('Biometric registration failed:', e);
      return false;
    } finally {
      setLoading(false);
    }
  }, []);

  const authenticate = useCallback(async (userType: string): Promise<{ userId: string } | null> => {
    setLoading(true);
    try {
      // Get all credentials for this user type
      const { data: creds } = await supabase.from('biometric_credentials')
        .select('credential_id, user_id')
        .eq('user_type', userType);

      if (!creds || creds.length === 0) return null;

      const challenge = crypto.getRandomValues(new Uint8Array(32));
      const allowCredentials = creds.map(c => ({
        id: base64ToBuffer(c.credential_id),
        type: 'public-key' as const,
      }));

      const assertion = await navigator.credentials.get({
        publicKey: {
          challenge,
          allowCredentials,
          userVerification: 'required',
          timeout: 60000,
        },
      }) as PublicKeyCredential;

      if (!assertion) return null;

      const matchedCredId = bufferToBase64(assertion.rawId);
      const matched = creds.find(c => c.credential_id === matchedCredId);

      return matched ? { userId: matched.user_id } : null;
    } catch (e) {
      console.error('Biometric auth failed:', e);
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const hasCredential = useCallback(async (userType: string, userId: string): Promise<boolean> => {
    const { data } = await supabase.from('biometric_credentials')
      .select('id').eq('user_type', userType).eq('user_id', userId).limit(1);
    return !!(data && data.length > 0);
  }, []);

  return { isAvailable, register, authenticate, hasCredential, loading };
}
