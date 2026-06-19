import type { ReactNode } from "react";
import { AlertCircle, CheckCircle2, Info } from "lucide-react";
import { cn } from "@/lib/cn";

type Tone = "error" | "success" | "info" | "warning";

const STYLES: Record<Tone, { box: string; icon: ReactNode }> = {
  error: {
    box: "border-red-200 bg-red-50 text-red-800",
    icon: <AlertCircle className="h-5 w-5 text-red-500" />,
  },
  success: {
    box: "border-brand-200 bg-brand-50 text-brand-800",
    icon: <CheckCircle2 className="h-5 w-5 text-brand-600" />,
  },
  info: {
    box: "border-blue-200 bg-blue-50 text-blue-800",
    icon: <Info className="h-5 w-5 text-blue-500" />,
  },
  warning: {
    box: "border-amber-200 bg-amber-50 text-amber-900",
    icon: <AlertCircle className="h-5 w-5 text-amber-500" />,
  },
};

export function Alert({
  tone = "info",
  children,
  className,
}: {
  tone?: Tone;
  children: ReactNode;
  className?: string;
}) {
  const s = STYLES[tone];
  return (
    <div
      className={cn(
        "flex items-start gap-3 rounded-xl border px-4 py-3 text-sm",
        s.box,
        className,
      )}
      role={tone === "error" ? "alert" : undefined}
    >
      <span className="mt-0.5 shrink-0">{s.icon}</span>
      <div className="leading-relaxed">{children}</div>
    </div>
  );
}
