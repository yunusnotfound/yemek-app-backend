import type { Metadata } from "next";
import { Store, Wallet, PackageCheck, ClipboardList, QrCode, BarChart3 } from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Nasıl Çalışır",
  description:
    "Bitir Gitsin müşteriler ve işletmeler için nasıl çalışır? Sürpriz paket akışını adım adım inceleyin.",
};

const CUSTOMER = [
  { icon: Store, title: "Keşfet", text: "Müşteriler mobil uygulamadan yakınındaki işletmelerin sürpriz paketlerini görür." },
  { icon: Wallet, title: "Ayırt & öde", text: "Beğendiği paketi seçer, ödemesini yapar ve benzersiz bir teslim alma kodu alır." },
  { icon: PackageCheck, title: "Teslim al", text: "Belirlenen saat aralığında işletmeye gider, kodunu gösterir ve paketini teslim alır." },
];

const BUSINESS = [
  { icon: ClipboardList, title: "İşletmeni kaydet", text: "Web panelinden ücretsiz hesap aç, işletme bilgilerini ve konumunu gir. Admin onayının ardından yayına alın." },
  { icon: Wallet, title: "Paket oluştur", text: "Gün sonu kalan ürünler için adet, fiyat ve teslim alma saatleriyle sürpriz paket tanımla." },
  { icon: QrCode, title: "Siparişleri doğrula", text: "Müşteri geldiğinde teslim alma kodunu panelden doğrula; sipariş otomatik kapanır." },
  { icon: BarChart3, title: "Takip et & büyüt", text: "Sipariş, gelir ve değerlendirmeleri panelden izle, paketlerini optimize et." },
];

export default function HowItWorksPage() {
  return (
    <div className="mx-auto max-w-5xl px-4 py-16 sm:px-6">
      <header className="mx-auto max-w-2xl text-center">
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-900">
          Nasıl çalışır?
        </h1>
        <p className="mt-4 text-lg text-slate-600">
          Bitir Gitsin, işletmelerin fazla ürününü müşterilerle buluşturur.
          Süreç hem müşteri hem işletme tarafında sade.
        </p>
      </header>

      <section className="mt-16">
        <h2 className="text-2xl font-bold text-slate-900">Müşteriler için</h2>
        <div className="mt-6 grid gap-6 md:grid-cols-3">
          {CUSTOMER.map((s, i) => (
            <div key={s.title} className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="flex items-center gap-3">
                <span className="grid h-10 w-10 place-items-center rounded-lg bg-brand-100 text-brand-700">
                  <s.icon className="h-5 w-5" />
                </span>
                <span className="text-sm font-semibold text-slate-400">Adım {i + 1}</span>
              </div>
              <h3 className="mt-4 font-bold text-slate-900">{s.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-slate-600">{s.text}</p>
            </div>
          ))}
        </div>
        <p className="mt-4 text-sm text-slate-500">
          Müşteri tarafı Bitir Gitsin mobil uygulaması üzerinden çalışır.
        </p>
      </section>

      <section className="mt-16">
        <h2 className="text-2xl font-bold text-slate-900">İşletmeler için</h2>
        <div className="mt-6 grid gap-6 sm:grid-cols-2">
          {BUSINESS.map((s, i) => (
            <div key={s.title} className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="flex items-center gap-3">
                <span className="grid h-10 w-10 place-items-center rounded-lg bg-brand-600 text-white">
                  <s.icon className="h-5 w-5" />
                </span>
                <span className="text-sm font-semibold text-slate-400">Adım {i + 1}</span>
              </div>
              <h3 className="mt-4 font-bold text-slate-900">{s.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-slate-600">{s.text}</p>
            </div>
          ))}
        </div>
      </section>

      <div className="mt-14 flex flex-col items-center justify-center gap-3 rounded-2xl bg-brand-50 px-6 py-10 text-center sm:flex-row">
        <p className="text-lg font-semibold text-brand-900">
          İşletmen için hazır mısın?
        </p>
        <ButtonLink href="/kayit" size="md">
          Hemen kaydol
        </ButtonLink>
      </div>
    </div>
  );
}
