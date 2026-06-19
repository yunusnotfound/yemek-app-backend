import {
  ArrowRight,
  Leaf,
  PackageCheck,
  Wallet,
  Store,
  Clock,
  QrCode,
  BarChart3,
  ShoppingBag,
} from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";

const CATEGORIES = [
  "FIRIN", "RESTORAN", "MARKET", "KAFE", "PASTANE", "DÖNER",
  "PİZZA", "TATLI", "MANAV", "ŞARKÜTERİ", "KAHVALTI", "SUSHI",
];

const STEPS = [
  { icon: Store, title: "Keşfet", text: "Müşteriler yakınındaki işletmelerin gün sonu sürpriz paketlerini uygulamadan görür." },
  { icon: Wallet, title: "Ayırt", text: "Beğendiği paketi uygun fiyata ayırır, ödemesini yapar ve teslim alma kodunu alır." },
  { icon: PackageCheck, title: "Teslim Al", text: "Belirtilen saat aralığında işletmeye uğrar, kodunu gösterir, lezzetini kurtarır." },
];

const BENEFITS = [
  { icon: Wallet, title: "Kaybı gelire çevir", text: "Satılmayan ürünleri çöpe atmak yerine indirimli paketlerle değerlendir." },
  { icon: Store, title: "Yeni müşteriler", text: "Bölgendeki yeni müşterilerle tanış, sadık bir kitle oluştur." },
  { icon: Clock, title: "Dakikalar içinde kurulum", text: "İşletmeni kaydet, paketini oluştur, satışa başla. Teknik bilgi gerekmez." },
  { icon: QrCode, title: "Kolay teslimat", text: "Müşterinin teslim alma kodunu panelden doğrula, siparişi kapat." },
  { icon: BarChart3, title: "Gerçek zamanlı panel", text: "Sipariş, gelir ve değerlendirmeleri tek ekrandan takip et." },
  { icon: Leaf, title: "Sürdürülebilirlik", text: "Gıda israfını azaltarak markanı çevreci değerlerle güçlendir." },
];

const display = "font-display font-black uppercase tracking-tight";

