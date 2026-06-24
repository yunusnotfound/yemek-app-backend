import { type ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { Card, CardBody } from "@/components/ui/Card";
import { cn } from "@/lib/cn";

const TONES = {
  default: "text-slate-900",
  amber: "text-amber-600",
  green: "text-brand-700",
  red: "text-red-600",
} as const;

export function StatCard({
  label,
  value,
  icon: Icon,
  hint,
  tone = "default",
}: {
  label: string;
  value: ReactNode;
  icon?: LucideIcon;
  hint?: ReactNode;
  tone?: keyof typeof TONES;
}) {
  return (
    <Card>
      <CardBody className="p-4 sm:p-5">
        <div className="flex items-center justify-between">
          <p className="text-sm text-slate-600">{label}</p>
          {Icon ? <Icon className="h-4 w-4 text-slate-400" /> : null}
        </div>
        <p className={cn("mt-1 text-2xl font-bold", TONES[tone])}>{value}</p>
        {hint ? <p className="mt-1 text-xs text-slate-500">{hint}</p> : null}
      </CardBody>
    </Card>
  );
}
