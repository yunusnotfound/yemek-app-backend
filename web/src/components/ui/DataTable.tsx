"use client";

import { type ReactNode } from "react";
import { cn } from "@/lib/cn";
import { LoadingBlock } from "@/components/ui/Spinner";

export interface Column<T> {
  key: string;
  header: ReactNode;
  render: (row: T) => ReactNode;
  className?: string;
}

export function DataTable<T>({
  columns,
  rows,
  keyField,
  loading,
  empty,
  onRowClick,
}: {
  columns: Column<T>[];
  rows: T[];
  keyField: (row: T) => string;
  loading?: boolean;
  empty?: ReactNode;
  onRowClick?: (row: T) => void;
}) {
  if (loading) return <LoadingBlock />;
  if (!rows.length) return <>{empty ?? null}</>;

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white">
      {/* Masaüstü: tablo */}
      <table className="hidden w-full text-sm sm:table">
        <thead className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
          <tr>
            {columns.map((c) => (
              <th key={c.key} className={cn("px-4 py-3", c.className)}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {rows.map((row) => (
            <tr
              key={keyField(row)}
              className={cn(onRowClick && "cursor-pointer hover:bg-slate-50")}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {columns.map((c) => (
                <td key={c.key} className={cn("px-4 py-3 align-middle", c.className)}>
                  {c.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>

      {/* Mobil: kart yığını */}
      <div className="divide-y divide-slate-100 sm:hidden">
        {rows.map((row) => (
          <div
            key={keyField(row)}
            className={cn("space-y-1.5 px-4 py-3", onRowClick && "cursor-pointer")}
            onClick={onRowClick ? () => onRowClick(row) : undefined}
          >
            {columns.map((c) => (
              <div key={c.key} className="flex justify-between gap-3 text-sm">
                <span className="shrink-0 text-slate-500">{c.header}</span>
                <span className="text-right">{c.render(row)}</span>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
