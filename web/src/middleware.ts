import { NextResponse, type NextRequest } from "next/server";

/**
 * Hafif yönlendirme koruması (gerçek yetki kontrolünü backend yapar):
 * - /panel/* : oturum çerezi yoksa /giris'e yönlendir.
 * - /giris,/kayit : zaten oturum varsa /panel'e yönlendir.
 */
const REFRESH_COOKIE = "bg_rt";

export function middleware(req: NextRequest) {
  if (req.nextUrl.pathname.startsWith("/api/") && !["GET", "HEAD", "OPTIONS"].includes(req.method)) {
    const origin = req.headers.get("origin");
    // Caddy preserves Host and sets X-Forwarded-Proto; Next's internal URL
    // may use the container origin. Host cannot be overridden by browser JS.
    const host = req.headers.get("host");
    const protocol = req.headers.get("x-forwarded-proto")?.split(",")[0]?.trim() || req.nextUrl.protocol.replace(":", "");
    const expected = process.env.WEB_ORIGIN || (host ? `${protocol}://${host}` : req.nextUrl.origin);
    if (origin !== expected || req.headers.get("sec-fetch-site") === "cross-site") {
      return NextResponse.json({ message: "İstek kaynağı doğrulanamadı" }, { status: 403 });
    }
  }
  const hasSession = Boolean(req.cookies.get(REFRESH_COOKIE)?.value);
  const { pathname } = req.nextUrl;

  // Oturum yoksa korumalı alanlara erişim engellenir (rol kontrolü backend + admin layout'ta).
  if ((pathname.startsWith("/panel") || pathname.startsWith("/admin")) && !hasSession) {
    const url = req.nextUrl.clone();
    url.pathname = "/giris";
    url.search = `?next=${encodeURIComponent(pathname)}`;
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/api/:path*", "/panel/:path*", "/admin/:path*", "/giris", "/kayit"],
};
