"use client";

import { useRef, useState } from "react";
import { ImagePlus, Trash2 } from "lucide-react";
import { uploadImage } from "@/lib/api/panel";
import { ApiError } from "@/lib/api/errors";
import { Spinner } from "@/components/ui/Spinner";

/**
 * Tek görsel yükleyici. Yükleme sonrası backend mutlak URL döndürür ve
 * onChange ile forma yazılır (imageUrl alanı).
 */
export function ImageUploader({
  value,
  onChange,
}: {
  value?: string;
  onChange: (url: string) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setBusy(true);
    setError(null);
    try {
      const { url } = await uploadImage(file);
      onChange(url);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Görsel yüklenemedi");
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <div>
      <div className="flex items-center gap-4">
        <div className="grid h-20 w-20 shrink-0 place-items-center overflow-hidden rounded-xl border border-slate-200 bg-slate-50">
          {value ? (
            <img src={value} alt="" className="h-full w-full object-cover" />
          ) : (
            <ImagePlus className="h-6 w-6 text-slate-400" />
          )}
        </div>
        <div className="flex flex-col gap-2">
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            disabled={busy}
            className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-60"
          >
            {busy ? <Spinner className="h-4 w-4" /> : <ImagePlus className="h-4 w-4" />}
            {value ? "Görseli değiştir" : "Görsel yükle"}
          </button>
          {value ? (
            <button
              type="button"
              onClick={() => onChange("")}
              className="inline-flex items-center gap-1.5 text-sm font-medium text-red-600 hover:underline"
            >
              <Trash2 className="h-4 w-4" /> Kaldır
            </button>
          ) : (
            <span className="text-xs text-slate-500">JPEG, PNG veya WebP · en fazla 5MB</span>
          )}
        </div>
      </div>
      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={handleFile}
        className="hidden"
      />
      {error ? <p className="mt-2 text-sm text-red-600">{error}</p> : null}
    </div>
  );
}
