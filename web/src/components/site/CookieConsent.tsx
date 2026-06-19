"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Cookie } from "lucide-react";
import { Button } from "@/components/ui/Button";

const STORAGE_KEY = "bg_cookie_consent";

/**
 * Çerez bildirimi. Site yalnızca temel (giriş/oturum) çerezleri kullandığından
 * bilgilendirme amaçlıdır; seçim localStorage'da saklanır, tekrar gösterilmez.
 * (Tercih çerez yerine localStorage'da tutulur ki bildirimin kendisi için çerez gerekmesin.)
 */
export function CookieConsent() {
  const [show, setShow] = useState(false);

  // SSR/hydration uyumsuzluğunu önlemek için yalnızca mount sonrası karar ver.
  useEffect(() => {
    try {
      if (!localStorage.getItem(STORAGE_KEY)) setShow(true);
    } catch {
      /* localStorage engelliyse bildirimi gösterme */
    }
  }, []);

  function decide(value: "accepted" | "rejected") {
    try {
      localStorage.setItem(STORAGE_KEY, value);
    } catch {
      /* yoksay */
    }
    setShow(false);
  }

  if (!show) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 p-4 sm:p-6">
      <div className="mx-auto flex max-w-3xl flex-col gap-4 rounded-2xl border border-ink/10 bg-white p-5 shadow-xl sm:flex-row sm:items-center sm:gap-5 sm:p-6">
        <div className="flex items-start gap-3">
          <span className="mt-0.5 grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-brand-100 text-brand-700">
            <Cookie className="h-5 w-5" />
          </span>
          <p className="text-sm leading-relaxed text-ink/70">
            Giriş ve oturum gibi <strong className="font-semibold text-ink">temel işlevler</strong>{" "}
            için çerez kullanıyoruz. Reklam veya takip çerezi kullanmıyoruz. Ayrıntılar için{" "}
            <Link
              href="/cerez-politikasi"
              className="font-semibold text-brand-700 underline underline-offset-2 hover:text-brand-800"
            >
              Çerez Politikası
            </Link>
            .
          </p>
        </div>
        <div className="flex shrink-0 gap-2 sm:ml-auto">
          <Button variant="outline" size="sm" onClick={() => decide("rejected")}>
            Reddet
          </Button>
          <Button size="sm" onClick={() => decide("accepted")}>
            Kabul et
          </Button>
        </div>
      </div>
    </div>
  );
}
