"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { subMerchantSchema, type SubMerchantInput } from "@/lib/validations/schemas";
import { upsertSubMerchant } from "@/lib/api/panel";
import { applyApiError } from "@/lib/api/formErrors";
import type { SubMerchantSummary, SubMerchantType } from "@/lib/types";
import { Card, CardBody } from "@/components/ui/Card";
import { Field, Input, Select } from "@/components/ui/Field";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";

export function SubMerchantForm({
  businessId,
  current,
  onSaved,
}: {
  businessId: string;
  current?: SubMerchantSummary;
  onSaved: () => void;
}) {
  const [formError, setFormError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    watch,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<SubMerchantInput>({
    resolver: zodResolver(subMerchantSchema),
    defaultValues: {
      subMerchantType: (current?.type as SubMerchantType) ?? "PERSONAL",
    },
  });

  const type = watch("subMerchantType");
  const isPersonal = type === "PERSONAL";
  const isLimited = type === "LIMITED_OR_JOINT_STOCK_COMPANY";

  async function onSubmit(values: SubMerchantInput) {
    setFormError(null);
    try {
      await upsertSubMerchant(businessId, values);
      onSaved();
    } catch (err) {
      setFormError(applyApiError(err, setError));
    }
  }

  return (
    <Card>
      <CardBody>
        <h2 className="text-lg font-semibold text-slate-900">Ödeme Hesabı Bilgileri</h2>
        <p className="mt-1 text-sm text-slate-600">
          Satış gelirleriniz iyzico tarafından bu hesaba (IBAN) ödenir. Bilgiler iyzico&apos;ya
          gönderilir.
        </p>

        {formError ? (
          <Alert tone="error" className="mt-5">
            {formError}
          </Alert>
        ) : null}

        <form onSubmit={handleSubmit(onSubmit)} className="mt-5 space-y-4" noValidate>
          <Field label="İşletme türü" htmlFor="subMerchantType" error={errors.subMerchantType?.message}>
            <Select id="subMerchantType" {...register("subMerchantType")}>
              <option value="PERSONAL">Şahıs / Bireysel</option>
              <option value="PRIVATE_COMPANY">Şahıs Şirketi</option>
              <option value="LIMITED_OR_JOINT_STOCK_COMPANY">Limited / Anonim Şirket</option>
            </Select>
          </Field>

          <Field
            label="IBAN"
            htmlFor="iban"
            error={errors.iban?.message}
            hint="TR ile başlayan 26 haneli IBAN."
          >
            <Input id="iban" placeholder="TR00 0000 0000 0000 0000 0000 00" {...register("iban")} />
          </Field>

          <Field label="Telefon" htmlFor="gsmNumber" error={errors.gsmNumber?.message}>
            <Input id="gsmNumber" placeholder="+90 5xx xxx xx xx" {...register("gsmNumber")} />
          </Field>

          {isPersonal ? (
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Ad" htmlFor="contactName" error={errors.contactName?.message}>
                <Input id="contactName" {...register("contactName")} />
              </Field>
              <Field label="Soyad" htmlFor="contactSurname" error={errors.contactSurname?.message}>
                <Input id="contactSurname" {...register("contactSurname")} />
              </Field>
              <Field
                label="TC Kimlik No"
                htmlFor="identityNumber"
                error={errors.identityNumber?.message}
              >
                <Input id="identityNumber" inputMode="numeric" maxLength={11} {...register("identityNumber")} />
              </Field>
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2">
              <Field
                label="Yasal şirket ünvanı"
                htmlFor="legalCompanyTitle"
                error={errors.legalCompanyTitle?.message}
              >
                <Input id="legalCompanyTitle" {...register("legalCompanyTitle")} />
              </Field>
              <Field label="Vergi dairesi" htmlFor="taxOffice" error={errors.taxOffice?.message}>
                <Input id="taxOffice" {...register("taxOffice")} />
              </Field>
              <Field
                label={isLimited ? "Vergi no (10 hane)" : "Vergi no (opsiyonel)"}
                htmlFor="taxNumber"
                error={errors.taxNumber?.message}
              >
                <Input id="taxNumber" inputMode="numeric" {...register("taxNumber")} />
              </Field>
            </div>
          )}

          <div className="flex justify-end pt-1">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? <Spinner className="h-5 w-5" /> : "Kaydet"}
            </Button>
          </div>
        </form>
      </CardBody>
    </Card>
  );
}
