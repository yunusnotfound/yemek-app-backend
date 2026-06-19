import { NextResponse } from "next/server";
import { callBackend } from "@/lib/api/client";
import { getAccessToken } from "@/lib/auth/session";
import { refreshSession } from "@/lib/auth/refresh";

/**
 * Kimlik doğrulamalı genel passthrough (BFF).
 * Tarayıcı /api/proxy/<backend-yolu> çağırır; bu handler httpOnly çerezdeki access
 * token'ı ekleyip backend'e iletir. 401 alırsa refresh token ile yeniler ve bir kez
 * tekrar dener. Yetki kontrolünü backend (authorize) yapar.
 *
 * Not: backend rate limiter IP bazlı olduğundan tüm web trafiği web konteynerinin
 * IP'siyle tek kovaya düşer — v1 için yeterli (business-dashboard limiti 200/15dk).
 */
export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ path: string[] }> };

async function handle(req: Request, ctx: Ctx): Promise<NextResponse> {
  const { path } = await ctx.params;
  const search = new URL(req.url).search;
  const target = "/" + path.join("/") + search;

  const method = req.method.toUpperCase();
  const hasBody = method !== "GET" && method !== "HEAD";
  const bodyBuf = hasBody ? await req.arrayBuffer() : undefined;

  const headers: Record<string, string> = {};
  const contentType = req.headers.get("content-type");
  if (contentType) headers["content-type"] = contentType;

  const send = (token?: string) =>
    callBackend(target, { method, token, headers, body: hasBody ? bodyBuf : undefined });

  let res = await send(await getAccessToken());

  if (res.status === 401) {
    const newToken = await refreshSession();
    if (!newToken) {
      return NextResponse.json({ message: "Oturum süresi doldu" }, { status: 401 });
    }
    res = await send(newToken);
  }

  const resBody = await res.arrayBuffer();
  const out = new NextResponse(resBody, { status: res.status });
  const resContentType = res.headers.get("content-type");
  if (resContentType) out.headers.set("content-type", resContentType);
  return out;
}

export const GET = handle;
export const POST = handle;
export const PUT = handle;
export const PATCH = handle;
export const DELETE = handle;
