"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { packageSchema, type PackageInput } from "@/lib/validations/schemas";
import type { SurprisePackage } from "@/lib/types";
import { createPackage, updatePackage } from "@/lib/api/panel";
import { applyApiError } from "@/lib/api/formErrors";
import { Button } from "@/components/ui/Button";
import { Field, Input, Textarea, Label } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";
import { Card, CardBody } from "@/components/ui/Card";
import { ImageUploader } from "@/components/panel/ImageUploader";

function num(v: number | string | null | undefined): number | undefined {
  if (v == null || v === "") return undefined;
  const n = Number(v);
  return Number.isFinite(n) ? n : undefined;
}

export function PackageForm({
  businessId,
  pkg,
  onSaved,
}: {
  businessId: string;
  pkg?: SurprisePackage;
  onSaved: () => void;
}) {
  const isEdit = Boolean(pkg);
  const [formError, setFormError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<PackageInput>({
    resolver: zodResolver(packageSchema),
    defaultValues: {
      title: pkg?.title ?? "",
      description: pkg?.description ?? "",
      originalPrice: num(pkg?.originalPrice),
      discountedPrice: num(pkg?.discountedPrice),
      quantity: pkg?.quantity ?? undefined,
      pickupDate: pkg?.pickupDate ?? "",
      pickupStart: pkg?.pickupStart?.slice(0, 5) ?? "",
      pickupEnd: pkg?.pickupEnd?.slice(0, 5) ?? "",
      imageUrl: pkg?.imageUrl ?? "",
    },
  });

  const imageUrl = watch("imageUrl");

  async function onSubmit(values: PackageInput) {
    setFormError(null);
    const base: Record<string, unknown> = {
      title: values.title,
      originalPrice: values.originalPrice,
      discountedPrice: values.discountedPrice,
      quantity: values.quantity,
      pickupDate: values.pickupDate,
      pickupStart: values.pickupStart,
      pickupEnd: values.pickupEnd,
    };
    if (values.description) base.description = values.description;
    if (values.imageUrl) base.imageUrl = values.imageUrl;

    try {
      if (isEdit) {
        await updatePackage(pkg!.id, base);
      } else {
        await createPackage({ ...base, businessId });
      }
      onSaved();
    } catch (err) {
      setFormError(applyApiError(err, setError));
    }
  }

  return (
    <Card>
      <CardBody>
        {formError ? (
          <Alert tone="error" className="mb-5">
            {formError}
          </Alert>
        ) : null}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
          <Field label="Paket adı" htmlFor="title" error={errors.title?.message}>
            <Input id="title" placeholder="Örn. Akşam Sürpriz Paketi" {...register("title")} />
          </Field>

          <Field
            label="Açıklama (opsiyonel)"
            htmlFor="description"
            error={errors.description?.message}
          >
            <Textarea
              id="description"
              placeholder="Pakette neler olabileceğine dair ipucu"
              {...register("description")}
            />
          </Field>

          <div className="grid gap-5 sm:grid-cols-3">
            <Field
              label="Orijinal fiyat (₺)"
              htmlFor="originalPrice"
              error={errors.originalPrice?.message}
            >
              <Input
                id="originalPrice"
                type="number"
                step="0.01"
                min="0"
                placeholder="100"
                {...register("originalPrice", { valueAsNumber: true })}
              />
            </Field>
            <Field
              label="İndirimli fiyat (₺)"
              htmlFor="discountedPrice"
              error={errors.discountedPrice?.message}
            >
              <Input
                id="discountedPrice"
                type="number"
                step="0.01"
                min="0"
                placeholder="40"
                {...register("discountedPrice", { valueAsNumber: true })}
              />
            </Field>
            <Field label="Adet" htmlFor="quantity" error={errors.quantity?.message}>
              <Input
                id="quantity"
                type="number"
                min="1"
                placeholder="5"
                {...register("quantity", { valueAsNumber: true })}
              />
            </Field>
          </div>

          <div className="grid gap-5 sm:grid-cols-3">
            <Field
              label="Teslim alma tarihi"
              htmlFor="pickupDate"
              error={errors.pickupDate?.message}
            >
              <Input id="pickupDate" type="date" {...register("pickupDate")} />
            </Field>
            <Field
              label="Başlangıç saati"
              htmlFor="pickupStart"
              error={errors.pickupStart?.message}
            >
              <Input id="pickupStart" type="time" {...register("pickupStart")} />
            </Field>
            <Field
              label="Bitiş saati"
              htmlFor="pickupEnd"
              error={errors.pickupEnd?.message}
            >
              <Input id="pickupEnd" type="time" {...register("pickupEnd")} />
            </Field>
          </div>

          <div>
            <Label>Paket görseli (opsiyonel)</Label>
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
                "Paketi oluştur"
              )}
            </Button>
          </div>
        </form>
      </CardBody>
    </Card>
  );
}
