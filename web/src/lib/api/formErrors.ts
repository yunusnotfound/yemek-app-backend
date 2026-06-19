import type { FieldValues, Path, UseFormSetError } from "react-hook-form";
import { ApiError } from "@/lib/api/errors";

/**
 * Backend hatasını react-hook-form'a uygular.
 * Alan hataları varsa inline gösterilir ve null döner; aksi halde üstte
 * gösterilecek genel mesaj döner.
 */
export function applyApiError<T extends FieldValues>(
  err: unknown,
  setError: UseFormSetError<T>,
): string | null {
  if (err instanceof ApiError) {
    if (err.fieldErrors?.length) {
      for (const fe of err.fieldErrors) {
        setError(fe.field as Path<T>, { message: fe.message });
      }
      return null;
    }
    return err.message;
  }
  return "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.";
}
