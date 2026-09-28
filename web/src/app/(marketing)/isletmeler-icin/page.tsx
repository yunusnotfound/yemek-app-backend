import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  ChartNoAxesCombined,
  HeartHandshake,
  Plus,
  Sprout,
} from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";
import { SITE } from "@/lib/config";

export const metadata: Metadata = {
  title: "İşletmeler İçin",
  description:
    "Bitir Gitsin ile fazla ürünlerini sürpriz paketlere dönüştür, yeni müşterilerle buluş. Paket ve siparişlerini işletme panelinden yönet.",
};

const BENEFITS = [
  {
    icon: ChartNoAxesCombined,
    title: "Fazlanı değerlendir.",
    text: "Tüketilmeye uygun, satılmamış ürünlerini indirimli paketlerle sun. Verdiğin emeğin değerini korumak için yeni bir satış kanalı oluştur.",
  },
  {
    icon: HeartHandshake,
    title: "Komşularınla tanış.",
    text: "Yakınındaki yeni müşterilerin işletmeni keşfetmesini sağla. Bir sürpriz paket, lezzetlerini tanıtmak için güzel bir başlangıç olsun.",
  },
  {
    icon: Sprout,
    title: "İsrafı birlikte azalt.",
    text: "İyi gıdanın çöpe gitmesini önlemeye katkıda bulun. Daha sorumlu bir gıda düzeninin yerel bir parçası ol.",
  },
];

const FAQ = [
  {
    question: "Hangi işletmeler katılabilir?",
    answer:
      "Tüketilmeye uygun fazla gıdalarını değerlendirmek isteyen restoranlar, kafeler, fırınlar, pastaneler ve marketler başvurabilir. İşletme bilgileri incelendikten sonra başvurunun durumu panelde görüntülenir.",
  },
  {
    question: "İşletmem ne zaman yayına girer?",
    answer:
      "Hesabını oluşturup işletme bilgilerini tamamladıktan sonra başvurun değerlendirilir. İşletmen onaylandığında paketlerini satışa sunabilirsin. Onay süreci tamamlanmadan müşterilere açık satış başlamaz.",
  },
  {
    question: "Ücretlendirme nasıl çalışır?",
    answer:
      "Hizmet bedelleri, ödeme ve iş birliği koşulları hakkında bilgi almak için bizimle iletişime geçebilirsin. İşletmene uygulanacak koşullar ilgili sözleşme kapsamında belirlenir.",
  },
  {
    question: "Paketin içine hangi ürünleri koyabilirim?",
    answer:
      "Gıda güvenliği koşullarına uygun, tüketilebilir ve paket açıklamasıyla uyumlu ürünlerini sunabilirsin. Paket adedini, fiyatını ve teslim alma aralığını sen belirlersin. İçerik ve alerjen bilgilerini müşterilerle açık biçimde paylaşmalısın.",
  },
  {
    question: "Siparişleri nasıl teslim ederim?",
    answer:
      "Müşteri, belirlediğin saat aralığında işletmene gelir. Paketi teslim ederken müşterinin uygulamadaki teslim alma kodunu panelden doğrularsın. Teslim edilen siparişleri ve ilgili ödeme durumlarını panelinden takip edebilirsin.",
  },
];

