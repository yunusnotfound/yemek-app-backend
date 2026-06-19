import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import type { OrderStatus } from "@/lib/types";

type Tone = "green" | "amber" | "slate" | "blue" | "red";

const TONES: Record<Tone, string> = {
  green: "bg-brand-100 text-brand-800",
  amber: "bg-amber-100 text-amber-800",
  slate: "bg-slate-100 text-slate-700",
  blue: "bg-blue-100 text-blue-800",
  red: "bg-red-100 text-red-700",
};

export function Badge({
  tone = "slate",
  className,
  children,
}: {
  tone?: Tone;
  className?: string;
  children: ReactNode;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
        TONES[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

const ORDER_TONES: Record<OrderStatus, Tone> = {
  pending: "amber",
  confirmed: "blue",
  picked_up: "green",
  cancelled: "red",
};

export function orderTone(status: OrderStatus): Tone {
  return ORDER_TONES[status] ?? "slate";
}
