import {
  ArrowRight,
  Leaf,
  PackageCheck,
  Wallet,
  Store,
  Clock,
  QrCode,
  BarChart3,
} from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";

const IMPACT = [
  { value: "1/3", label: "Üretilen gıdanın yaklaşık üçte biri israf oluyor" },
  { value: "%50+", label: "Sürpriz paketlerde ortalama indirim oranı" },
  { value: "0₺", label: "İşletme için kurulum ve aylık sabit ücret" },
];

const CUSTOMER_STEPS = [
  {
    icon: Store,
    title: "Keşfet",
    text: "Yakınındaki işletmelerin gün sonu sürpriz paketlerini uygulamadan gör.",
  },
  {
    icon: Wallet,
    title: "Ayırt",
    text: "Uygun fiyata paketini ayırt, ödemeni yap, teslim alma kodunu al.",
  },
  {
    icon: PackageCheck,
    title: "Teslim Al",
    text: "Belirtilen saat aralığında işletmeye uğra, kodunu göster, lezzetini kurtar.",
  },
];

const BUSINESS_BENEFITS = [
  {
    icon: Wallet,
    title: "Kaybı gelire çevir",
    text: "Satılmayan ürünleri çöpe atmak yerine indirimli paketlerle değerlendir.",
  },
  {
    icon: Store,
    title: "Yeni müşteriler",
    text: "Bölgendeki yeni müşterilerle tanış, sadık bir kitle oluştur.",
  },
  {
    icon: Clock,
    title: "Dakikalar içinde kurulum",
    text: "İşletmeni kaydet, paketini oluştur, satışa başla. Teknik bilgi gerekmez.",
  },
  {
    icon: QrCode,
    title: "Kolay teslimat",
    text: "Müşterinin teslim alma kodunu panelden doğrula, siparişi kapat.",
  },
  {
    icon: BarChart3,
    title: "Gerçek zamanlı panel",
    text: "Sipariş, gelir ve değerlendirmeleri tek ekrandan takip et.",
  },
  {
    icon: Leaf,
    title: "Sürdürülebilirlik",
    text: "Gıda israfını azaltarak markanı çevreci değerlerle güçlendir.",
  },
];

export default function HomePage() {
  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden bg-gradient-to-b from-brand-50 to-white">
        <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-28">
          <div className="mx-auto max-w-3xl text-center">
            <span className="inline-flex items-center gap-2 rounded-full border border-brand-200 bg-white px-4 py-1.5 text-sm font-medium text-brand-700 shadow-sm">
              <Leaf className="h-4 w-4" /> Gıda israfını birlikte azaltalım
            </span>
            <h1 className="mt-6 text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl md:text-6xl">
              İsrafı azalt,{" "}
              <span className="text-brand-600">lezzeti kurtar.</span>
            </h1>
            <p className="mt-6 text-lg leading-relaxed text-slate-600">
              Bitir Yemek; restoran, fırın ve marketlerin gün sonunda kalan
              lezzetlerini uygun fiyatlı <strong>sürpriz paketlerle</strong>{" "}
              satışa sunmasını sağlar. Hem bütçene hem gezegene iyi gelir.
            </p>
            <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <ButtonLink href="/kayit" size="lg" className="w-full sm:w-auto">
                İşletmeni kaydet <ArrowRight className="h-5 w-5" />
              </ButtonLink>
              <ButtonLink
                href="/nasil-calisir"
                variant="outline"
                size="lg"
                className="w-full sm:w-auto"
              >
                Nasıl çalışır?
              </ButtonLink>
            </div>
          </div>

          {/* Impact strip */}
          <div className="mx-auto mt-16 grid max-w-4xl gap-4 sm:grid-cols-3">
            {IMPACT.map((s) => (
              <div
                key={s.label}
                className="rounded-2xl border border-slate-200 bg-white p-6 text-center shadow-sm"
              >
                <div className="text-3xl font-extrabold text-brand-600">
                  {s.value}
                </div>
                <p className="mt-2 text-sm text-slate-600">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Müşteri adımları */}
      <section className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="text-3xl font-bold tracking-tight text-slate-900">
            Üç adımda lezzet kurtar
          </h2>
          <p className="mt-4 text-slate-600">
            Müşteriler için sade bir deneyim — keşfet, ayırt, teslim al.
          </p>
        </div>
        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {CUSTOMER_STEPS.map((s, i) => (
            <div
              key={s.title}
              className="relative rounded-2xl border border-slate-200 bg-white p-7 shadow-sm"
            >
              <span className="absolute right-6 top-6 text-5xl font-extrabold text-brand-50">
                {i + 1}
              </span>
              <span className="grid h-12 w-12 place-items-center rounded-xl bg-brand-100 text-brand-700">
                <s.icon className="h-6 w-6" />
              </span>
              <h3 className="mt-5 text-lg font-bold text-slate-900">{s.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-slate-600">
                {s.text}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* İşletmeler için */}
      <section className="bg-slate-50">
        <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
          <div className="mx-auto max-w-2xl text-center">
            <span className="text-sm font-semibold uppercase tracking-wide text-brand-600">
              İşletmeler için
            </span>
            <h2 className="mt-3 text-3xl font-bold tracking-tight text-slate-900">
              Satamadığın ürün, kayıp olmasın
            </h2>
            <p className="mt-4 text-slate-600">
              Bitir Yemek işletme paneliyle paketlerini yönet, siparişleri takip
              et, geliri artır.
            </p>
          </div>
          <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {BUSINESS_BENEFITS.map((b) => (
              <div
                key={b.title}
                className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
              >
                <span className="grid h-11 w-11 place-items-center rounded-xl bg-brand-600 text-white">
                  <b.icon className="h-5 w-5" />
                </span>
                <h3 className="mt-4 font-bold text-slate-900">{b.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-slate-600">
                  {b.text}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
        <div className="overflow-hidden rounded-3xl bg-brand-600 px-8 py-14 text-center shadow-lg sm:px-16">
          <h2 className="text-3xl font-bold tracking-tight text-white sm:text-4xl">
            İşletmeni bugün kaydet
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-brand-50">
            Kurulum ücreti yok, aylık sabit ücret yok. Sadece sat, kazan ve
            israfı azalt.
          </p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <ButtonLink
              href="/kayit"
              size="lg"
              variant="secondary"
              className="w-full bg-white text-brand-700 hover:bg-brand-50 sm:w-auto"
            >
              Ücretsiz başla <ArrowRight className="h-5 w-5" />
            </ButtonLink>
            <ButtonLink
              href="/isletmeler-icin"
              size="lg"
              variant="ghost"
              className="w-full text-white hover:bg-brand-500 sm:w-auto"
            >
              Detayları gör
            </ButtonLink>
          </div>
        </div>
      </section>
    </>
  );
}
