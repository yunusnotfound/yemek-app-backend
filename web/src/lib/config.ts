/**
 * Uygulama yapılandırması. Sunucu-tarafı değerler yalnızca server bileşenlerinde /
 * route handler'larında okunur; tarayıcıya yalnızca NEXT_PUBLIC_* değerleri gider.
 */

/** Express backend'in temel URL'i ("/api" ile biter). Yalnızca sunucu tarafında kullanılır. */
export const BACKEND_API_URL =
  process.env.BACKEND_API_URL?.replace(/\/$/, "") || "http://localhost:3000/api";

/** Mapbox token (işletme konum seçici). Boşsa harita yerine elle giriş gösterilir. */
export const MAPBOX_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN || "";

/** Marka bilgileri (tek kaynak). */
export const SITE = {
  name: "Bitir Yemek",
  tagline: "İsrafı azalt, lezzeti kurtar.",
  description:
    "Bitir Yemek, restoran ve işletmelerin gün sonunda kalan lezzetlerini uygun fiyatlı sürpriz paketlerle satışa sunmasını sağlayan bir gıda israfını önleme platformudur.",
  email: "iletisim@bitirgitsin.com",
} as const;
