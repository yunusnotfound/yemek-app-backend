import "server-only";
import { redirect } from "next/navigation";
import { callBackend } from "@/lib/api/client";
import { getAccessToken } from "@/lib/auth/session";
import type { Role } from "@/lib/types";

export interface ServerUser {
  id: string;
  name: string;
  email: string;
  role: Role;
  isEmailVerified: boolean;
}

/**
 * Sunucu tarafında mevcut kullanıcıyı access-token çerezi ile çözer (server component'lerde güvenli).
 * Token yok/expire ise null döner — RSC'de çerez yazılamayacağından burada refresh DENENMEZ;
 * token yenileme client veri çağrılarında `/api/proxy` üzerinden otomatik yapılır.
 */
export async function getServerUser(): Promise<ServerUser | null> {
  const token = await getAccessToken();
  if (!token) return null;

  const res = await callBackend("/users/profile", { token });
  if (!res.ok) return null;

  try {
    const data = (await res.json()) as { user?: ServerUser };
    return data.user ?? null;
  } catch {
    return null;
  }
}

/**
 * Admin kapısı. Oturum yoksa /giris'e, admin değilse /panel'e yönlendirir (asla normal dönmez).
 * Layout/sayfa server component'lerinde çağrılır — admin olmayan kullanıcıya admin HTML'i hiç gönderilmez.
 */
export async function requireAdmin(nextPath = "/admin"): Promise<ServerUser> {
  const user = await getServerUser();
  if (!user) redirect(`/giris?next=${encodeURIComponent(nextPath)}`);
  if (user.role !== "admin") redirect("/panel");
  return user;
}
