import Link from "next/link";
import { ArrowUpRight, Leaf } from "lucide-react";
import { PaymentMethods } from "@/components/site/PaymentMethods";
import { SITE } from "@/lib/config";

const EXPLORE = [
  { href: "/nasil-calisir", label: "Nasıl çalışır?" },
  { href: "/isletmeler-icin", label: "İşletmeler için" },
  { href: "/hakkimizda", label: "Hakkımızda" },
  { href: "/kayit", label: "İşletme kaydı" },
  { href: "/giris", label: "İşletme girişi" },
];
const SUPPORT = [
  { href: "/iptal-teslimat-iade#iptal", label: "İptal koşulları" },
  { href: "/iptal-teslimat-iade#teslimat", label: "Teslimat koşulları" },
  { href: "/iptal-teslimat-iade#iade", label: "İade koşulları" },
  { href: "/cerez-politikasi", label: "Çerez politikası" },
  { href: `mailto:${SITE.email}`, label: "İletişim" },
];

export function Footer() {
  return (
    <footer className="overflow-hidden bg-ink text-cream">
      <div className="mx-auto max-w-[1240px] px-6 pt-16 sm:px-10 sm:pt-20">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.7fr_1fr_1fr]">
          <div>
            <span className="mb-5 inline-flex h-11 w-11 items-center justify-center rounded-full bg-brand-500 text-ink">
              <Leaf size={25} strokeWidth={1.5} />
            </span>
            <h2 className="font-display text-4xl font-bold uppercase leading-none sm:text-5xl">
              BİRLİKTE DAHA
              <br />
              <span className="text-brand-400">AZ İSRAF.</span>
            </h2>
            <p className="mt-5 max-w-xs text-xs leading-7 text-cream/70">
              Her sürpriz paket, güzel bir başlangıç.
              <br />
              Sen de bu değişimin bir parçası ol.
            </p>
            <Link
              href={`mailto:${SITE.email}`}
              className="mt-5 inline-flex items-center gap-2 text-xs font-semibold text-cream underline decoration-cream/40 underline-offset-4"
            >
              {SITE.email} <ArrowUpRight size={14} />
            </Link>
          </div>
          {[
            { title: "KEŞFET", links: EXPLORE },
            { title: "YARDIM & KOŞULLAR", links: SUPPORT },
          ].map((group) => (
            <nav key={group.title} aria-label={group.title}>
              <p className="mb-5 text-[10px] font-bold tracking-[.18em] text-brand-300">
                {group.title}
              </p>
              <ul className="space-y-3.5">
                {group.links.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="text-xs text-cream/75 transition-colors hover:text-white hover:underline hover:underline-offset-4"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>
        <p
          aria-hidden="true"
          className="mt-12 select-none whitespace-nowrap text-center font-display text-[clamp(3rem,14.4vw,11rem)] font-black uppercase leading-[1.2] tracking-[-.035em] text-cream"
        >
          BİTİR GİTSİN<span className="text-brand-500">.</span>
        </p>
        <div className="flex flex-col items-start justify-between gap-6 border-t border-cream/15 py-7 sm:flex-row sm:items-center">
          <p className="text-[10px] leading-6 text-cream/65">
            © {new Date().getFullYear()} {SITE.name}. Tüm hakları saklıdır.
            <br />
            İsrafı azalt, lezzeti kurtar.
          </p>
          <PaymentMethods compact />
        </div>
      </div>
    </footer>
  );
}
