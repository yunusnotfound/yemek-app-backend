import Link from "next/link";
import { Logo } from "@/components/site/Logo";
import { SITE } from "@/lib/config";

const COLUMNS = [
  {
    title: "Platform",
    links: [
      { href: "/nasil-calisir", label: "Nasıl Çalışır" },
      { href: "/isletmeler-icin", label: "İşletmeler İçin" },
      { href: "/hakkimizda", label: "Hakkımızda" },
    ],
  },
  {
    title: "İşletme",
    links: [
      { href: "/kayit", label: "İşletme Kaydı" },
      { href: "/giris", label: "İşletme Girişi" },
      { href: "/panel", label: "Yönetim Paneli" },
    ],
  },
];

export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="bg-ink text-cream">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.5fr_1fr_1fr]">
        <div>
          <Logo tone="light" />
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-cream/70">
            {SITE.description}
          </p>
          <a
            href={`mailto:${SITE.email}`}
            className="mt-4 inline-block text-sm font-semibold text-brand-400 hover:text-brand-300"
          >
            {SITE.email}
          </a>
        </div>

        {COLUMNS.map((col) => (
          <div key={col.title}>
            <h3 className="font-display text-sm font-bold uppercase tracking-wide text-cream">
              {col.title}
            </h3>
            <ul className="mt-4 space-y-3">
              {col.links.map((l) => (
                <li key={l.href}>
                  <Link
                    href={l.href}
                    className="text-sm text-cream/70 transition-colors hover:text-brand-400"
                  >
                    {l.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="border-t border-white/10">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-5 text-sm text-cream/50 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <span>© {year} {SITE.name}. Tüm hakları saklıdır.</span>
          <Link href="/cerez-politikasi" className="hover:text-brand-400">
            Çerez Politikası
          </Link>
        </div>
      </div>
    </footer>
  );
}
