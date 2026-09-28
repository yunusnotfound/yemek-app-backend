import type { Metadata } from "next";
import type { ReactNode } from "react";
import {
  ArrowDown,
  ArrowUpRight,
  Clock3,
  CreditCard,
  Store,
} from "lucide-react";
import { SITE } from "@/lib/config";

export const metadata: Metadata = {
  title: "İptal, Teslimat ve İade Koşulları",
  description:
    "Bitir Gitsin siparişlerinde işletmeden teslim alma, teslim öncesi iptal, ödeme iadesi ve tüketici haklarına ilişkin koşullar.",
};

const sections = [
  { id: "teslimat", label: "Teslimat" },
  { id: "iptal", label: "Sipariş iptali" },
  { id: "iade", label: "İade ve geri ödeme" },
  { id: "cayma-hakki", label: "Cayma hakkı" },
  { id: "destek", label: "Başvuru ve destek" },
];

function PolicySection({
  id,
  number,
  title,
  children,
}: {
  id: string;
  number: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <section
      id={id}
      aria-labelledby={`${id}-heading`}
      className="scroll-mt-32 border-t border-ink/15 py-10 sm:py-12"
    >
      <div className="mb-6 flex items-start gap-4 sm:gap-6">
        <span
          className="pt-1 font-display text-xl font-bold text-brand-700"
          aria-hidden="true"
        >
          {number}
        </span>
        <h2
          id={`${id}-heading`}
          className="font-display text-3xl font-black uppercase leading-tight tracking-tight text-ink sm:text-4xl"
        >
          {title}
        </h2>
      </div>
      <div className="space-y-5 text-base leading-8 text-ink/80 sm:pl-12 [&_h3]:pt-2 [&_h3]:text-lg [&_h3]:font-bold [&_h3]:text-ink [&_li]:pl-1 [&_strong]:font-semibold [&_strong]:text-ink [&_ul]:list-disc [&_ul]:space-y-3 [&_ul]:pl-5">
        {children}
      </div>
    </section>
  );
}

