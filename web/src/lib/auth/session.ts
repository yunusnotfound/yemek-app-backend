import "server-only";
import { cookies } from "next/headers";

/**
 * Oturum = backend'in döndürdüğü JWT'leri httpOnly çerezlerde tutmak.
 * Çerezler JS'ye kapalı (httpOnly) olduğundan token'lar XSS'e açık değildir.
 * Bu modül yalnızca route handler / server action içinde çağrılmalıdır;
 * çerez yazımı (set/delete) yalnız oralarda mümkündür.
 */

const ACCESS_COOKIE = "bg_at";
const REFRESH_COOKIE = "bg_rt";

// Refresh token ömrü (backend varsayılanı 7 gün). Çerez de bu süre kadar yaşar;
// access token JWT'si içeride daha kısa sürede dolsa da 401'de refresh ile yenilenir.
const MAX_AGE = 60 * 60 * 24 * 7;

function cookieOptions() {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: MAX_AGE,
  };
}

export async function getAccessToken(): Promise<string | undefined> {
  return (await cookies()).get(ACCESS_COOKIE)?.value;
}

export async function getRefreshToken(): Promise<string | undefined> {
  return (await cookies()).get(REFRESH_COOKIE)?.value;
}

export async function setSession(accessToken: string, refreshToken: string): Promise<void> {
  const store = await cookies();
  store.set(ACCESS_COOKIE, accessToken, cookieOptions());
  store.set(REFRESH_COOKIE, refreshToken, cookieOptions());
}

export async function clearSession(): Promise<void> {
  const store = await cookies();
  store.delete(ACCESS_COOKIE);
  store.delete(REFRESH_COOKIE);
}
