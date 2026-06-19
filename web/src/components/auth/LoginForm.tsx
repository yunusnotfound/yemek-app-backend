"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { loginSchema, type LoginInput } from "@/lib/validations/schemas";
import { apiFetch } from "@/lib/api/browser";
import { ApiError } from "@/lib/api/errors";
import { applyApiError } from "@/lib/api/formErrors";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";

export function LoginForm({ next }: { next?: string }) {
  const [formError, setFormError] = useState<string | null>(null);
  const [needsVerify, setNeedsVerify] = useState(false);
  const [resendDone, setResendDone] = useState(false);

  const {
    register,
    handleSubmit,
    getValues,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<LoginInput>({ resolver: zodResolver(loginSchema) });

  async function onSubmit(values: LoginInput) {
    setFormError(null);
    setNeedsVerify(false);
    try {
      await apiFetch("/api/auth/login", {
        method: "POST",
        body: JSON.stringify(values),
      });
      window.location.assign(next && next.startsWith("/") ? next : "/panel");
    } catch (err) {
      if (err instanceof ApiError && err.status === 403) {
        setNeedsVerify(true);
        return;
      }
      setFormError(applyApiError(err, setError));
    }
  }

  async function resendVerification() {
    setResendDone(false);
    try {
      await apiFetch("/api/auth/resend-verification", {
        method: "POST",
        body: JSON.stringify({ email: getValues("email") }),
      });
      setResendDone(true);
    } catch {
      setResendDone(true); // numaralandırmayı önlemek için her durumda olumlu mesaj
    }
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-7 shadow-sm sm:p-8">
      <h1 className="text-2xl font-bold text-slate-900">İşletme Girişi</h1>
      <p className="mt-1.5 text-sm text-slate-600">
        Hesabına giriş yaparak işletme paneline ulaş.
      </p>

      {needsVerify ? (
        <Alert tone="warning" className="mt-5">
          E-posta adresin henüz doğrulanmamış. Gelen kutunu kontrol et veya{" "}
          <button
            type="button"
            onClick={resendVerification}
            className="font-semibold underline underline-offset-2"
          >
            doğrulama e-postasını tekrar gönder
          </button>
          .
          {resendDone ? (
            <span className="mt-1 block font-medium">
              Doğrulama e-postası gönderildi (kayıtlıysa).
            </span>
          ) : null}
        </Alert>
      ) : null}

      {formError ? (
        <Alert tone="error" className="mt-5">
          {formError}
        </Alert>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="mt-6 space-y-4" noValidate>
        <Field label="E-posta" htmlFor="email" error={errors.email?.message}>
          <Input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="ornek@isletme.com"
            {...register("email")}
          />
        </Field>

        <Field label="Şifre" htmlFor="password" error={errors.password?.message}>
          <Input
            id="password"
            type="password"
            autoComplete="current-password"
            placeholder="••••••••"
            {...register("password")}
          />
        </Field>

        <div className="flex justify-end">
          <Link
            href="/sifremi-unuttum"
            className="text-sm font-medium text-brand-700 hover:underline"
          >
            Şifremi unuttum
          </Link>
        </div>

        <Button type="submit" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? <Spinner className="h-5 w-5" /> : "Giriş yap"}
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-slate-600">
        Hesabın yok mu?{" "}
        <Link href="/kayit" className="font-semibold text-brand-700 hover:underline">
          İşletme kaydı oluştur
        </Link>
      </p>
    </div>
  );
}
