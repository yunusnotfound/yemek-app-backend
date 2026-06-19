/** Backend hata yanıtlarını taşıyan ortak hata tipi. */
export interface FieldError {
  field: string;
  message: string;
}

export class ApiError extends Error {
  status: number;
  fieldErrors?: FieldError[];

  constructor(message: string, status: number, fieldErrors?: FieldError[]) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.fieldErrors = fieldErrors;
  }
}

/** Backend'in döndürdüğü { message, errors? } gövdesinden ApiError üretir. */
export function apiErrorFromBody(
  status: number,
  body: { message?: string; errors?: FieldError[] } | null,
): ApiError {
  return new ApiError(
    body?.message || "Beklenmeyen bir hata oluştu",
    status,
    body?.errors,
  );
}