export default function ForBusinessesPage() {
  return (
    <div className="bg-cream">
      <section className="overflow-hidden bg-ink text-cream">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-5 py-14 sm:px-8 sm:py-20 lg:grid-cols-[1.05fr_1fr] lg:gap-14">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-300">
              Bitir Gitsin × Senin işletmen
            </p>
            <h1 className="mt-5 font-display text-5xl font-black uppercase leading-[0.98] tracking-tight sm:text-7xl">
              Günün sonunda
              <br />
              <span className="text-brand-400">
                yeni bir
                <br />
                başlangıç.
              </span>
            </h1>
            <p className="mt-7 max-w-lg text-lg leading-8 text-cream/80">
              Tezgahta kalan lezzetler, bir sonraki sofrada yerini bulsun. Fazla
              ürünlerini sürpriz paketlere dönüştür, yeni müşterilerle buluş.
            </p>
            <ButtonLink href="/kayit" variant="light" size="lg" className="mt-8">
              İşletmeni kaydet{" "}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </ButtonLink>
          </div>
          <div className="relative mx-auto w-full max-w-lg pb-4">
            <Image
              src="/images/restaurant.webp"
              alt="İşletmelerin sürpriz paketlerinde değerlendirebileceği hazırlanmış yemekler"
              width={720}
              height={720}
              sizes="(min-width: 1024px) 500px, 90vw"
              className="aspect-square h-auto w-full rounded-t-[45%] rounded-b-2xl object-cover"
              priority
            />
            <p className="absolute -bottom-2 left-4 -rotate-3 bg-brand-500 px-5 py-3 font-display text-xl font-bold uppercase text-ink sm:left-8 sm:text-2xl">
              Lezzete değer. Emeğine değer.
            </p>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-5 py-16 sm:px-8 sm:py-24">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
          Birlikte mümkün
        </p>
        <h2 className="mt-5 max-w-3xl font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
          İşletmen için iyi.
          <br />
          Gelecek için de.
        </h2>
        <div className="mt-12 grid gap-10 md:grid-cols-3 md:gap-8">
          {BENEFITS.map(({ icon: Icon, title, text }) => (
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

      <section className="bg-sand">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-5 py-16 sm:px-8 sm:py-24 md:grid-cols-2 md:gap-16">
          <div className="grid grid-cols-2 items-center gap-4">
            <Image
              src="/images/bakery.webp"
              alt="Fırın ve pastaneler için unlu mamuller"
              width={720}
              height={720}
              sizes="(min-width: 768px) 250px, 43vw"
              className="aspect-[4/5] h-auto w-full rounded-t-full object-cover"
            />
            <Image
              src="/images/produce.webp"
              alt="Manav ve marketler için meyve ve sebzeler"
              width={720}
              height={720}
              sizes="(min-width: 768px) 250px, 43vw"
              className="mt-16 aspect-[4/5] h-auto w-full rounded-b-full object-cover"
            />
          </div>
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
              Fırın, restoran, kafe, market
            </p>
            <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
              Sen işine bak.
              <br />
              Fazlasını buluşturalım.
            </h2>
            <p className="mt-6 text-lg leading-8 text-ink/75">
              Bir tepsi börek, birkaç somun ekmek ya da günün yemeği. İşletmenin
              ritmine uygun paketler oluştur; içeriği, adedi ve teslim alma
              saatini sen belirle.
            </p>
            <p className="mt-5 leading-7 text-ink/70">
              Paketlerin, siparişlerin, ödemelerin ve müşteri değerlendirmelerin
              tek panelde. Müşterin geldiğinde teslim alma kodunu doğrula,
              hazırladığın paketi teslim et.
            </p>
            <Link
              href="/nasil-calisir"
              className="mt-6 inline-flex min-h-11 items-center gap-3 font-bold text-brand-700 underline underline-offset-4 hover:text-brand-900"
            >
              Süreci adım adım incele{" "}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </Link>
          </div>
        </div>
      </section>

      <section className="mx-auto grid max-w-6xl gap-10 px-5 py-16 sm:px-8 sm:py-24 lg:grid-cols-[0.7fr_1.3fr] lg:gap-20">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
            Aklındaki sorular
          </p>
          <h2 className="mt-5 font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
            Başlamadan
            <br />
            önce.
          </h2>
          <p className="mt-6 leading-7 text-ink/70">İşletmen için konuşalım.</p>
          <a
            href={`mailto:${SITE.email}`}
            className="mt-2 inline-block break-all font-semibold text-brand-700 underline underline-offset-4 hover:text-brand-900"
          >
            {SITE.email}
          </a>
        </div>
        <div>
          {FAQ.map((item) => (
            <details
              key={item.question}
              className="group border-t border-ink/20 last:border-b"
            >
              <summary className="flex min-h-20 cursor-pointer list-none items-center justify-between gap-5 py-6 text-lg font-semibold text-ink focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand-700 [&::-webkit-details-marker]:hidden">
                {item.question}
                <Plus
                  className="h-5 w-5 shrink-0 text-brand-700 transition-transform group-open:rotate-45 motion-reduce:transition-none"
                  aria-hidden="true"
                />
              </summary>
              <p className="max-w-xl pb-7 pr-5 leading-7 text-ink/75">
                {item.answer}
              </p>
            </details>
          ))}
          <Link
            href="/iptal-teslimat-iade"
            className="mt-7 inline-block min-h-11 text-sm font-semibold text-brand-700 underline underline-offset-4 hover:text-brand-900"
          >
            Sipariş iptal, teslimat ve iade koşullarını incele
          </Link>
        </div>
      </section>

      <section className="bg-brand-500">
        <div className="mx-auto flex max-w-6xl flex-col gap-8 px-5 py-14 sm:px-8 sm:py-16 md:flex-row md:items-center md:justify-between">
          <h2 className="max-w-2xl font-display text-4xl font-black uppercase leading-none tracking-tight text-ink sm:text-5xl">
            Güzel bir değişim,
            <br />
            senin tezgâhında başlasın.
          </h2>
          <ButtonLink
            href="/kayit"
            variant="secondary"
            size="lg"
            className="self-start md:shrink-0 md:self-auto"
          >
            Aramıza katıl <ArrowRight className="h-4 w-4" aria-hidden="true" />
          </ButtonLink>
        </div>
      </section>
    </div>
  );
}
