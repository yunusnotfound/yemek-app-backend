"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ArrowUpRight, Menu, X } from "lucide-react";
import { Logo } from "@/components/site/Logo";
import { ButtonLink } from "@/components/ui/Button";
import { cn } from "@/lib/cn";

const NAV_LINKS = [
  { href: "/nasil-calisir", label: "Nasıl çalışır?" },
  { href: "/isletmeler-icin", label: "İşletmeler için" },
  { href: "/hakkimizda", label: "Biz kimiz?" },
];

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const trigger = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);
  useEffect(() => {
    if (!open) return;
    function onKeyDown(event: globalThis.KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
        trigger.current?.focus();
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open]);

  return (
    <header className="sticky top-0 z-40 border-b border-ink/10 bg-cream/95 backdrop-blur-md">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-lg focus:bg-ink focus:px-4 focus:py-3 focus:text-cream"
      >
        İçeriğe geç
      </a>
      <div className="mx-auto flex h-20 max-w-[1328px] items-center justify-between gap-6 px-6 lg:px-12">
        <Logo />
        <nav
          aria-label="Ana menü"
          className="hidden items-center gap-7 lg:flex"
        >
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={pathname === link.href ? "page" : undefined}
              className={cn(
                "text-xs font-bold transition-colors hover:text-brand-700",
                pathname === link.href ? "text-brand-700" : "text-ink/80",
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="hidden items-center gap-5 lg:flex">
          <Link
            href="/giris"
            className="text-xs font-semibold hover:text-brand-700"
          >
            İşletme girişi
          </Link>
          <ButtonLink
            href="/kayit"
            variant="secondary"
            size="sm"
            className="min-h-11 text-xs"
          >
            İşletmeni kaydet <ArrowUpRight size={16} />
          </ButtonLink>
        </div>
        <button
          ref={trigger}
          type="button"
          onClick={() => setOpen((value) => !value)}
          className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-ink/15 text-ink hover:bg-ink/5 lg:hidden"
          aria-label={open ? "Menüyü kapat" : "Menüyü aç"}
          aria-expanded={open}
          aria-controls="mobile-menu"
        >
          {open ? <X size={23} /> : <Menu size={23} />}
        </button>
      </div>
      <nav
        id="mobile-menu"
        aria-label="Mobil menü"
        hidden={!open}
        className="absolute inset-x-0 top-full max-h-[calc(100dvh-5rem)] overflow-y-auto border-b border-ink/15 bg-cream px-6 py-6 shadow-surface lg:hidden"
      >
        <div className="mx-auto flex max-w-6xl flex-col gap-2">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              onClick={() => setOpen(false)}
              aria-current={pathname === link.href ? "page" : undefined}
              className={cn(
                "rounded-lg px-3 py-3 text-sm font-semibold hover:bg-ink/5",
                pathname === link.href && "text-brand-700",
              )}
            >
              {link.label}
            </Link>
          ))}
          <Link
            href="/iptal-teslimat-iade"
            onClick={() => setOpen(false)}
            className="rounded-lg px-3 py-3 text-sm font-semibold hover:bg-ink/5"
          >
            İptal, teslimat ve iade
          </Link>
          <div className="mt-3 flex flex-wrap gap-3 border-t border-ink/10 pt-5">
            <ButtonLink
              href="/giris"
              variant="outline"
              size="sm"
              onClick={() => setOpen(false)}
            >
              İşletme girişi
            </ButtonLink>
            <ButtonLink
              href="/kayit"
              variant="secondary"
              size="sm"
              onClick={() => setOpen(false)}
            >
              İşletmeni kaydet <ArrowUpRight size={16} />
            </ButtonLink>
          </div>
        </div>
      </nav>
    </header>
  );
}
