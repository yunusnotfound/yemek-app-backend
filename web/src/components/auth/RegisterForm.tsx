"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { registerSchema } from "@/lib/validations/schemas";
import { apiFetch } from "@/lib/api/browser";
import { applyApiError } from "@/lib/api/formErrors";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { Spinner } from "@/components/ui/Spinner";

// Şifre tekrarı yalnız istemci tarafında doğrulanır (backend'e gönderilmez).
const formSchema = registerSchema
  .extend({ passwordConfirm: z.string().min(1, "Şifre tekrarı gerekli") })
  .refine((d) => d.password === d.passwordConfirm, {
    message: "Şifreler eşleşmiyor",
    path: ["passwordConfirm"],
  });
type FormValues = z.infer<typeof formSchema>;

export function RegisterForm() {
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
      await apiFetch("/api/auth/register", {
        method: "POST",
        body: JSON.stringify({
          name: values.name,
          email: values.email,
          password: values.password,
          phone: values.phone || undefined,
        }),
      });
      // Kayıt başarılı → oturum kuruldu. Panele git (e-posta doğrulama uyarısı orada).
      window.location.assign("/panel?welcome=1");
    } catch (err) {
      setFormError(applyApiError(err, setError));
    }
  }

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-7 shadow-sm sm:p-8">
      <h1 className="text-2xl font-bold text-slate-900">İşletme Kaydı</h1>
      <p className="mt-1.5 text-sm text-slate-600">
        Ücretsiz işletme hesabı oluştur, paketlerini yönetmeye başla.
      </p>

      {formError ? (
        <Alert tone="error" className="mt-5">
          {formError}
        </Alert>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="mt-6 space-y-4" noValidate>
        <Field label="Ad soyad" htmlFor="name" error={errors.name?.message}>
          <Input
            id="name"
            autoComplete="name"
            placeholder="Yetkili adı soyadı"
            {...register("name")}
          />
        </Field>

        <Field label="E-posta" htmlFor="email" error={errors.email?.message}>
          <Input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="ornek@isletme.com"
            {...register("email")}
          />
        </Field>

        <Field
          label="Telefon (opsiyonel)"
          htmlFor="phone"
          error={errors.phone?.message}
        >
          <Input
            id="phone"
            type="tel"
            autoComplete="tel"
            placeholder="5XX XXX XX XX"
            {...register("phone")}
          />
        </Field>

        <Field
          label="Şifre"
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
          label="Şifre tekrar"
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
          {isSubmitting ? <Spinner className="h-5 w-5" /> : "Hesap oluştur"}
        </Button>

        <p className="text-center text-xs text-slate-500">
          Kaydolarak hizmet koşullarını kabul etmiş olursun. İşletmen yönetici
          onayından sonra yayına alınır.
        </p>
      </form>

      <p className="mt-6 text-center text-sm text-slate-600">
        Zaten hesabın var mı?{" "}
        <Link href="/giris" className="font-semibold text-brand-700 hover:underline">
          Giriş yap
        </Link>
      </p>
    </div>
  );
}
