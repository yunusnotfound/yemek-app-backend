import Link from "next/link";
import {
  ArrowDown,
  ArrowRight,
  ArrowUpRight,
  Check,
  Heart,
  Leaf,
  MapPin,
  Plus,
  ShieldCheck,
  Store,
  Wallet,
} from "lucide-react";
import { ButtonLink } from "@/components/ui/Button";
import { HowItWorks } from "@/components/site/HowItWorks";
import { PaymentMethods } from "@/components/site/PaymentMethods";
import { SITE } from "@/lib/config";
import styles from "@/components/site/Marketing.module.css";

const BENEFITS = [
  {
    icon: Wallet,
    title: "Bütçene iyi gelir.",
    text: "Sevdiğin lezzetlere, gün sonuna özel daha uygun fiyatlarla ulaş.",
  },
  {
    icon: MapPin,
    title: "Mahallene iyi gelir.",
    text: "Yakınındaki fırınları, kafeleri ve restoranları yeniden keşfet.",
  },
  {
    icon: Leaf,
    title: "Gezegene iyi gelir.",
    text: "Hâlâ tüketilebilir güzel yemeklerin israf olmasını önlemeye katkı sağla.",
  },
];

const CATEGORIES = [
  {
    title: "Fırından gelen mutluluk",
    type: "FIRIN & PASTANE",
    image: "bakery.webp",
    alt: "Tahta sunum üzerinde simit, ekmek ve poğaça",
  },
  {
    title: "Günün lezzetli sürprizi",
    type: "RESTORAN & KAFE",
    image: "restaurant.webp",
    alt: "Restoran lezzetlerinden oluşan bir yemek tabağı",
  },
  {
    title: "İyilikle dolu bir sepet",
    type: "MARKET & MANAV",
    image: "produce.webp",
    alt: "Çeşitli mevsim meyveleri ve sebzeleri",
  },
];

const FAQ = [
  {
    q: "Sürpriz paketin içinde ne var?",
    a: "Paket içeriği, işletmenin o gün elinde kalan ve tüketime uygun ürünlerine göre değişir. Ürün türü, fiyatı ve teslim alma saatleri için uygulamadaki paket açıklamasını inceleyebilirsin. Alerjin veya özel bir beslenme ihtiyacın varsa sipariş vermeden önce işletmeden bilgi almalısın.",
  },
  {
    q: "Paketim adresime teslim edilir mi?",
    a: "Paketini, siparişte belirtilen saat aralığında doğrudan işletmeden teslim alırsın. Bitir Gitsin’de kurye veya adrese teslim hizmeti bulunmaz. Teslim alma kodunu işletmede göstermen yeterli.",
    href: "/iptal-teslimat-iade#teslimat",
    label: "Teslim alma koşulları",
  },
  {
    q: "Siparişimi iptal edebilir miyim?",
    a: "Teslim alınmamış, iptale uygun siparişini uygulamadaki sipariş detayından iptal edebilirsin. Ödeme yaptıysan iptal işlemiyle birlikte iade süreci başlatılır. Bankana yansıma süresi ödeme kuruluşuna ve bankana göre değişebilir.",
    href: "/iptal-teslimat-iade#iptal",
    label: "İptal ve iade koşulları",
  },
  {
    q: "Paketimle ilgili bir sorun yaşarsam ne yapmalıyım?",
    a: `Sipariş numaran ve yaşadığın sorunun açıklamasıyla ${SITE.email} adresinden bize ulaşabilirsin. Varsa fotoğrafları da ekleyebilirsin. Eksik, bozuk veya siparişe uygun olmayan ürünlere ilişkin yasal hakların saklıdır.`,
    href: "/iptal-teslimat-iade#iade",
    label: "İade ve destek süreci",
  },
];

