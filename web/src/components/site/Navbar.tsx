"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import { Logo } from "@/components/site/Logo";
import { ButtonLink } from "@/components/ui/Button";
import { cn } from "@/lib/cn";

const NAV_LINKS = [
  { href: "/nasil-calisir", label: "Nasıl Çalışır" },
  { href: "/isletmeler-icin", label: "İşletmeler İçin" },
  { href: "/hakkimizda", label: "Hakkımızda" },
];

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  // Şeffaf yalnızca ana sayfanın en üstünde (koyu hero üzerinde); menü açıkken
  // veya kaydırınca ya da diğer sayfalarda katı krem.
  const isHome = pathname === "/";
  const transparent = isHome && !scrolled && !open;

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  return (
    <header
      className={cn(
        "sticky top-0 z-50 transition-colors duration-300",
        transparent
          ? "bg-transparent"
          : "border-b border-ink/10 bg-cream/90 backdrop-blur",
      )}
    >
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Logo tone={transparent ? "light" : "dark"} />

        <nav className="hidden items-center gap-8 md:flex">
          {NAV_LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={cn(
                "text-sm font-semibold transition-colors",
                transparent
                  ? "text-white/90 hover:text-white"
                  : "text-ink/70 hover:text-brand-700",
              )}
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-2 md:flex">
          <ButtonLink
            href="/giris"
            variant="ghost"
            size="sm"
            className={transparent ? "!text-white hover:!bg-white/10" : ""}
          >
            Giriş Yap
          </ButtonLink>
          <ButtonLink href="/kayit" size="sm">
            İşletme Kaydı
          </ButtonLink>
        </div>

        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className={cn(
            "inline-flex h-10 w-10 items-center justify-center rounded-lg md:hidden",
            transparent ? "text-white hover:bg-white/10" : "text-ink hover:bg-ink/5",
          )}
          aria-label="Menü"
          aria-expanded={open}
        >
          {open ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {open ? (
        <div className="border-t border-ink/10 bg-cream md:hidden">
          <nav className="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-3">
            {NAV_LINKS.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-3 py-2.5 text-sm font-semibold text-ink/80 hover:bg-ink/5"
              >
                {l.label}
              </Link>
            ))}
            <div className="mt-2 grid grid-cols-2 gap-2">
              <ButtonLink href="/giris" variant="outline" size="sm" onClick={() => setOpen(false)}>
                Giriş Yap
              </ButtonLink>
              <ButtonLink href="/kayit" size="sm" onClick={() => setOpen(false)}>
                İşletme Kaydı
              </ButtonLink>
            </div>
          </nav>
        </div>
      ) : null}
    </header>
  );
}
