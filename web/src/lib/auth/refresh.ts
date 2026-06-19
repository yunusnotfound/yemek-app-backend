import "server-only";
import { callBackendJson } from "@/lib/api/client";
import { getRefreshToken, setSession, clearSession } from "@/lib/auth/session";

/**
 * Refresh token ile yeni access/refresh token alır ve çerezleri günceller.
 * Başarılıysa yeni access token'ı döndürür, başarısızsa oturumu temizleyip null döner.
 * Yalnızca route handler içinde çağrılmalı (çerez yazımı gerektirir).
 */
export async function refreshSession(): Promise<string | null> {
  const refreshToken = await getRefreshToken();
  if (!refreshToken) return null;

  const res = await callBackendJson("/auth/refresh", "POST", { refreshToken });
  if (!res.ok) {
    await clearSession();
    return null;
  }

  const data = (await res.json()) as { accessToken: string; refreshToken: string };
  await setSession(data.accessToken, data.refreshToken);
  return data.accessToken;
}
