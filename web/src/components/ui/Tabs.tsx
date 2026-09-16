"use client";

import { cn } from "@/lib/cn";

export interface TabItem<K extends string> {
  key: K;
  label: string;
  count?: number;
}

export function Tabs<K extends string>({
  items,
  value,
  onChange,
  className,
}: {
  items: TabItem<K>[];
  value: K;
  onChange: (k: K) => void;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {items.map((t) => (
        <button
          key={t.key}
          type="button"
          aria-pressed={value === t.key}
          onClick={() => onChange(t.key)}
          className={cn(
            "min-h-11 rounded-full px-4 py-2 text-sm font-medium transition-colors motion-reduce:transition-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600",
            value === t.key
              ? "bg-brand-600 text-white shadow-control"
              : "bg-surface text-muted-ink ring-1 ring-surface-border hover:bg-surface-muted",
          )}
        >
          {t.label}
          {typeof t.count === "number" ? ` (${t.count})` : ""}
        </button>
      ))}
    </div>
  );
}