export default function HomePage() {
  return (
    <>
      <section className={styles.hero} aria-labelledby="hero-title">
        <div className={styles.heroInner}>
          <div className={styles.heroCopy}>
            <p className={styles.eyebrow}>
              <span className={styles.smallDot} /> İYİ YEMEK. İYİ FİYAT. İYİ BİR
              GELECEK.
            </p>
            <h1 id="hero-title" className={styles.heroTitle}>
              İSRAFI AZALT.
              <br />
              LEZZETİ
              <br />
              <span className={styles.heroUnderline}>KURTAR.</span>
            </h1>
            <p className={styles.heroDescription}>
              Mahallendeki güzel lezzetlere bir şans daha ver. Gün sonu sürpriz
              paketlerini keşfet; hem bütçene hem gezegene iyi gelsin.
            </p>
            <div className="flex flex-col gap-3 min-[420px]:flex-row min-[420px]:flex-wrap [&>a]:shrink-0">
              <ButtonLink href="#nasil-calisir" variant="secondary" size="lg">
                Nasıl çalışır? <ArrowDown className="h-4 w-4" />
              </ButtonLink>
              <ButtonLink
                href="/isletmeler-icin"
                variant="outline"
                size="lg"
                className="border-ink/40"
              >
                İşletmeler için <ArrowUpRight className="h-4 w-4" />
              </ButtonLink>
            </div>
            <p className={styles.heroNote}>
              <Leaf className="h-4 w-4" aria-hidden="true" /> Küçük bir seçim,
              güzel bir değişim.
            </p>
          </div>
          <div className={styles.heroVisual}>
            <div className={styles.heroPhoto}>
              <img
                src="/images/surprise-bag.webp"
                width="1536"
                height="1024"
                fetchPriority="high"
                alt="Ekmek, simit, kruvasan ve sebzelerle dolu bir sürpriz paket"
              />
            </div>
            <div className={styles.rescueStamp} aria-hidden="true">
              <span>BİR PAKET</span>
              <Heart size={33} strokeWidth={1.7} />
              <span>BİR İYİLİK</span>
            </div>
            <div className={styles.heroLabel}>
              <span className={styles.labelIcon}>
                <Leaf size={22} />
              </span>
              <span>
                <strong>Fazlası var. İsrafı yok.</strong>
                <small>Bugünün lezzeti, senin sürprizin.</small>
              </span>
            </div>
            <span className={styles.visualCaption}>
              Sürpriz paket içeriği işletmeye ve güne göre değişir.
            </span>
          </div>
        </div>
      </section>

      <div
        className={styles.ticker}
        aria-label="Fırın, restoran, kafe, market, pastane ve manavlardan sürpriz paketler"
      >
        <div className={styles.tickerTrack} aria-hidden="true">
          {[0, 1].map((copy) => (
            <div key={copy}>
              {["FIRIN", "RESTORAN", "KAFE", "MARKET", "PASTANE", "MANAV"].map(
                (item) => (
                  <span key={item}>
                    {item}
                    <span className={styles.tickerStar}>✳</span>
                  </span>
                ),
              )}
            </div>
          ))}
        </div>
      </div>

      <section className={`${styles.section} ${styles.mission}`}>
        <p className={`${styles.eyebrow} text-brand-700`}>
          HER PAKETİN BİR HİKÂYESİ VAR
        </p>
        <h2 className={styles.sectionTitle}>
          GÜZEL YEMEĞİN YERİ
          <br />
          <span className="text-brand-600">ÇÖP DEĞİL.</span>
        </h2>
        <p className={styles.intro}>
          Bir fırının son simidi, bir kafenin son dilimi… Gün bitti diye lezzet
          bitmez. Bitir Gitsin, işletmelerin gün sonunda kalan kaliteli
          ürünlerini uygun fiyatlı sürpriz paketlerle seninle buluşturur.
        </p>
        <div className={styles.benefits}>
          {BENEFITS.map(({ icon: Icon, title, text }) => (
            <div key={title} className={styles.benefit}>
              <span className={styles.benefitIcon}>
                <Icon size={27} strokeWidth={1.5} />
              </span>
              <h3>{title}</h3>
              <p>{text}</p>
            </div>
          ))}
        </div>
      </section>

      <HowItWorks />

      <section className={styles.section}>
        <div className={styles.sectionHeading}>
          <div>
            <p className={`${styles.eyebrow} text-brand-700`}>
              HER GÜN BAŞKA BİR SÜRPRİZ
            </p>
            <h2 className={styles.sectionTitle}>CANIN NE ÇEKERSE.</h2>
          </div>
          <p className={styles.sectionAside}>
            Mahallendeki lezzetlerin tadını çıkar.
            <br />
            Yeni favorin, bir sürpriz pakette olabilir.
          </p>
        </div>
        <div className={styles.categoryGrid}>
          {CATEGORIES.map((category) => (
            <article key={category.type} className={styles.categoryCard}>
              <div className={styles.categoryImage}>
                <img
                  src={`/images/${category.image}`}
                  alt={category.alt}
                  width="720"
                  height="720"
                  loading="lazy"
                />
              </div>
              <div className={styles.categoryBody}>
                <p className={styles.eyebrow}>{category.type}</p>
                <h3>{category.title}</h3>
              </div>
            </article>
          ))}
        </div>
        <p className="mt-5 text-center text-xs text-muted-ink">
          Görseller temsilidir. Paketleri ve güncel içerik bilgilerini mobil
          uygulamada inceleyebilirsin.
        </p>
      </section>

      <section className={styles.businessSection}>
        <div className={styles.businessInner}>
          <div className={styles.businessVisual}>
            <span className={styles.businessCircle} />
            <img
              src="/images/bakery-box.webp"
              alt="Kruvasan, simit ve ekmekten oluşan fırın sürpriz paketi"
              width="640"
              height="640"
              loading="lazy"
            />
            <span className={styles.businessTag}>
              <Store size={20} /> Yerel işletmeler, büyük değişim.
            </span>
          </div>
          <div>
            <p className={`${styles.eyebrow} text-brand-700`}>
              İŞLETMELER İÇİN BİTİR GİTSİN
            </p>
            <h2 className={styles.sectionTitle}>
              EMEĞİN DEĞERLİ.
              <br />
              İSRAF OLMASIN.
            </h2>
            <p className={styles.bodyCopy}>
              Özenle hazırladığın ürünleri gün sonunda sürpriz paketlere
              dönüştür. Yeni müşterilerle tanış, ek gelir elde et, gıda israfını
              birlikte azaltalım.
            </p>
            <ul className={styles.businessList}>
              {[
                "Fazla ürünlerini kazanca dönüştür",
                "Paketlerini ve siparişlerini tek panelden yönet",
                "Teslim alma koduyla kolayca teslim et",
              ].map((text) => (
                <li key={text}>
                  <Check size={18} />
                  {text}
                </li>
              ))}
            </ul>
            <ButtonLink href="/kayit" variant="secondary" size="lg">
              İşletmeni kaydet <ArrowRight size={18} />
            </ButtonLink>
            <Link href="/isletmeler-icin" className={styles.textLink}>
              İşletmeler için tüm avantajlar <ArrowUpRight size={16} />
            </Link>
          </div>
        </div>
      </section>

      <section className={styles.section}>
        <div className={styles.faqGrid}>
          <div>
            <p className={`${styles.eyebrow} text-brand-700`}>
              AKLINDA SORU KALMASIN
            </p>
            <h2 className={styles.sectionTitle}>
              MERAK
              <br />
              ETTİKLERİN.
            </h2>
            <p className={styles.bodyCopy}>
              İlk sürpriz paketinden önce
              <br />
              bilmen gerekenler burada.
            </p>
            <Link href={`mailto:${SITE.email}`} className={styles.textLink}>
              Bize ulaş <ArrowUpRight size={16} />
            </Link>
          </div>
          <div>
            {FAQ.map((item) => (
              <details key={item.q} className={styles.faqItem}>
                <summary>
                  {item.q}
                  <Plus size={20} aria-hidden="true" />
                </summary>
                <div>
                  <p>{item.a}</p>
                  {item.href && (
                    <Link href={item.href} className={styles.textLink}>
                      {item.label} <ArrowRight size={15} />
                    </Link>
                  )}
                </div>
              </details>
            ))}
          </div>
        </div>
      </section>

      <section
        className={styles.paymentSection}
        aria-labelledby="payment-heading"
      >
        <div className={styles.paymentInner}>
          <div className="flex items-start gap-4">
            <ShieldCheck
              className="mt-1 h-8 w-8 shrink-0 text-brand-700"
              strokeWidth={1.5}
            />
            <div>
              <h2 id="payment-heading" className="text-lg font-bold">
                Ödemen güvenle, aklın lezzette.
              </h2>
              <p className="mt-1 text-sm leading-relaxed text-muted-ink">
                Ödemeler iyzico altyapısı üzerinden gerçekleştirilir.
              </p>
              <Link
                href="/iptal-teslimat-iade"
                className="mt-3 inline-flex items-center gap-2 text-xs font-semibold underline underline-offset-4"
              >
                İptal, teslimat ve iade koşulları <ArrowUpRight size={14} />
              </Link>
            </div>
          </div>
          <PaymentMethods />
        </div>
      </section>
    </>
  );
}
