import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowDown,
  ArrowRight,
  MapPin,
  ShoppingBag,
  Smartphone,
} from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Nasıl Çalışır",
  description:
    "Bitir Gitsin müşteriler ve işletmeler için nasıl çalışır? Sürpriz paket akışını adım adım inceleyin.",
};

const CUSTOMER_STEPS = [
  {
    icon: MapPin,
    title: "Yakınında keşfet.",
    text: "Uygulamada çevrendeki fırınları, restoranları ve marketleri bul. Paket açıklamasına, fiyatına ve teslim alma saatine göz at.",
  },
  {
    icon: Smartphone,
    title: "Paketini ayırt.",
    text: "Sana uygun sürpriz paketi seç ve ödemenle siparişini tamamla. Teslim alma kodun, siparişinle birlikte uygulamada seni beklesin.",
  },
  {
    icon: ShoppingBag,
    title: "Git, al, tadını çıkar.",
    text: "Belirtilen saat aralığında işletmeye uğra, teslim alma kodunu göster ve paketini al. İyi bir lezzete, güzel bir iyilik eşlik etsin.",
  },
];

const BUSINESS_STEPS = [
  {
    title: "İşletmeni tanıtalım.",
    text: "Hesabını oluştur, işletme bilgilerini ve konumunu ekle. Başvurun incelenip onaylandığında paketlerini satışa sunabilirsin.",
  },
  {
    title: "Fazlasını pakete dönüştür.",
    text: "Satılmamış, tüketilmeye uygun ürünlerin için paket açıklamasını, adedini, fiyatını ve teslim alma aralığını belirle.",
  },
  {
    title: "Teslim et, panelinden takip et.",
    text: "Müşteri geldiğinde kodunu doğrula ve paketini teslim et. Siparişlerini, ödemelerini ve değerlendirmelerini tek yerden takip et.",
  },
];

