"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { businessSchema, type BusinessInput } from "@/lib/validations/schemas";
import type { Business, Category } from "@/lib/types";
import {
  createBusiness,
  updateBusiness,
  getCategories,
} from "@/lib/api/panel";
import { applyApiError } from "@/lib/api/formErrors";
import { Button } from "@/components/ui/Button";
import { Field, Input, Textarea, Select, Label } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";
import { Card, CardBody } from "@/components/ui/Card";
import { ImageUploader } from "@/components/panel/ImageUploader";
import { LocationPicker } from "@/components/panel/LocationPicker";
import { MAPBOX_TOKEN } from "@/lib/config";

function num(v: number | string | null | undefined): number | undefined {
  if (v == null || v === "") return undefined;
  const n = Number(v);
  return Number.isFinite(n) ? n : undefined;
}

export function BusinessForm({
  business,
  onSaved,
}: {
  business?: Business;
  onSaved: (b: Business) => void;
}) {
  const isEdit = Boolean(business);
  const [categories, setCategories] = useState<Category[]>([]);
  const [formError, setFormError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<BusinessInput>({
    resolver: zodResolver(businessSchema),
    defaultValues: {
      name: business?.name ?? "",
      description: business?.description ?? "",
      address: business?.address ?? "",
      city: business?.city ?? "",
      district: business?.district ?? "",
      latitude: num(business?.latitude),
      longitude: num(business?.longitude),
      phone: business?.phone ?? "",
      imageUrl: business?.imageUrl ?? "",
      categoryId: business?.categoryId,
    },
  });

  useEffect(() => {
    getCategories()
      .then((res) => setCategories(res.categories))
      .catch(() => {});
  }, []);

  const lat = watch("latitude");
  const lng = watch("longitude");
  const imageUrl = watch("imageUrl");

  async function onSubmit(values: BusinessInput) {
    setFormError(null);
    setSuccess(null);
    const payload: Record<string, unknown> = {
      name: values.name,
      address: values.address,
      city: values.city,
      district: values.district,
      latitude: values.latitude,
      longitude: values.longitude,
      categoryId: values.categoryId,
    };
    if (values.description) payload.description = values.description;
    if (values.phone) payload.phone = values.phone;
    if (values.imageUrl) payload.imageUrl = values.imageUrl;

    try {
      const res = isEdit
        ? await updateBusiness(business!.id, payload)
        : await createBusiness(payload);
      setSuccess(
        isEdit
          ? "İşletme bilgileri güncellendi."
          : "İşletmen oluşturuldu. Yönetici onayından sonra yayına alınacak.",
      );
      onSaved(res.business);
    } catch (err) {
      setFormError(applyApiError(err, setError));
    }
  }

  return (
    <Card>
      <CardBody>
        {success ? (
          <Alert tone="success" className="mb-5">
            {success}
          </Alert>
        ) : null}
        {formError ? (
          <Alert tone="error" className="mb-5">
            {formError}
          </Alert>
        ) : null}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
          <Field label="İşletme adı" htmlFor="name" error={errors.name?.message}>
            <Input id="name" placeholder="Örn. Lezzet Fırını" {...register("name")} />
          </Field>

          <Field
            label="Açıklama (opsiyonel)"
            htmlFor="description"
            error={errors.description?.message}
          >
            <Textarea
              id="description"
              placeholder="İşletmen hakkında kısa bir tanıtım"
              {...register("description")}
            />
          </Field>

          <div className="grid gap-5 sm:grid-cols-2">
            <Field label="Kategori" htmlFor="categoryId" error={errors.categoryId?.message}>
              <Select
                id="categoryId"
                {...register("categoryId", { valueAsNumber: true })}
                defaultValue={business?.categoryId ?? ""}
              >
                <option value="" disabled>
                  Kategori seç
                </option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Telefon (opsiyonel)" htmlFor="phone" error={errors.phone?.message}>
              <Input
                id="phone"
                type="tel"
                placeholder="5XX XXX XX XX"
                {...register("phone")}
              />
            </Field>
          </div>

          <Field label="Adres" htmlFor="address" error={errors.address?.message}>
            <Input id="address" placeholder="Açık adres" {...register("address")} />
          </Field>

          <div className="grid gap-5 sm:grid-cols-2">
            <Field label="Şehir" htmlFor="city" error={errors.city?.message}>
              <Input id="city" placeholder="Örn. İstanbul" {...register("city")} />
            </Field>
            <Field label="İlçe" htmlFor="district" error={errors.district?.message}>
              <Input id="district" placeholder="Örn. Kadıköy" {...register("district")} />
            </Field>
          </div>

          {/* Konum */}
          <div>
            <Label>Konum</Label>
            {MAPBOX_TOKEN ? (
              <>
                <p className="mb-2 text-sm text-slate-500">
                  Haritada tıklayarak veya işaretçiyi sürükleyerek konumu seç.
                </p>
                <LocationPicker
                  lat={num(lat)}
                  lng={num(lng)}
                  onChange={(la, lo) => {
                    setValue("latitude", la, { shouldValidate: true });
                    setValue("longitude", lo, { shouldValidate: true });
                  }}
                />
              </>
            ) : (
              <p className="mb-2 text-sm text-slate-500">
                Enlem ve boylamı elle gir (harita için Mapbox anahtarı tanımlı değil).
              </p>
            )}
            <div className="mt-3 grid gap-5 sm:grid-cols-2">
              <Field label="Enlem" htmlFor="latitude" error={errors.latitude?.message}>
                <Input
                  id="latitude"
                  type="number"
                  step="any"
                  placeholder="41.0082"
                  {...register("latitude", { valueAsNumber: true })}
                />
              </Field>
              <Field label="Boylam" htmlFor="longitude" error={errors.longitude?.message}>
                <Input
                  id="longitude"
                  type="number"
                  step="any"
                  placeholder="28.9784"
                  {...register("longitude", { valueAsNumber: true })}
                />
              </Field>
            </div>
          </div>

          {/* Görsel */}
          <div>
            <Label>İşletme görseli (opsiyonel)</Label>
            <ImageUploader
              value={imageUrl || ""}
              onChange={(url) => setValue("imageUrl", url, { shouldValidate: true })}
            />
          </div>

          <div className="flex justify-end pt-2">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? (
                <Spinner className="h-5 w-5" />
              ) : isEdit ? (
                "Değişiklikleri kaydet"
              ) : (
                "İşletmeyi oluştur"
              )}
            </Button>
          </div>
        </form>
      </CardBody>
    </Card>
  );
}