export default function OrderPolicyPage() {
  return (
    <div className="bg-cream">
      <header className="border-b border-ink/10 bg-sand">
        <div className="mx-auto max-w-5xl px-5 py-14 sm:px-8 sm:py-20">
          <p className="mb-5 text-xs font-bold uppercase tracking-[0.2em] text-brand-700">
            Siparişin hakkında her şey
          </p>
          <h1 className="max-w-4xl font-display text-[clamp(2.8rem,7vw,5.5rem)] font-black uppercase leading-[0.98] tracking-tight text-ink">
            İptal, teslimat
            <br />
            <span className="text-brand-700">ve iade koşulları.</span>
          </h1>
          <p className="mt-7 max-w-2xl text-base leading-8 text-ink/75 sm:text-lg">
            Bir lezzeti kurtarırken sürecin her adımı açık olsun. Siparişini
            nasıl teslim alabileceğini, planın değişirse ne yapacağını ve iade
            haklarını burada bulabilirsin.
          </p>
          <p className="mt-6 text-sm text-ink/60">
            Son güncelleme: <time dateTime="2026-09-28">28 Eylül 2026</time>
          </p>
        </div>
      </header>

      <div className="mx-auto max-w-5xl px-5 py-10 sm:px-8 sm:py-14">
        <div className="grid gap-4 sm:grid-cols-3">
          {[
            {
              icon: Store,
              title: "İşletmeden teslim",
              text: "Paketini, siparişinde belirtilen yer ve saat aralığında al.",
            },
            {
              icon: Clock3,
              title: "Teslim öncesi iptal",
              text: "Teslim alınmamış aktif siparişini uygulamadan iptal et.",
            },
            {
              icon: CreditCard,
              title: "Ödeme aracına iade",
              text: "Geri ödemen, alışverişte kullandığın ödeme aracına yapılır.",
            },
          ].map(({ icon: Icon, title, text }) => (
            <div
              key={title}
              className="rounded-2xl border border-ink/10 bg-white/60 p-6"
            >
              <Icon
                className="mb-5 h-7 w-7 text-brand-700"
                strokeWidth={1.5}
                aria-hidden="true"
              />
              <h2 className="font-display text-xl font-bold uppercase text-ink">
                {title}
              </h2>
              <p className="mt-2 text-sm leading-6 text-ink/70">{text}</p>
            </div>
          ))}
        </div>

        <nav
          aria-label="Koşulların bölümleri"
          className="my-9 flex flex-wrap gap-2 sm:my-12"
        >
          {sections.map((section) => (
            <a
              key={section.id}
              href={`#${section.id}`}
              className="inline-flex min-h-11 items-center gap-2 rounded-full border border-ink/20 px-4 py-2 text-sm font-semibold text-ink transition-colors hover:border-brand-700 hover:bg-brand-100 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand-700"
            >
              {section.label}
              <ArrowDown size={14} aria-hidden="true" />
            </a>
          ))}
        </nav>

        <div className="mb-10 max-w-3xl space-y-4 text-base leading-8 text-ink/80">
          <p>
            Bu koşullar, {SITE.name} üzerinden verilen sürpriz paket
            siparişlerinin teslim alınması, iptali ve iadesi için geçerlidir.
            Paketi satışa sunan işletme ürünün satıcısıdır; {SITE.name},
            işletmeler ile kullanıcıları bir araya getiren platformdur.
            Satıcının ve platformun mevzuattan doğan yükümlülükleri saklıdır.
          </p>
          <p>
            Siparişe özgü ürün açıklaması, fiyat, işletme bilgileri ve teslim
            alma aralığı ilgili paket ve sipariş ekranlarında yer alır. Bu
            sayfa, siparişe ilişkin ön bilgilendirme ve sözleşme hükümleriyle
            birlikte değerlendirilir; tüketicinin kanuni haklarını
            sınırlandırmaz.
          </p>
        </div>

        <PolicySection
          id="teslimat"
          number="01"
          title="Teslimat ve teslim alma"
        >
          <p>
            <strong>
              Teslimat, paketin işletmeden elden alınmasıyla gerçekleşir.
            </strong>{" "}
            Mevcut hizmet modelinde kurye veya kargo ile adrese gönderim
            bulunmaz. Sipariş vermeden önce işletmenin konumunu, teslim alma
            tarihini ve saat aralığını kontrol edin.
          </p>
          <ul>
            <li>
              Paketinizi siparişte belirtilen işletmeden, belirtilen teslim alma
              aralığında alın.
            </li>
            <li>
              Teslim alma kodunu paketi alırken işletme görevlisine gösterin.
              Kodun doğrulanmasıyla siparişin teslim kaydı oluşturulur.
            </li>
            <li>
              Teslim sırasında paket adedini ve gözle görülebilen bir sorun olup
              olmadığını kontrol edin. Teslim kaydı, sonradan fark edilen
              ayıplara ilişkin haklarınızı ortadan kaldırmaz.
            </li>
            <li>
              İşletme kapalıysa, paket hazır değilse veya teslim sağlanamıyorsa
              sipariş numaranızla bize ulaşın. Teslim edilemeyen siparişin
              durumu ve varsa ödeme iadesi değerlendirilir.
            </li>
          </ul>
          <h3>Teslim saatine yetişemiyorsanız</h3>
          <p>
            Teslim alma aralığı dışında paketin saklanması veya teslim edilmesi
            garanti edilemez. Gecikeceğinizi fark ettiğinizde işletmeyle veya
            bizimle iletişime geçin; teslim alınmamış aktif siparişler için
            aşağıdaki iptal akışını kullanabilirsiniz. Teslim süresinin geçmesi,
            siparişin otomatik olarak iptal edildiği veya iadenin tamamlandığı
            anlamına gelmez.
          </p>
          <h3>Paket içeriği ve gıda güvenliği</h3>
          <p>
            Sürpriz paketin içeriği işletmenin o gün elinde kalan ürünlere göre
            değişebilir. Paketin ilan edilen temel niteliklerine uygun olması
            gerekir. Alerjen, içerik ve saklama koşullarına ilişkin bilgileri
            işletmeden teyit edin; teslim sonrasında bildirilen saklama ve
            tüketim koşullarına uyun. Sürpriz paket olması, güvenli olmayan veya
            sözleşmeye aykırı ürün teslimini haklı kılmaz.
          </p>
        </PolicySection>

        <PolicySection id="iptal" number="02" title="Sipariş iptali">
          <h3>Kullanıcı tarafından iptal</h3>
          <p>
            Henüz teslim alınmamış; ödeme bekleyen, onay bekleyen veya
            onaylanmış aktif siparişlerinizi uygulamadaki{" "}
            <strong>Siparişlerim</strong> bölümünde ilgili siparişin{" "}
            <strong>Siparişi İptal Et</strong> seçeneğiyle iptal edebilirsiniz.
            İşlemin ardından sipariş durumunun iptal edildiğini kontrol edin.
          </p>
          <p>
            Ödeme tahsil edilmemişse geri ödenecek bir tutar oluşmaz. Ödeme
            alınmışsa iptal işlemi, tahsil edilen tutarın iade sürecini
            başlatır. İptal durumunun görünmesi ile tutarın kartınıza yansıması
            farklı zamanlarda gerçekleşebilir.
          </p>
          <h3>İşletme tarafından iptal</h3>
          <p>
            İşletmenin siparişi karşılayamaması nedeniyle iptal edilen ve
            ödemesi alınmış siparişlerde tahsil edilen tutar iade edilir.
            Siparişinizin güncel durumunu uygulamadan kontrol edebilir, teslim
            gerçekleşmediği hâlde aktif görünen siparişler için destek
            isteyebilirsiniz.
          </p>
          <div className="rounded-2xl border-l-4 border-brand-500 bg-brand-50 p-5">
            <p>
              Teslim alınmış siparişlerde uygulama üzerinden iptal işlemi
              yapılamaz. Bu durum, eksik, bozuk veya açıklamaya aykırı ürünler
              için iade ve diğer tüketici haklarını kullanmanıza engel değildir.
              Bu taleplerinizi aşağıdaki iletişim kanalından iletebilirsiniz.
            </p>
          </div>
        </PolicySection>

        <PolicySection id="iade" number="03" title="İade ve geri ödeme">
          <h3>Ürünle ilgili bir sorun varsa</h3>
          <p>
            Paketin eksik teslim edilmesi, bozulmuş olması veya ilan edilen
            özellikleri taşımaması gibi durumlarda sipariş numaranızı, işletme
            adını ve sorunun açıklamasını bize iletin. Varsa fotoğraf, fiş veya
            diğer belgeler incelemeye yardımcı olur; fotoğraf sunulması
            başvurunun kabulü için zorunlu koşul değildir.
          </p>
          <p>
            Gıdanın niteliği nedeniyle sorunu fark ettiğinizde gecikmeden
            bildirimde bulunmanız değerlendirmeyi kolaylaştırır. Bu öneri kanuni
            başvuru sürelerinizi kısaltmaz. Güvenliğinden şüphe ettiğiniz ürünü
            tüketmeyin; ürünün geri alınması gerekiyorsa uygun teslim yöntemi
            sizinle paylaşılır.
          </p>
          <p>
            Ayıplı ürünlerde 6502 sayılı Kanun kapsamında sözleşmeden dönerek
            bedel iadesi, ayıp oranında indirim veya koşulları mevcutsa ayıpsız
            ürünle değişim talep edebilirsiniz. Ürünün niteliğine uygulanabilen
            diğer kanuni seçimlik haklarınız da saklıdır. İndirimli satış veya
            sürpriz paket modeli bu hakları ortadan kaldırmaz.
          </p>
          <h3>İade nasıl yapılır?</h3>
          <ul>
            <li>
              İptal edilen ve tahsilatı gerçekleşmiş siparişlerde, sipariş için
              fiilen ödenen tutar geri ödenir.
            </li>
            <li>
              Kartlı ödemelerin iadesi iyzico üzerinden, satın alma sırasında
              kullanılan karta veya ödeme aracına yapılır. Geri ödeme için
              ayrıca işlem ücreti alınmaz.
            </li>
            <li>
              İade tutarının hesap hareketlerinde görünme zamanı bankanın işlem
              sürecine göre değişebilir. İade henüz görünmüyorsa sipariş
              numaranızla durum bilgisi talep edebilirsiniz.
            </li>
            <li>
              İşlem doğrulaması gereken durumlarda iade sonucu ödeme kayıtları
              üzerinden takip edilir. Teknik inceleme, kanuni iade
              yükümlülüklerini ve sürelerini ortadan kaldırmaz.
            </li>
          </ul>
          <p>
            Ayıplı üründe sözleşmeden dönme veya bedel indirimi hakkı
            kullanıldığında, ilgili bedelin derhâl iadesine ilişkin kanuni
            hükümler uygulanır. Diğer iade nedenlerinde de mevzuatın öngördüğü
            süreler esas alınır; bankanın tutarı görüntüleme süreci bu
            yükümlülükleri değiştirmez.
          </p>
        </PolicySection>

        <PolicySection
          id="cayma-hakki"
          number="04"
          title="Cayma hakkı ve gıda ürünleri"
        >
          <p>
            Mesafeli Sözleşmeler Yönetmeliği’nin 15. maddesi uyarınca, çabuk
            bozulabilen veya son kullanma tarihi geçebilecek ürünler için,
            taraflarca aksi kararlaştırılmadıkça gerekçesiz cayma hakkı
            bulunmaz. Bu kapsamdaki gıda paketlerinde genel 14 günlük cayma
            hakkı uygulanmaz.
          </p>
          <p>
            Bu istisna, yukarıda açıklanan teslim öncesi iptal olanağını veya
            ayıplı ve teslim edilmemiş ürüne ilişkin haklarınızı kaldırmaz.
            İstisna kapsamına girmeyen bir ürün için yasal cayma koşulları
            oluşmuşsa, teslimden itibaren 14 gün içinde cayma bildiriminizi
            satıcıya veya bize yazılı olarak iletebilirsiniz. Cayma hakkına
            bağlı geri ödeme ve ürünün geri verilmesi için ilgili yasal hükümler
            uygulanır.
          </p>
          <p className="text-sm">
            Ayrıntılı bilgi:{" "}
            <a
              href="https://tuketici.ticaret.gov.tr/yayinlar/tuketici-bilgi-rehberi/mesafeli-sozlesmeler-hakkinda-bilgilendirme"
              className="font-semibold text-brand-700 underline underline-offset-4 hover:text-brand-900"
            >
              Ticaret Bakanlığı — Mesafeli sözleşmeler
            </a>
            {" · "}
            <a
              href="https://tuketici.ticaret.gov.tr/yayinlar/tuketici-bilgi-rehberi/ayipli-mal-ve-hizmetler-hakkinda-bilgilendirme"
              className="font-semibold text-brand-700 underline underline-offset-4 hover:text-brand-900"
            >
              Ayıplı mal ve hizmetlerde haklar
            </a>
          </p>
        </PolicySection>

        <PolicySection id="destek" number="05" title="Başvuru ve destek">
          <p>
            İptal, teslim alma ve iade talepleriniz için {SITE.email} adresine
            yazabilirsiniz. Mesajınıza sipariş numaranızı, işletme adını,
            sipariş tarihini ve talebinizi eklemeniz işleminizin bulunmasını
            kolaylaştırır. Başvuru için tam kart numaranızı, kart güvenlik
            kodunuzu veya şifrenizi paylaşmayın.
          </p>
          <a
            href={`mailto:${SITE.email}?subject=${encodeURIComponent("Sipariş, iptal ve iade desteği")}`}
            className="inline-flex min-h-12 max-w-full items-center gap-3 rounded-full bg-ink px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-brand-800 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-brand-700 sm:text-base"
          >
            <span className="break-all">{SITE.email}</span>
            <ArrowUpRight size={18} className="shrink-0" aria-hidden="true" />
          </a>
          <h3>Uyuşmazlık hâlinde</h3>
          <p>
            İlgili yılın parasal sınırları ve görev kuralları doğrultusunda,
            yerleşim yerinizdeki veya işlemin yapıldığı yerdeki Tüketici Hakem
            Heyetine; gerektiğinde dava şartı arabuluculuk hükümleri saklı
            kalmak üzere Tüketici Mahkemesine başvurabilirsiniz. Hakem heyeti
            başvuruları e-Devlet üzerinden TÜBİS aracılığıyla da yapılabilir.
            Destek ekibimize başvurmuş olmanız yasal yollara başvurma hakkınızı
            sınırlandırmaz.
          </p>
          <p className="text-sm">
            <a
              href="https://tuketici.ticaret.gov.tr/yayinlar/tuketici-bilgi-rehberi/tuketici-hakem-heyetleri-hakkinda-bilgilendirme"
              className="font-semibold text-brand-700 underline underline-offset-4 hover:text-brand-900"
            >
              Ticaret Bakanlığı — Tüketici Hakem Heyeti başvuru bilgileri
            </a>
          </p>
        </PolicySection>
      </div>
    </div>
  );
}
