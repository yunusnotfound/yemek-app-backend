import type { Metadata } from "next";
import { Leaf, HeartHandshake, Sparkles } from "lucide-react";
import { SITE } from "@/lib/config";

export const metadata: Metadata = {
  title: "Hakkımızda",
  description:
    "Bitir Gitsin'in misyonu: gıda israfını azaltmak, işletmelere değer katmak ve herkese uygun fiyatlı lezzet sunmak.",
};

const VALUES = [
  {
    icon: Leaf,
    title: "Sürdürülebilirlik",
    text: "Her kurtarılan paket, çöpe gitmeyen gıda ve azalan karbon ayak izi demek.",
  },
  {
    icon: HeartHandshake,
    title: "Kazan-kazan",
    text: "İşletme gelirini artırır, müşteri uygun fiyata lezzete ulaşır, gezegen nefes alır.",
  },
  {
    icon: Sparkles,
    title: "Sadelik",
    text: "Hem müşteri hem işletme için zahmetsiz, anlaşılır bir deneyim tasarlıyoruz.",
  },
];

export default function AboutPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
      <header>
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-900">
          Hakkımızda
        </h1>
        <p className="mt-5 text-lg leading-relaxed text-slate-600">
          {SITE.name}, üretilen gıdanın önemli bir kısmının israf olduğu
          gerçeğinden yola çıktı. Amacımız basit: restoran, fırın ve marketlerin
          gün sonunda kalan kaliteli ürünlerini, atılmadan önce uygun fiyatlı
          sürpriz paketlerle müşterilerle buluşturmak.
        </p>
      </header>

      <div className="mt-10 space-y-5 text-slate-700">
        <p>
          Bir işletme için satılmayan ürün doğrudan kayıptır; bir tüketici için
          ise her gün karşılaşılan bir bütçe kalemi. Bitir Gitsin bu iki ihtiyacı
          tek bir basit fikirde birleştirir:{" "}
          <strong>kaybı, paylaşılan bir kazanca çevirmek.</strong>
        </p>
        <p>
          Mobil uygulamamız müşterileri yakınlarındaki fırsatlarla buluştururken,
          web panelimiz işletmelerin paketlerini, siparişlerini ve
          değerlendirmelerini kolayca yönetmesini sağlar. Böylece israfı
          azaltırken yerel işletmeleri de destekliyoruz.
        </p>
      </div>

      <div className="mt-12 grid gap-6 sm:grid-cols-3">
        {VALUES.map((v) => (
          <div
            key={v.title}
            className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
          >
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-brand-100 text-brand-700">
              <v.icon className="h-5 w-5" />
            </span>
            <h3 className="mt-4 font-bold text-slate-900">{v.title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-slate-600">
              {v.text}
            </p>
          </div>
        ))}
      </div>

      <div className="mt-12 rounded-2xl bg-slate-900 p-8 text-center">
        <p className="text-lg font-semibold text-white">
          Sorularınız mı var? Bize ulaşın.
        </p>
        <a
          href={`mailto:${SITE.email}`}
          className="mt-2 inline-block font-medium text-brand-300 hover:underline"
        >
          {SITE.email}
        </a>
      </div>
    </div>
  );
}
