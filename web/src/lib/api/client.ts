import "server-only";
import { BACKEND_API_URL } from "@/lib/config";

/**
 * Express backend'e yapılan düşük seviye fetch (yalnızca sunucu tarafı).
 * Token ekleme/refresh üst katmanlarda (route handler'lar) yapılır.
 */
export async function callBackend(
  path: string,
  init: RequestInit & { token?: string } = {},
): Promise<Response> {
  const { token, headers, ...rest } = init;
  const h = new Headers(headers);
  if (token) h.set("Authorization", `Bearer ${token}`);

  try {
    return await fetch(`${BACKEND_API_URL}${path}`, {
      ...rest,
      headers: h,
      cache: "no-store",
    });
  } catch {
    // Backend'e ulaşılamadı (ağ/bağlantı hatası) → her tüketicinin tek biçimde
    // işleyebilmesi için sentetik 502 JSON yanıtı döndür.
    return new Response(
      JSON.stringify({ message: "Sunucuya şu anda ulaşılamıyor. Lütfen tekrar deneyin." }),
      { status: 502, headers: { "content-type": "application/json" } },
    );
  }
}

/** JSON gövdeli backend isteği için kısa yol. */
export async function callBackendJson(
  path: string,
  method: string,
  body: unknown,
  token?: string,
): Promise<Response> {
  return callBackend(path, {
    method,
    token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}
