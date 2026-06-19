import Link from "next/link";
import { SITE } from "@/lib/config";

const LINKS = [
  { href: "/nasil-calisir", label: "Nasıl Çalışır" },
  { href: "/isletmeler-icin", label: "İşletmeler İçin" },
  { href: "/hakkimizda", label: "Hakkımızda" },
  { href: "/kayit", label: "İşletme Kaydı" },
  { href: "/giris", label: "İşletme Girişi" },
  { href: "/cerez-politikasi", label: "Çerez Politikası" },
  { href: `mailto:${SITE.email}`, label: "İletişim" },
];

export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="overflow-hidden bg-ink text-cream">
      {/* Dev wordmark — genişliği dolduran büyük Korolev */}
      <div className="px-4 pt-14 sm:px-6">
        <p className="select-none text-center font-display font-black uppercase leading-none tracking-tight text-cream text-[clamp(2.5rem,14vw,13rem)]">
          Bitir Yemek
        </p>
      </div>

      {/* Linkler + telif */}
      <div className="mx-auto max-w-6xl px-4 pb-10 sm:px-6">
        <nav className="flex flex-wrap items-center justify-center gap-x-7 gap-y-3 pt-8">
          {LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="text-sm text-cream/60 transition-colors hover:text-cream"
            >
              {l.label}
            </Link>
          ))}
        </nav>
        <p className="mt-8 text-center text-sm text-cream/40">
          © {year} {SITE.name}. Tüm hakları saklıdır.
        </p>
      </div>
    </footer>
  );
}