export default function HowItWorksPage() {
  return (
    <div className="bg-cream">
      <section className="mx-auto grid max-w-6xl items-center gap-8 px-5 py-14 sm:px-8 sm:py-20 lg:grid-cols-[1.1fr_1fr] lg:gap-14">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
            Nasıl çalışır?
          </p>
          <h1 className="mt-5 font-display text-5xl font-black uppercase leading-[0.98] tracking-tight text-ink sm:text-7xl">
            Bir paket.
            <br />
            <span className="text-brand-700">Üç kolay adım.</span>
          </h1>
          <p className="mt-7 max-w-lg text-lg leading-8 text-ink/75">
            Yakınındaki lezzetleri keşfet, uygun fiyatla paketini ayırt ve
            işletmeden teslim al. Yemeğin değerini birlikte koruyalım.
          </p>
          <ButtonLink
            href="#musteriler"
            variant="secondary"
            size="lg"
            className="mt-8"
          >
            Adımları keşfet <ArrowDown className="h-4 w-4" aria-hidden="true" />
          </ButtonLink>
        </div>
        <div className="relative isolate mx-auto w-full max-w-md">
          <div className="absolute inset-x-3 bottom-6 top-10 -z-10 rounded-[50%_50%_12%_12%] bg-brand-200" />
          <Image
            src="/images/bakery-box.webp"
            alt="İşletmeden teslim alınmaya hazır ekmek ve unlu mamullerden oluşan sürpriz paket"
            width={640}
            height={640}
            sizes="(min-width: 640px) 448px, 90vw"
            className="relative h-auto w-full"
            priority
          />
          <p className="mx-auto w-fit -rotate-3 rounded-sm bg-ink px-5 py-3 font-display text-xl font-bold uppercase text-cream">
            İyi yemek, güzel bir sürpriz.
          </p>
        </div>
      </section>

      <section
        id="musteriler"
        className="scroll-mt-28 border-t border-ink/10 bg-white/50"
      >
        <div className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-24">
          <div className="flex flex-col gap-5 md:flex-row md:items-end md:justify-between">
            <h2 className="max-w-xl font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
              Bir sonraki lezzetin
              <br />
              çok yakınında.
            </h2>
            <p className="max-w-sm leading-7 text-ink/70">
              Keşiften teslim almaya kadar siparişini Bitir Gitsin mobil
              uygulamasından yönetirsin.
            </p>
          </div>
          <ol className="mt-12 grid gap-10 md:grid-cols-3 md:gap-8">
            {CUSTOMER_STEPS.map(({ icon: Icon, title, text }, index) => (
              <li key={title} className="border-t border-ink/20 pt-5">
                <div className="flex items-center justify-between">
                  <span className="font-display text-6xl font-black text-brand-600">
                    0{index + 1}
                  </span>
                  <Icon
                    className="h-8 w-8 text-ink"
                    strokeWidth={1.4}
                    aria-hidden="true"
                  />
                </div>
                <h3 className="mt-6 font-display text-2xl font-bold uppercase text-ink">
                  {title}
                </h3>
                <p className="mt-3 leading-7 text-ink/75">{text}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="bg-ink text-cream">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-5 py-16 sm:px-8 sm:py-24 md:grid-cols-2 md:gap-16">
          <div className="overflow-hidden rounded-t-[40%] rounded-b-2xl">
            <Image
              src="/images/bakery.webp"
              alt="Sürpriz paketlerde değerlendirilebilecek fırın ürünleri"
              width={720}
              height={720}
              sizes="(min-width: 768px) 500px, 90vw"
              className="aspect-square h-auto w-full object-cover"
            />
          </div>
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-300">
              Adı üstünde: sürpriz
            </p>
            <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight sm:text-5xl">
              İçinde ne var?
            </h2>
            <p className="mt-6 text-lg leading-8 text-cream/80">
              Bir fırından yeni favorin, bir restorandan günün lezzeti. Paketin
              içeriği, işletmenin o gün elinde kalan ürünlere göre değişir.
            </p>
            <p className="mt-5 leading-7 text-cream/70">
              Seçim yapmadan önce paket açıklamasını incele. İçerik, alerjen ve
              saklama bilgileri için işletmeyle iletişime geç. Paketini
              belirtilen saatlerde işletmeden kendin teslim alırsın.
            </p>
            <Link
              href="/iptal-teslimat-iade"
              className="mt-7 inline-flex min-h-11 items-center gap-3 font-semibold text-brand-200 underline underline-offset-4 hover:text-white"
            >
              Teslimat, iptal ve iade koşulları{" "}
              <ArrowRight className="h-4 w-4 shrink-0" aria-hidden="true" />
            </Link>
          </div>
        </div>
      </section>

      <section className="bg-sand">
        <div className="mx-auto grid max-w-6xl gap-12 px-5 py-16 sm:px-8 sm:py-24 lg:grid-cols-[0.85fr_1.15fr] lg:gap-20">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
              İşletmeler için
            </p>
            <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
              Senin emeğin.
              <br />
              Yeni bir sofra.
            </h2>
            <p className="mt-6 max-w-md leading-8 text-ink/75">
              Günün sonunda kalan lezzetleri, onları bekleyen insanlarla
              buluştur. Paketlerini ve siparişlerini web panelinden yönet.
            </p>
            <ButtonLink
              href="/isletmeler-icin"
              variant="secondary"
              className="mt-8"
            >
              İşletmen için keşfet{" "}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </ButtonLink>
          </div>
          <ol>
            {BUSINESS_STEPS.map((step, index) => (
              <li
                key={step.title}
                className="flex gap-5 border-t border-ink/20 py-7 first:pt-5"
              >
                <span className="font-display text-3xl font-black text-brand-700">
                  0{index + 1}
                </span>
                <div>
                  <h3 className="font-display text-2xl font-bold uppercase text-ink">
                    {step.title}
                  </h3>
                  <p className="mt-3 leading-7 text-ink/75">{step.text}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>
    </div>
  );
}
