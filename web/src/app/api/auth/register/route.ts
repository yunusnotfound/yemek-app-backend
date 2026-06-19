import { NextResponse } from "next/server";
import { callBackendJson } from "@/lib/api/client";
import { setSession } from "@/lib/auth/session";
import type { AuthResponse } from "@/lib/types";

/**
 * Web portalı işletme portalı olduğundan kayıt her zaman business_owner rolüyle yapılır.
 * Backend kayıt sonrası token döndürür (e-posta doğrulaması beklenir) — oturumu kurar,
 * panelde "e-postanı doğrula" uyarısı gösterilir.
 */
export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));

  const res = await callBackendJson("/auth/register", "POST", {
    name: body.name,
    email: body.email,
    password: body.password,
    phone: body.phone || undefined,
    role: "business_owner",
  });
  const data = await res.json().catch(() => null);

  if (!res.ok) {
    return NextResponse.json(data ?? { message: "Kayıt başarısız" }, {
      status: res.status,
    });
  }

  const auth = data as AuthResponse;
  await setSession(auth.accessToken, auth.refreshToken);
  return NextResponse.json({ user: auth.user, message: auth.message });
}
