import type { Metadata } from "next";
import { Check, ArrowRight } from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "İşletmeler İçin",
  description:
    "Bitir Yemek ile satılmayan ürünlerini gelire çevir. Ücretsiz kurulum, kolay panel, gerçek zamanlı sipariş yönetimi.",
};

const REASONS = [
  "Kurulum ve aylık sabit ücret yok — sadece sattıkça değerlendir.",
  "Çöpe giden ürünleri indirimli paketlerle gelire dönüştür.",
  "Bölgendeki yeni müşterilerle tanış, marka bilinirliğini artır.",
  "Web panelinden paket, sipariş ve değerlendirmeleri tek yerden yönet.",
  "Teslim alma kodu ile hızlı ve hatasız teslimat.",
  "Gıda israfını azaltarak sürdürülebilirlik hedeflerine katkı sun.",
];

const FAQ = [
  {
    q: "Kaydolmak ücretli mi?",
    a: "Hayır. İşletme kaydı ve panel kullanımı ücretsizdir; kurulum veya aylık sabit ücret alınmaz.",
  },
  {
    q: "İşletmem ne zaman yayına girer?",
    a: "Kayıt sonrası işletmen yönetici onayına düşer. Onaylandıktan sonra paketlerin müşterilere görünür olur.",
  },
  {
    q: "Paketlerin içinde ne olmalı?",
    a: "Gün sonunda kalan, kalitesi yerinde ancak satılamayacak ürünlerden oluşan sürpriz bir set. İçeriği sen belirlersin.",
  },
  {
    q: "Siparişleri nasıl teslim ederim?",
    a: "Müşteri belirlenen saat aralığında gelir ve teslim alma kodunu gösterir. Kodu panelden doğrularsın, sipariş kapanır.",
  },
];

export default function ForBusinessesPage() {
  return (
    <div>
      <section className="bg-gradient-to-b from-brand-50 to-white">
        <div className="mx-auto max-w-5xl px-4 py-16 text-center sm:px-6">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl">
            Satamadığın ürün, kayıp olmasın
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-slate-600">
            Bitir Yemek işletme paneliyle fazla ürünlerini sürpriz paketlere
            dönüştür, yeni müşterilere ulaş ve israfı azalt.
          </p>
          <div className="mt-8">
            <ButtonLink href="/kayit" size="lg">
              İşletmeni ücretsiz kaydet <ArrowRight className="h-5 w-5" />
            </ButtonLink>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-4 py-16 sm:px-6">
        <div className="grid gap-10 md:grid-cols-2">
          <div>
            <h2 className="text-2xl font-bold text-slate-900">
              Neden Bitir Yemek?
            </h2>
            <ul className="mt-6 space-y-4">
              {REASONS.map((r) => (
                <li key={r} className="flex items-start gap-3">
                  <span className="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-brand-100 text-brand-700">
                    <Check className="h-4 w-4" />
                  </span>
                  <span className="text-slate-700">{r}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="rounded-3xl border border-brand-200 bg-brand-50 p-8">
            <h3 className="text-lg font-bold text-brand-900">Üç adımda başla</h3>
            <ol className="mt-5 space-y-5">
              {[
                "İşletme hesabı oluştur ve bilgilerini gir.",
                "Yönetici onayından sonra sürpriz paketini tanımla.",
                "Siparişleri al, teslim alma koduyla teslim et.",
              ].map((step, i) => (
                <li key={step} className="flex gap-4">
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-brand-600 text-sm font-bold text-white">
                    {i + 1}
                  </span>
                  <span className="pt-1 text-sm text-brand-900">{step}</span>
                </li>
              ))}
            </ol>
            <ButtonLink href="/kayit" className="mt-8 w-full">
              Hemen kaydol
            </ButtonLink>
          </div>
        </div>
      </section>

      <section className="bg-slate-50">
        <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
          <h2 className="text-center text-2xl font-bold text-slate-900">
            Sık sorulan sorular
          </h2>
          <dl className="mt-8 space-y-4">
            {FAQ.map((item) => (
              <div
                key={item.q}
                className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
              >
                <dt className="font-semibold text-slate-900">{item.q}</dt>
                <dd className="mt-2 text-sm leading-relaxed text-slate-600">
                  {item.a}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      </section>
    </div>
  );
}
