"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  forgotPasswordSchema,
  type ForgotPasswordInput,
} from "@/lib/validations/schemas";
import { apiFetch } from "@/lib/api/browser";
import { applyApiError } from "@/lib/api/formErrors";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";

export function ForgotPasswordForm() {
  const [sent, setSent] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<ForgotPasswordInput>({
    resolver: zodResolver(forgotPasswordSchema),
  });

  async function onSubmit(values: ForgotPasswordInput) {
    setFormError(null);
    try {
      await apiFetch("/api/auth/forgot-password", {
        method: "POST",
        body: JSON.stringify(values),
      });
      setSent(true);
    } catch (err) {
      setFormError(applyApiError(err, setError));
    }
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-7 shadow-sm sm:p-8">
      <h1 className="text-2xl font-bold text-slate-900">Şifremi unuttum</h1>
      <p className="mt-1.5 text-sm text-slate-600">
        E-posta adresine 6 haneli bir sıfırlama kodu gönderelim.
      </p>

      {sent ? (
        <div className="mt-6 space-y-4">
          <Alert tone="success">
            Eğer bu e-posta kayıtlıysa, sıfırlama kodu gönderildi. Kod 15 dakika
            geçerlidir.
          </Alert>
          <ButtonLink href="/sifre-sifirla" className="w-full">
            Kodu girip şifre belirle
          </ButtonLink>
        </div>
      ) : (
        <>
          {formError ? (
            <Alert tone="error" className="mt-5">
              {formError}
            </Alert>
          ) : null}
          <form
            onSubmit={handleSubmit(onSubmit)}
            className="mt-6 space-y-4"
            noValidate
          >
            <Field label="E-posta" htmlFor="email" error={errors.email?.message}>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                placeholder="ornek@isletme.com"
                {...register("email")}
              />
            </Field>
            <Button type="submit" className="w-full" disabled={isSubmitting}>
              {isSubmitting ? <Spinner className="h-5 w-5" /> : "Sıfırlama kodu gönder"}
            </Button>
          </form>
        </>
      )}

      <p className="mt-6 text-center text-sm text-slate-600">
        <Link href="/giris" className="font-semibold text-brand-700 hover:underline">
          Girişe dön
        </Link>
      </p>
    </div>
  );
}
