import { NextResponse, type NextRequest } from "next/server";

/**
 * Hafif yönlendirme koruması (gerçek yetki kontrolünü backend yapar):
 * - /panel/* : oturum çerezi yoksa /giris'e yönlendir.
 * - /giris,/kayit : zaten oturum varsa /panel'e yönlendir.
 */
const REFRESH_COOKIE = "bg_rt";

export function middleware(req: NextRequest) {
  const hasSession = Boolean(req.cookies.get(REFRESH_COOKIE)?.value);
  const { pathname } = req.nextUrl;

  // Oturum yoksa korumalı alanlara erişim engellenir (rol kontrolü backend + admin layout'ta).
  if ((pathname.startsWith("/panel") || pathname.startsWith("/admin")) && !hasSession) {
    const url = req.nextUrl.clone();
    url.pathname = "/giris";
    url.search = `?next=${encodeURIComponent(pathname)}`;
    return NextResponse.redirect(url);
  }

  if (hasSession && (pathname === "/giris" || pathname === "/kayit")) {
    const url = req.nextUrl.clone();
    url.pathname = "/panel";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/panel/:path*", "/admin/:path*", "/giris", "/kayit"],
};
