"use client";

import { useRef, useState, type KeyboardEvent } from "react";
import Link from "next/link";
import {
  ArrowUpRight,
  Check,
  Clock,
  MapPin,
  ShieldCheck,
  ShoppingBag,
} from "lucide-react";
import styles from "./HowItWorks.module.css";

const STEPS = [
  {
    label: "Keşfet",
    title: "YAKININDAKİ\nLEZZETLERİ BUL.",
    text: "Bitir Gitsin mobil uygulamasında çevrendeki işletmeleri keşfet. Sana uygun sürpriz paketi seç; içeriğini, fiyatını ve teslim alma saatini incele.",
    note: "Fırın, kafe, restoran ve daha fazlası.",
    icon: MapPin,
  },
  {
    label: "Ayırt",
    title: "PAKETİNİ SEÇ.\nYERİNİ AYIRT.",
    text: "Seçtiğin paketin ödemesini uygulama üzerinden tamamla. Siparişin ve teslim alma kodun, ihtiyaç duyduğunda sipariş detayında seni bekler.",
    note: "iyzico altyapısı üzerinden ödeme.",
    icon: ShieldCheck,
  },
  {
    label: "Teslim al",
    title: "UĞRA, TESLİM AL.\nAFİYET OLSUN.",
    text: "Belirtilen saat aralığında işletmeye git. Teslim alma kodunu göster, paketini al. Güzel bir lezzeti israf olmaktan birlikte kurtarmış olalım.",
    note: "İşletmeden teslim al, lezzetin tadını çıkar.",
    icon: ShoppingBag,
  },
];

export function HowItWorks() {
  const [active, setActive] = useState(0);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const step = STEPS[active];
  const Icon = step.icon;

  function onKeyDown(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    let next: number;
    if (event.key === "ArrowRight") next = (index + 1) % STEPS.length;
    else if (event.key === "ArrowLeft")
      next = (index + STEPS.length - 1) % STEPS.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = STEPS.length - 1;
    else return;
    event.preventDefault();
    setActive(next);
    tabs.current[next]?.focus();
  }

  return (
    <section
      id="nasil-calisir"
      className={styles.section}
      aria-labelledby="steps-title"
    >
      <div className={styles.inner}>
        <div className={styles.heading}>
          <p>ÜÇ KÜÇÜK ADIM, GÜZEL BİR DEĞİŞİM</p>
          <h2 id="steps-title">
            LEZZET KURTARMAK
            <br />
            BU KADAR KOLAY.
          </h2>
        </div>
        <div
          className={styles.tabs}
          role="tablist"
          aria-label="Bitir Gitsin nasıl çalışır?"
        >
          {STEPS.map((item, index) => (
            <button
              key={item.label}
              ref={(element) => {
                tabs.current[index] = element;
              }}
              type="button"
              role="tab"
              id={`step-tab-${index}`}
              aria-controls="step-panel"
              aria-selected={active === index}
              tabIndex={active === index ? 0 : -1}
              onKeyDown={(event) => onKeyDown(event, index)}
              onClick={() => setActive(index)}
            >
              <span>0{index + 1}</span>
              {item.label}
              <ArrowUpRight size={18} aria-hidden="true" />
            </button>
          ))}
        </div>
        <div
          className={styles.panel}
          role="tabpanel"
          id="step-panel"
          aria-labelledby={`step-tab-${active}`}
          tabIndex={0}
        >
          <div className={styles.copy}>
            <span className={styles.stepNumber}>0{active + 1}</span>
            <h3>{step.title}</h3>
            <p>{step.text}</p>
            <span className={styles.note}>
              <Icon size={18} aria-hidden="true" />
              {step.note}
            </span>
            <Link href="/nasil-calisir">
              Tüm adımları incele <ArrowUpRight size={15} />
            </Link>
          </div>
          <div className={styles.visual}>
            {active === 0 && (
              <div className={styles.exampleCard}>
                <div className={styles.exampleImage}>
                  <img
                    src="/images/bakery.webp"
                    alt="Fırın sürpriz paketindeki simit ve ekmekler"
                    width="720"
                    height="720"
                    loading="lazy"
                  />
                  <span>ÖRNEK PAKET</span>
                </div>
                <div className={styles.exampleBody}>
                  <span>
                    <MapPin size={13} /> Mahallendeki fırın
                  </span>
                  <h4>Günün sürpriz paketi</h4>
                  <p>
                    <Clock size={14} /> Teslim alma saatini incele
                  </p>
                  <div className={styles.cardFooter}>
                    <span>Güzel lezzetler, uygun fiyatlar.</span>
                    <ArrowUpRight size={18} />
                  </div>
                </div>
              </div>
            )}
            {active === 1 && (
              <div className={styles.paymentCard}>
                <span className={styles.checkCircle}>
                  <ShieldCheck size={42} strokeWidth={1.5} />
                </span>
                <p className={styles.visualEyebrow}>
                  ÖNCE AYIRT, SONRA TESLİM AL
                </p>
                <h4>
                  Sürprizin
                  <br />
                  seni beklesin.
                </h4>
                <ul>
                  <li>
                    <Check size={17} /> Paketini ve teslim saatini kontrol et
                  </li>
                  <li>
                    <Check size={17} /> Ödemeni uygulamada tamamla
                  </li>
                  <li>
                    <Check size={17} /> Teslim alma kodunu sakla
                  </li>
                </ul>
              </div>
            )}
            {active === 2 && (
              <div className={styles.bagVisual}>
                <span className={styles.bagCircle} />
                <img
                  src="/images/rescue-bag.webp"
                  alt="İşletmeden teslim alınan kraft sürpriz paket poşeti"
                  width="660"
                  height="660"
                  loading="lazy"
                />
                <span className={styles.bagCaption}>
                  <Check size={17} /> Bir paket daha kurtarıldı!
                </span>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
