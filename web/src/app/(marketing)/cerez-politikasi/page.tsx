import type { Metadata } from "next";
import { SITE } from "@/lib/config";

export const metadata: Metadata = {
  title: "Çerez Politikası",
  description:
    "Bitir Yemek web sitesinde kullanılan çerezler hakkında bilgilendirme.",
};

const COOKIES = [
  {
    name: "bg_at",
    purpose: "Oturum erişim jetonu (giriş yapan kullanıcıyı tanımak için).",
    type: "Zorunlu · httpOnly",
    duration: "Oturum / 7 gün",
  },
  {
    name: "bg_rt",
    purpose: "Oturum yenileme jetonu (oturumu güvenle sürdürmek için).",
    type: "Zorunlu · httpOnly",
    duration: "7 gün",
  },
];

export default function CookiePolicyPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
      <h1 className="font-display text-4xl font-black uppercase tracking-tight text-ink">
        Çerez Politikası
      </h1>
      <p className="mt-4 text-ink/60">Son güncelleme: Haziran 2026</p>

      <div className="mt-8 space-y-5 leading-relaxed text-ink/80">
        <p>
          Çerezler, ziyaret ettiğiniz web sitelerinin tarayıcınıza kaydettiği
          küçük metin dosyalarıdır. {SITE.name}, sitenin temel işlevlerini
          sağlamak için çerezleri kullanır.
        </p>
        <p>
          <strong className="font-semibold text-ink">
            Reklam, pazarlama veya üçüncü taraf takip çerezleri kullanmıyoruz.
          </strong>{" "}
          Yalnızca giriş ve oturum gibi sitenin çalışması için gerekli olan zorunlu
          çerezleri kullanırız.
        </p>
      </div>

      <h2 className="mt-12 font-display text-2xl font-black uppercase tracking-tight text-ink">
        Kullandığımız çerezler
      </h2>
      <div className="mt-5 overflow-hidden rounded-2xl border border-ink/10">
        <table className="w-full text-left text-sm">
          <thead className="bg-sand text-ink">
            <tr>
              <th className="px-4 py-3 font-semibold">Çerez</th>
              <th className="px-4 py-3 font-semibold">Amaç</th>
              <th className="px-4 py-3 font-semibold">Tür</th>
              <th className="px-4 py-3 font-semibold">Süre</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-ink/10 bg-white">
            {COOKIES.map((c) => (
              <tr key={c.name}>
                <td className="px-4 py-3 font-mono font-semibold text-ink">{c.name}</td>
                <td className="px-4 py-3 text-ink/70">{c.purpose}</td>
                <td className="px-4 py-3 text-ink/70">{c.type}</td>
                <td className="px-4 py-3 text-ink/70">{c.duration}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2 className="mt-12 font-display text-2xl font-black uppercase tracking-tight text-ink">
        Çerezleri nasıl kontrol edersiniz?
      </h2>
      <p className="mt-4 leading-relaxed text-ink/80">
        Tarayıcınızın ayarlarından çerezleri silebilir veya engelleyebilirsiniz.
        Ancak zorunlu çerezleri engellerseniz giriş yapma ve oturum açık tutma gibi
        temel işlevler düzgün çalışmayabilir.
      </p>

      <h2 className="mt-12 font-display text-2xl font-black uppercase tracking-tight text-ink">
        İletişim
      </h2>
      <p className="mt-4 leading-relaxed text-ink/80">
        Çerez kullanımına ilişkin sorularınız için bize{" "}
        <a
          href={`mailto:${SITE.email}`}
          className="font-semibold text-brand-700 underline underline-offset-2 hover:text-brand-800"
        >
          {SITE.email}
        </a>{" "}
        adresinden ulaşabilirsiniz.
      </p>
    </div>
  );
}
