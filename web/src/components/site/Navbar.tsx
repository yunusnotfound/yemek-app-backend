"use client";

import { useState } from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { Logo } from "@/components/site/Logo";
import { ButtonLink } from "@/components/ui/Button";

const NAV_LINKS = [
  { href: "/nasil-calisir", label: "Nasıl Çalışır" },
  { href: "/isletmeler-icin", label: "İşletmeler İçin" },
  { href: "/hakkimizda", label: "Hakkımızda" },
];

export function Navbar() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-40 border-b border-slate-200/80 bg-white/85 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Logo />

        <nav className="hidden items-center gap-8 md:flex">
          {NAV_LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="text-sm font-medium text-slate-600 transition-colors hover:text-brand-700"
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-3 md:flex">
          <ButtonLink href="/giris" variant="ghost" size="sm">
            Giriş Yap
          </ButtonLink>
          <ButtonLink href="/kayit" size="sm">
            İşletme Kaydı
          </ButtonLink>
        </div>

        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="inline-flex h-10 w-10 items-center justify-center rounded-lg text-slate-700 hover:bg-slate-100 md:hidden"
          aria-label="Menü"
          aria-expanded={open}
        >
          {open ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {open ? (
        <div className="border-t border-slate-200 bg-white md:hidden">
          <nav className="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-3">
            {NAV_LINKS.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-3 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-50"
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
