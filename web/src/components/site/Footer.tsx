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
    <footer className="border-t border-slate-200 bg-slate-50">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 md:grid-cols-[1.5fr_1fr_1fr]">
        <div>
          <Logo />
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-slate-600">
            {SITE.description}
          </p>
          <a
            href={`mailto:${SITE.email}`}
            className="mt-4 inline-block text-sm font-medium text-brand-700 hover:underline"
          >
            {SITE.email}
          </a>
        </div>

        {COLUMNS.map((col) => (
          <div key={col.title}>
            <h3 className="text-sm font-semibold text-slate-900">{col.title}</h3>
            <ul className="mt-4 space-y-3">
              {col.links.map((l) => (
                <li key={l.href}>
                  <Link
                    href={l.href}
                    className="text-sm text-slate-600 transition-colors hover:text-brand-700"
                  >
                    {l.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="border-t border-slate-200">
        <div className="mx-auto max-w-6xl px-4 py-5 text-sm text-slate-500 sm:px-6">
          © {year} {SITE.name}. Tüm hakları saklıdır.
        </div>
      </div>
    </footer>
  );
}
