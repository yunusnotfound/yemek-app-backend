import type { ComponentType, ReactNode } from "react";
import type { LucideProps } from "lucide-react";

export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
}: {
  icon?: ComponentType<LucideProps>;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white px-6 py-16 text-center">
      {Icon ? (
        <span className="grid h-12 w-12 place-items-center rounded-xl bg-slate-100 text-slate-500">
          <Icon className="h-6 w-6" />
        </span>
      ) : null}
      <h3 className="mt-4 text-lg font-semibold text-slate-900">{title}</h3>
      {description ? (
        <p className="mt-1.5 max-w-sm text-sm text-slate-600">{description}</p>
      ) : null}
      {action ? <div className="mt-6">{action}</div> : null}
    </div>
  );
}
