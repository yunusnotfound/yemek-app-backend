import { ApiError, type FieldError } from "@/lib/api/errors";

/**
 * Tarayıcı (client component) tarafı fetch yardımcısı.
 * Yalnızca Next'in kendi route handler'larıyla (same-origin) konuşur;
 * backend'e doğrudan gitmez. Token'lar httpOnly çerezde olduğundan
 * burada token yönetimi yoktur.
 */
async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    headers: {
      ...(init?.body && !(init.body instanceof FormData)
        ? { "Content-Type": "application/json" }
        : {}),
      ...init?.headers,
    },
  });

  type ResBody = Record<string, unknown> & { message?: string; errors?: FieldError[] };
  let body: ResBody | null = null;
  try {
    body = (await res.json()) as ResBody;
  } catch {
    body = null;
  }

  if (!res.ok) {
    throw new ApiError(body?.message || "Bir hata oluştu", res.status, body?.errors);
  }
  return body as T;
}

/** Next BFF auth/route handler'larına istek (örn. /api/auth/login). */
export function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  return request<T>(path, init);
}

/**
 * Kimlik doğrulamalı backend isteklerini Next proxy'si üzerinden yapar.
 * path örn. "/business-dashboard/my-businesses". 401'de giriş sayfasına yönlendirir.
 */
export async function proxyFetch<T>(path: string, init?: RequestInit): Promise<T> {
  try {
    return await request<T>(`/api/proxy${path}`, init);
  } catch (err) {
    if (err instanceof ApiError && err.status === 401 && typeof window !== "undefined") {
      window.location.href = "/giris";
    }
    throw err;
  }
}
