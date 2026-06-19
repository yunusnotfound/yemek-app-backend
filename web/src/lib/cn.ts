/** Koşullu className birleştirici (clsx benzeri minimal sürüm). */
export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}
