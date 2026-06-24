"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Store,
  Package,
  ShoppingBag,
  Star,
  Wallet,
  LogOut,
  Menu,
  MailWarning,
} from "lucide-react";
import { Logo } from "@/components/site/Logo";
import { Badge } from "@/components/ui/Badge";
import { useBusiness } from "@/components/panel/BusinessProvider";
import { getProfile } from "@/lib/api/panel";
import { apiFetch } from "@/lib/api/browser";
import { cn } from "@/lib/cn";

const NAV = [
  { href: "/panel", label: "Genel Bakış", icon: LayoutDashboard, exact: true },
  { href: "/panel/isletme", label: "İşletmem", icon: Store },
  { href: "/panel/paketler", label: "Paketler", icon: Package },
  { href: "/panel/siparisler", label: "Siparişler", icon: ShoppingBag },
  { href: "/panel/odemeler", label: "Ödemeler", icon: Wallet },
  { href: "/panel/degerlendirmeler", label: "Değerlendirmeler", icon: Star },
];

function isActive(pathname: string, href: string, exact?: boolean) {
  return exact ? pathname === href : pathname.startsWith(href);
}

export function PanelShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { businesses, active, setActiveId } = useBusiness();
  const [open, setOpen] = useState(false);
  const [unverified, setUnverified] = useState(false);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  useEffect(() => {
    getProfile()
      .then((res) => setUnverified(!res.user.isEmailVerified))
      .catch(() => {});
  }, []);

  async function logout() {
    await apiFetch("/api/auth/logout", { method: "POST" }).catch(() => {});
    window.location.assign("/giris");
  }

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="flex h-16 items-center px-5">
        <Logo href="/panel" />
      </div>
      <nav className="flex-1 space-y-1 px-3 py-4">
        {NAV.map((item) => {
          const activeLink = isActive(pathname, item.href, item.exact);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors",
                activeLink
                  ? "bg-brand-50 text-brand-700"
                  : "text-slate-600 hover:bg-slate-100 hover:text-slate-900",
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="px-3 pb-4">
        <button
          type="button"
          onClick={logout}
          className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-slate-600 transition-colors hover:bg-red-50 hover:text-red-700"
        >
          <LogOut className="h-5 w-5" /> Çıkış yap
        </button>
      </div>
    </div>
  );

  return (
    <div className="min-h-dvh bg-slate-50">
      {/* Masaüstü sidebar */}
      <aside className="fixed inset-y-0 left-0 hidden w-64 border-r border-slate-200 bg-white lg:block">
        {sidebar}
      </aside>

      {/* Mobil drawer */}
      {open ? (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div
            className="absolute inset-0 bg-slate-900/40"
            onClick={() => setOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-64 bg-white shadow-xl">
            {sidebar}
          </aside>
        </div>
      ) : null}

      <div className="lg:pl-64">
        {/* Topbar */}
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-slate-200 bg-white/90 px-4 backdrop-blur sm:px-6">
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="inline-flex h-10 w-10 items-center justify-center rounded-lg text-slate-700 hover:bg-slate-100 lg:hidden"
            aria-label="Menü"
          >
            <Menu className="h-6 w-6" />
          </button>

          <div className="flex min-w-0 flex-1 items-center gap-3">
            {businesses.length > 1 ? (
              <select
                value={active?.id ?? ""}
                onChange={(e) => setActiveId(e.target.value)}
                className="max-w-[14rem] truncate rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-800"
              >
                {businesses.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            ) : active ? (
              <span className="truncate text-sm font-semibold text-slate-900">
                {active.name}
              </span>
            ) : null}

            {active ? (
              active.isApproved ? (
                <Badge tone="green">Onaylı</Badge>
              ) : (
                <Badge tone="amber">Onay bekliyor</Badge>
              )
            ) : null}
          </div>

          <button
            type="button"
            onClick={logout}
            className="hidden items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 sm:inline-flex lg:hidden"
          >
            <LogOut className="h-4 w-4" /> Çıkış
          </button>
        </header>

        {unverified ? (
          <div className="flex items-center gap-2 border-b border-amber-200 bg-amber-50 px-4 py-2.5 text-sm text-amber-900 sm:px-6">
            <MailWarning className="h-4 w-4 shrink-0" />
            E-posta adresin doğrulanmamış. Gönderdiğimiz doğrulama bağlantısına
            tıklayarak hesabını doğrula.
          </div>
        ) : null}

        <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 sm:py-8">
          {children}
        </main>
      </div>
    </div>
  );
}
