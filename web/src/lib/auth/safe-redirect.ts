export function safeLocalPath(value: unknown, fallback = "/panel"): string {
  if (typeof value !== "string" || !value.startsWith("/") ||
      /[\u0000-\u0020\u007f\\]/.test(value)) return fallback;
  try {
    const url = new URL(value, "https://local.invalid");
    return url.origin === "https://local.invalid" ? value : fallback;
  } catch { return fallback; }
}
