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

const IMPACT = [
  { value: "1/3", label: "Üretilen gıdanın yaklaşık üçte biri israf oluyor" },
  { value: "%50+", label: "Sürpriz paketlerde ortalama indirim" },
  { value: "0₺", label: "İşletme için kurulum ve aylık sabit ücret" },
];

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
      <section className="relative overflow-hidden bg-gradient-to-br from-brand-500 via-brand-600 to-brand-700 text-white">
        <ShoppingBag className="pointer-events-none absolute -right-10 -top-10 h-72 w-72 text-white/10" />
        <Leaf className="pointer-events-none absolute -bottom-16 -left-10 h-64 w-64 text-white/10" />
        <div className="relative mx-auto max-w-6xl px-4 py-20 sm:px-6 sm:py-28">
          <div className="mx-auto max-w-3xl text-center">
            <span className="inline-flex items-center gap-2 rounded-full bg-white/15 px-4 py-1.5 text-sm font-semibold backdrop-blur">
              <Leaf className="h-4 w-4" /> Gıda israfını birlikte azaltalım
            </span>
            <h1 className={`mt-6 text-5xl leading-[0.92] sm:text-6xl md:text-7xl ${display}`}>
              İsrafı azalt,
              <br />
              <span className="text-ink">lezzeti kurtar.</span>
            </h1>
            <p className="mx-auto mt-7 max-w-xl text-lg leading-relaxed text-white/90">
              Restoran, fırın ve marketlerin gün sonunda kalan lezzetlerini uygun
              fiyatlı <strong className="font-semibold">sürpriz paketlerle</strong>{" "}
              satışa sun. Hem bütçene hem gezegene iyi gelir.
            </p>
            <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <ButtonLink href="/kayit" variant="light" size="lg" className="w-full sm:w-auto">
                İşletmeni kaydet <ArrowRight className="h-5 w-5" />
              </ButtonLink>
              <ButtonLink href="/nasil-calisir" variant="outlineLight" size="lg" className="w-full sm:w-auto">
                Nasıl çalışır?
              </ButtonLink>
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

        <div className="mx-auto mt-14 grid max-w-4xl gap-5 sm:grid-cols-3">
          {IMPACT.map((s) => (
            <div key={s.label} className="rounded-3xl border border-ink/10 bg-white p-7 text-center shadow-sm">
              <div className={`text-4xl text-brand-600 ${display}`}>{s.value}</div>
              <p className="mt-3 text-sm text-ink/60">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

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
