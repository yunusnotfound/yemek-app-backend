import type { Metadata } from "next";
import Image from "next/image";
import { ArrowRight, HeartHandshake, Leaf, Sparkles } from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";
import { SITE } from "@/lib/config";

export const metadata: Metadata = {
  title: "Hakkımızda",
  description:
    "Bitir Gitsin'in misyonu: gıda israfını azaltmak, işletmelere değer katmak ve herkese uygun fiyatlı lezzet sunmak.",
};

const VALUES = [
  {
    icon: Leaf,
    title: "Gıdaya saygı.",
    text: "Her yemeğin arkasında emek, zaman ve kaynak var. Tüketilmeye uygun gıdanın değerini korumayı günlük bir alışkanlığa dönüştürmek istiyoruz.",
  },
  {
    icon: HeartHandshake,
    title: "Yerelden güç al.",
    text: "Mahallenin fırını, köşedeki kafe, her gün önünden geçtiğin restoran. İşletmelerin emeğini, yakınlarındaki insanların sofralarıyla buluşturuyoruz.",
  },
  {
    icon: Sparkles,
    title: "Küçükten başla.",
    text: "İyi bir seçim karmaşık olmak zorunda değil. Keşfetmek, ayırtmak ve teslim almak kadar sade bir deneyimle herkesin katılabileceği bir değişime inanıyoruz.",
  },
];

export default function AboutPage() {
  return (
    <div className="bg-cream">
      <section className="mx-auto grid max-w-6xl items-center gap-10 px-5 py-14 sm:px-8 sm:py-20 lg:grid-cols-[1.1fr_1fr] lg:gap-14">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
            Hakkımızda
          </p>
          <h1 className="mt-5 font-display text-5xl font-black uppercase leading-[0.98] tracking-tight text-ink sm:text-7xl">
            İyi yemeğin
            <br />
            yeri{" "}
            <span className="text-brand-700">
              çöplük
              <br />
              değil.
            </span>
          </h1>
          <p className="mt-7 max-w-lg text-lg leading-8 text-ink/75">
            Bir somun ekmeğin, özenle pişen bir yemeğin, dalından toplanan bir
            meyvenin hikâyesi çöpte bitmesin. Bitir Gitsin bunun için var.
          </p>
        </div>
        <div className="relative isolate mx-auto w-full max-w-md">
          <div className="absolute inset-5 -z-10 rounded-full bg-brand-200" />
          <Image
            src="/images/rescue-bag.webp"
            alt="İsraf edilmeden değerlendirilmek üzere bir araya getirilen lezzetlerden oluşan Bitir Gitsin paketi"
            width={660}
            height={660}
            sizes="(min-width: 640px) 448px, 90vw"
            className="h-auto w-full"
            priority
          />
        </div>
      </section>

      <section className="bg-sand">
        <div className="mx-auto grid max-w-6xl gap-8 px-5 py-16 sm:px-8 sm:py-24 md:grid-cols-[0.8fr_1.2fr] md:gap-20">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
              Bizim fikrimiz
            </p>
            <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
              Fazla olan,
              <br />
              boşa gitmesin.
            </h2>
          </div>
          <div className="space-y-6 text-lg leading-8 text-ink/75">
            <p>
              Gün biterken bir fırının tezgâhında hâlâ güzel lezzetler
              kalabilir. Aynı mahallede birileri de uygun fiyatlı, iyi bir yemek
              arıyor olabilir. Biz bu iki hikâyeyi bir araya getiriyoruz.
            </p>
            <p>
              {SITE.name}, restoranların, fırınların, kafelerin ve marketlerin
              tüketilmeye uygun fazla ürünlerini sürpriz paketlerle sunmasına
              yardımcı olur. İşletmeler ürünlerini değerlendirir; sen
              yakınındaki lezzetleri daha uygun fiyatla keşfedersin.
            </p>
            <p>
              Amacımız, gıda israfını azaltmayı günlük hayatın doğal bir parçası
              hâline getirmek. Birlikte atabileceğimiz küçük bir adımla
              başlıyoruz:{" "}
              <strong className="font-semibold text-ink">
                bir paketi daha sofraya ulaştırmak.
              </strong>
            </p>
          </div>
        </div>
      </section>

      <section className="bg-ink text-cream">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-5 py-16 sm:px-8 sm:py-24 md:grid-cols-2 md:gap-16">
          <Image
            src="/images/surprise-bag.webp"
            alt="Gün sonunda değerlendirilen farklı lezzetlerden oluşan bir sürpriz paket"
            width={1536}
            height={1024}
            sizes="(min-width: 768px) 520px, 90vw"
            className="aspect-[5/4] h-auto w-full rounded-2xl object-cover"
          />
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-300">
              Her pakette bir ihtimal
            </p>
            <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight sm:text-5xl">
              Daha az israf.
              <br />
              <span className="text-brand-400">Daha çok paylaşım.</span>
            </h2>
            <p className="mt-6 text-lg leading-8 text-cream/80">
              Sürpriz olan paketin içeriği. Paylaştığımız niyet ise belli:
              lezzeti değerlendirmek, emeği korumak ve yerel işletmelerin
              yanında olmak.
            </p>
            <ButtonLink
              href="/nasil-calisir"
              variant="outlineLight"
              className="mt-8"
            >
              Nasıl çalıştığını keşfet{" "}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </ButtonLink>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-24">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
          Bize yön verenler
        </p>
        <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
          Soframızda bunlar var.
        </h2>
        <div className="mt-12 grid gap-10 md:grid-cols-3 md:gap-8">
          {VALUES.map(({ icon: Icon, title, text }) => (
            <div key={title} className="border-t border-ink/20 pt-6">
              <Icon
                className="h-9 w-9 text-brand-700"
                strokeWidth={1.5}
                aria-hidden="true"
              />
              <h3 className="mt-6 font-display text-2xl font-bold uppercase text-ink">
                {title}
              </h3>
              <p className="mt-3 leading-7 text-ink/75">{text}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="bg-brand-500">
        <div className="mx-auto max-w-6xl px-5 py-16 text-center sm:px-8 sm:py-20">
          <h2 className="font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-6xl">
            Bu hikâyede
            <br />
            senin de yerin var.
          </h2>
          <p className="mx-auto mt-6 max-w-xl text-lg leading-8 text-ink/80">
            İster yeni lezzetler keşfet, ister işletmenin fazlasını değerlendir.
            Müşteri siparişleri mobil uygulamadan, işletme yönetimi web
            panelinden gerçekleşir.
          </p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <ButtonLink href="/nasil-calisir" variant="secondary" size="lg">
              Nasıl çalışır?{" "}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </ButtonLink>
            <ButtonLink
              href="/isletmeler-icin"
              variant="outline"
              size="lg"
              className="border-ink/40"
            >
              İşletmeler için
            </ButtonLink>
          </div>
          <p className="mt-8 text-sm text-ink/80">
            Bize yaz:{" "}
            <a
              href={`mailto:${SITE.email}`}
              className="font-semibold text-ink underline underline-offset-4 hover:text-white"
            >
              {SITE.email}
            </a>
          </p>
        </div>
      </section>
    </div>
  );
}
