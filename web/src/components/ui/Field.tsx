import type { ComponentProps, ReactNode } from "react";
import { cn } from "@/lib/cn";

const controlBase =
  "w-full min-h-11 rounded-xl border border-surface-border bg-surface px-3.5 py-2.5 text-sm text-ink placeholder:text-muted-ink transition-[border-color,box-shadow] motion-reduce:transition-none hover:border-brand-200 focus:border-brand-600 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:bg-surface-muted disabled:text-muted-ink disabled:cursor-not-allowed aria-invalid:border-red-600 aria-invalid:focus:ring-red-500/20";

export function Input({ className, ...props }: ComponentProps<"input">) {
  return <input className={cn(controlBase, className)} {...props} />;
}

export function Textarea({ className, ...props }: ComponentProps<"textarea">) {
  return <textarea className={cn(controlBase, "min-h-24", className)} {...props} />;
}

export function Select({ className, ...props }: ComponentProps<"select">) {
  return <select className={cn(controlBase, className)} {...props} />;
}

export function Label({ className, ...props }: ComponentProps<"label">) {
  return (
    <label
      className={cn("mb-1.5 block text-sm font-medium text-slate-700", className)}
      {...props}
    />
  );
}

export function FieldError({ children }: { children?: ReactNode }) {
  if (!children) return null;
  return <p className="mt-1.5 text-sm text-red-600">{children}</p>;
}

export function Field({
  label,
  htmlFor,
  error,
  hint,
  children,
}: {
  label?: string;
  htmlFor?: string;
  error?: ReactNode;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div>
      {label ? <Label htmlFor={htmlFor}>{label}</Label> : null}
      {children}
      {hint && !error ? <p className="mt-1.5 text-sm text-slate-500">{hint}</p> : null}
      <FieldError>{error}</FieldError>
    </div>
  );
}
