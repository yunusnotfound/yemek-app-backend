"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { resetPasswordSchema } from "@/lib/validations/schemas";
import { apiFetch } from "@/lib/api/browser";
import { applyApiError } from "@/lib/api/formErrors";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";

const formSchema = resetPasswordSchema
  .extend({ passwordConfirm: z.string().min(1, "Şifre tekrarı gerekli") })
  .refine((d) => d.password === d.passwordConfirm, {
    message: "Şifreler eşleşmiyor",
    path: ["passwordConfirm"],
  });
type FormValues = z.infer<typeof formSchema>;

export function ResetPasswordForm() {
  const [done, setDone] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(formSchema) });

  async function onSubmit(values: FormValues) {
    setFormError(null);
    try {
      await apiFetch("/api/auth/reset-password", {
        method: "POST",
        body: JSON.stringify({ token: values.token, password: values.password }),
      });
      setDone(true);
    } catch (err) {
      setFormError(applyApiError(err, setError));
    }
  }

  if (done) {
    return (
      <div className="rounded-2xl border border-slate-200 bg-white p-7 shadow-sm sm:p-8">
        <Alert tone="success">Şifren başarıyla değiştirildi.</Alert>
        <Link
          href="/giris"
          className="mt-5 inline-block font-semibold text-brand-700 hover:underline"
        >
          Giriş yap →
        </Link>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-7 shadow-sm sm:p-8">
      <h1 className="text-2xl font-bold text-slate-900">Yeni şifre belirle</h1>
      <p className="mt-1.5 text-sm text-slate-600">
        E-postana gelen 6 haneli kodu ve yeni şifreni gir.
      </p>

      {formError ? (
        <Alert tone="error" className="mt-5">
          {formError}
        </Alert>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="mt-6 space-y-4" noValidate>
        <Field label="Sıfırlama kodu" htmlFor="token" error={errors.token?.message}>
          <Input
            id="token"
            inputMode="numeric"
            placeholder="6 haneli kod"
            {...register("token")}
          />
        </Field>
        <Field
          label="Yeni şifre"
          htmlFor="password"
          error={errors.password?.message}
          hint="En az 8 karakter."
        >
          <Input
            id="password"
            type="password"
            autoComplete="new-password"
            placeholder="••••••••"
            {...register("password")}
          />
        </Field>
        <Field
          label="Yeni şifre tekrar"
          htmlFor="passwordConfirm"
          error={errors.passwordConfirm?.message}
        >
          <Input
            id="passwordConfirm"
            type="password"
            autoComplete="new-password"
            placeholder="••••••••"
            {...register("passwordConfirm")}
          />
        </Field>
        <Button type="submit" className="w-full" disabled={isSubmitting}>
          {isSubmitting ? <Spinner className="h-5 w-5" /> : "Şifreyi değiştir"}
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-slate-600">
        Kod gelmedi mi?{" "}
        <Link
          href="/sifremi-unuttum"
          className="font-semibold text-brand-700 hover:underline"
        >
          Tekrar gönder
        </Link>
      </p>
    </div>
  );
}
