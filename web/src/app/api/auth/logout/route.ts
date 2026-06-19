import { NextResponse } from "next/server";
import { callBackendJson } from "@/lib/api/client";
import { getRefreshToken, clearSession } from "@/lib/auth/session";

export async function POST() {
  const refreshToken = await getRefreshToken();
  if (refreshToken) {
    // Backend tarafında refresh token'ı geçersiz kıl (hata olsa da oturumu temizleriz).
    await callBackendJson("/auth/logout", "POST", { refreshToken }).catch(() => {});
  }
  await clearSession();
  return NextResponse.json({ ok: true });
}
