"use client";

import { Button } from "@/components/ui/Button";
import { cn } from "@/lib/cn";

export function Pagination({
  page,
  totalPages,
  onPageChange,
  className,
}: {
  page: number;
  totalPages: number;
  onPageChange: (p: number) => void;
  className?: string;
}) {
  if (totalPages <= 1) return null;
  return (
    <div className={cn("flex items-center justify-center gap-3", className)}>
      <Button variant="outline" size="sm" onClick={() => onPageChange(page - 1)} disabled={page <= 1}>
        Önceki
      </Button>
      <span className="text-sm text-slate-600">
        Sayfa {page} / {totalPages}
      </span>
      <Button variant="outline" size="sm" onClick={() => onPageChange(page + 1)} disabled={page >= totalPages}>
        Sonraki
      </Button>
    </div>
  );
}
