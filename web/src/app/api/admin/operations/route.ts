import { NextResponse } from "next/server";
import { callBackend } from "@/lib/api/client";
import { getAccessToken } from "@/lib/auth/session";
import { refreshSession } from "@/lib/auth/refresh";
import { getOperationsSnapshot, OperationsUnavailable } from "@/lib/operations/collector";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const json = (body: unknown, status = 200) => NextResponse.json(body, {
  status, headers: { "Cache-Control": "private, no-store", Vary: "Cookie" },
});

export async function GET() {
  let token = await getAccessToken();
  const headers = { "x-operations-probe": "1" };
  let profile = token ? await callBackend("/users/profile", { token, headers, signal: AbortSignal.timeout(5_000) }) : null;
  if (!profile || profile.status === 401) {
    token = await refreshSession() || undefined;
    if (!token) return json({ message: "Yönetici oturumu gerekli." }, 401);
    profile = await callBackend("/users/profile", { token, headers, signal: AbortSignal.timeout(5_000) });
  }
  if (!profile.ok) return json({ message: "Yönetici oturumu doğrulanamadı." }, profile.status === 401 ? 401 : 503);
  const data = await profile.json().catch(() => null);
  if (data?.user?.role !== "admin") return json({ message: "Yalnızca yöneticiler erişebilir." }, 403);
  if (!token) return json({ message: "Yönetici oturumu gerekli." }, 401);

  try {
    return json(await getOperationsSnapshot(token));
  } catch (error) {
    return json({ message: error instanceof OperationsUnavailable ? error.message : "Teknik ölçümler şu anda alınamıyor." }, 503);
  }
}