export default function HomePage() {
  return (
    <>
      {/* ── Hero ───────────────────────────────────────────────────────── */}
      {/* -mt-16: şeffaf (sticky) navbar'ın arkasına uzanır */}
      <section className="relative isolate -mt-16 overflow-hidden bg-brand-700 text-white">
        {/* Lifestyle görsel — web/public/hero.jpg (kendi fotoğrafınla değiştir) */}
        <img
          src="/hero.jpg"
          alt=""
          className="absolute inset-0 h-full w-full object-cover object-center"
        />
        {/* Turuncu tonlama + metin okunabilirliği için degradeler */}
        <div className="absolute inset-0 bg-brand-600/40 mix-blend-multiply" />
        <div className="absolute inset-0 bg-gradient-to-b from-brand-700/55 via-brand-700/10 to-brand-800/85" />

        <div className="relative mx-auto flex min-h-[80vh] max-w-6xl flex-col items-center justify-end px-4 pb-20 pt-28 text-center sm:px-6">
          <h1 className={`text-5xl leading-[0.9] text-cream drop-shadow-md sm:text-6xl md:text-7xl ${display}`}>
            İsrafı azalt,
            <br />
            lezzeti kurtar.
          </h1>
          <div className="mt-9 flex w-full flex-col items-center justify-center gap-3 sm:w-auto sm:flex-row">
            <ButtonLink href="#" variant="light" size="lg" className="w-full sm:w-auto">
              Uygulamayı indir
            </ButtonLink>
            <ButtonLink href="/isletmeler-icin" variant="outlineLight" size="lg" className="w-full sm:w-auto">
              İşletmeler için
            </ButtonLink>
          </div>
        </div>
      </section>

      {/* ── Misyon ─────────────────────────────────────────────────────── */}
      <section className="mx-auto max-w-4xl px-4 py-20 text-center sm:px-6 sm:py-28">
        <p className="text-2xl font-medium leading-snug text-ink sm:text-3xl md:text-4xl">
          Bitir Yemek, gün sonunda kalan kaliteli lezzetleri uygun fiyatlı sürpriz
          paketlerle{" "}
          <span className="relative whitespace-nowrap text-brand-600">
            kurtaran
            <svg className="absolute -bottom-1 left-0 w-full" height="6" viewBox="0 0 200 6" preserveAspectRatio="none" aria-hidden>
              <path d="M0 3 Q 50 6 100 3 T 200 3" stroke="currentColor" strokeWidth="3" fill="none" strokeLinecap="round" />
            </svg>
          </span>{" "}
          bir gıda israfını önleme platformudur.
        </p>
        <p className="mx-auto mt-6 max-w-2xl text-base text-ink/60">
          İşletmenin kaybını gelire, müşterinin bütçesini lezzete çevirir; her
          kurtarılan paket çöpe gitmeyen gıda demektir.
        </p>
      </section>

      {/* ── Neden Bitir Yemek ──────────────────────────────────────────── */}
      <section className="bg-cream pb-20 sm:pb-28">
        <div className="mx-auto max-w-6xl px-4 text-center sm:px-6">
          <p className="font-display text-base font-bold uppercase tracking-[0.25em] text-ink">
            Neden
          </p>
          <h2 className={`mt-1 text-5xl text-brand-600 sm:text-6xl ${display}`}>
            Bitir Yemek?
          </h2>

          <div className="mt-14 grid items-center gap-x-6 gap-y-12 lg:grid-cols-[1fr_auto_1fr]">
            {/* Sol değerler */}
            <div className="flex flex-col gap-y-12 lg:gap-y-28 lg:py-6 lg:text-right">
              <p className="font-display text-lg font-bold uppercase leading-tight text-ink">
                Yarım fiyatına lezzet
              </p>
              <p className="font-display text-lg font-bold uppercase leading-tight text-ink">
                İsrafı azaltarak gezegene katkı
              </p>
            </div>

            {/* Merkez: sürpriz paket */}
            <div className="relative mx-auto grid h-60 w-60 place-items-center sm:h-72 sm:w-72">
              <div className="absolute inset-0 rounded-full bg-gradient-to-br from-brand-400 to-brand-600 shadow-xl" />
              <ShoppingBag className="relative h-28 w-28 text-cream" strokeWidth={1.5} />
            </div>

            {/* Sağ değerler */}
            <div className="flex flex-col gap-y-12 lg:gap-y-28 lg:py-6 lg:text-left">
              <p className="font-display text-lg font-bold uppercase leading-tight text-ink">
                Yakınındaki lezzetleri kurtar
              </p>
              <p className="font-display text-lg font-bold uppercase leading-tight text-ink">
                Yeni işletmeler keşfet
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── Kategori şeridi ────────────────────────────────────────────── */}
      <div className="overflow-hidden border-y-2 border-ink bg-ink py-3.5 text-cream">
        <div className="flex w-max animate-marquee">
          {[0, 1].map((dup) => (
            <ul key={dup} className="flex shrink-0 items-center" aria-hidden={dup === 1}>
              {CATEGORIES.map((c) => (
                <li key={c} className="flex items-center">
                  <span className={`px-6 text-lg ${display} text-cream`}>{c}</span>
                  <Leaf className="h-3.5 w-3.5 text-brand-400" />
                </li>
              ))}
            </ul>
          ))}
        </div>
      </div>

      {/* ── Nasıl çalışır (koyu bölüm) ─────────────────────────────────── */}
      <section className="bg-ink text-cream">
        <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-28">
          <div className="mx-auto max-w-2xl text-center">
            <span className="text-sm font-bold uppercase tracking-widest text-gold-400">
              Nasıl çalışır
            </span>
            <h2 className={`mt-3 text-4xl sm:text-5xl ${display}`}>
              Üç adımda lezzet kurtar
            </h2>
          </div>
          <div className="mt-14 grid gap-6 md:grid-cols-3">
            {STEPS.map((s, i) => (
              <div key={s.title} className="relative rounded-3xl bg-white/5 p-8 ring-1 ring-white/10">
                <span className={`absolute right-7 top-6 text-6xl text-white/10 ${display}`}>
                  {i + 1}
                </span>
                <span className="grid h-14 w-14 place-items-center rounded-2xl bg-brand-600 text-white">
                  <s.icon className="h-7 w-7" />
                </span>
                <h3 className={`mt-6 text-2xl ${display}`}>{s.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-cream/70">{s.text}</p>
              </div>
            ))}
          </div>
          <p className="mt-8 text-center text-sm text-cream/50">
            Müşteri tarafı Bitir Yemek mobil uygulaması üzerinden çalışır.
          </p>
        </div>
      </section>

      {/* ── İşletmeler için ────────────────────────────────────────────── */}
      <section className="mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-28">
        <div className="mx-auto max-w-2xl text-center">
          <span className="text-sm font-bold uppercase tracking-widest text-brand-600">
            İşletmeler için
          </span>
          <h2 className={`mt-3 text-4xl text-ink sm:text-5xl ${display}`}>
            Satamadığın ürün, kayıp olmasın
          </h2>
          <p className="mt-4 text-ink/60">
            İşletme paneliyle paketlerini yönet, siparişleri takip et, geliri artır.
          </p>
        </div>
        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {BENEFITS.map((b) => (
            <div key={b.title} className="rounded-3xl border border-ink/10 bg-white p-7 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
              <span className="grid h-12 w-12 place-items-center rounded-2xl bg-brand-100 text-brand-700">
                <b.icon className="h-6 w-6" />
              </span>
              <h3 className="mt-5 text-lg font-bold text-ink">{b.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-ink/60">{b.text}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Büyük CTA ──────────────────────────────────────────────────── */}
      <section className="px-4 pb-24 sm:px-6">
        <div className="relative mx-auto max-w-6xl overflow-hidden rounded-[2rem] bg-gradient-to-br from-brand-500 to-brand-700 px-8 py-16 text-center shadow-xl sm:px-16">
          <ShoppingBag className="pointer-events-none absolute -right-8 -bottom-10 h-56 w-56 text-white/10" />
          <h2 className={`relative text-4xl text-white sm:text-5xl ${display}`}>
            İşletmeni bugün kaydet
          </h2>
          <p className="relative mx-auto mt-4 max-w-xl text-white/90">
            Kurulum ücreti yok, aylık sabit ücret yok. Sadece sat, kazan ve israfı azalt.
          </p>
          <div className="relative mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <ButtonLink href="/kayit" variant="light" size="lg" className="w-full sm:w-auto">
              Ücretsiz başla <ArrowRight className="h-5 w-5" />
            </ButtonLink>
            <ButtonLink href="/isletmeler-icin" variant="outlineLight" size="lg" className="w-full sm:w-auto">
              Detayları gör
            </ButtonLink>
          </div>
        </div>
      </section>
    </>
  );
}
