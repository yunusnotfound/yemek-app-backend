import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";
import { cn } from "@/lib/cn";

type Variant =
  | "primary"
  | "secondary"
  | "light"
  | "outline"
  | "outlineLight"
  | "ghost"
  | "danger";
type Size = "sm" | "md" | "lg";

const VARIANTS: Record<Variant, string> = {
  // Dolu turuncu — birincil eylem
  primary: "bg-brand-600 text-white hover:bg-brand-700 shadow-sm",
  // Koyu pill — krem zeminde ikincil güçlü eylem
  secondary: "bg-ink text-cream hover:bg-ink-700",
  // Açık/krem pill — koyu veya turuncu zeminde (hero)
  light: "bg-white text-ink hover:bg-cream shadow-sm",
  // Çizgili — krem zeminde
  outline: "border-2 border-ink/15 text-ink hover:bg-ink/5",
  // Çizgili — koyu zeminde
  outlineLight: "border-2 border-white/40 text-white hover:bg-white/10",
  ghost: "text-ink hover:bg-ink/5",
  danger: "bg-red-600 text-white hover:bg-red-700",
};

const SIZES: Record<Size, string> = {
  sm: "h-9 px-4 text-sm",
  md: "h-11 px-6 text-sm",
  lg: "h-14 px-8 text-base",
};

const base =
  "inline-flex items-center justify-center gap-2 rounded-full font-bold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600 disabled:opacity-60 disabled:pointer-events-none";

type CommonProps = {
  variant?: Variant;
  size?: Size;
  className?: string;
  children: ReactNode;
};

export function Button({
  variant = "primary",
  size = "md",
  className,
  ...props
}: CommonProps & ComponentProps<"button">) {
  return (
    <button className={cn(base, VARIANTS[variant], SIZES[size], className)} {...props}>
      {props.children}
    </button>
  );
}

export function ButtonLink({
  variant = "primary",
  size = "md",
  className,
  ...props
}: CommonProps & ComponentProps<typeof Link>) {
  return (
    <Link className={cn(base, VARIANTS[variant], SIZES[size], className)} {...props}>
      {props.children}
    </Link>
  );
}
