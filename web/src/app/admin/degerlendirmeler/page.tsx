"use client";

import { useCallback, useEffect, useState } from "react";
import { Star } from "lucide-react";
import type { Pagination as Pg } from "@/lib/types";
import { getReviews, deleteReview, type AdminReview } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatDateTime } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";
import { EmptyState } from "@/components/ui/EmptyState";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";

type Filter = "all" | "1" | "2" | "3";
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "3" as const, label: "3+ yıldız" },
  { key: "2" as const, label: "2+ yıldız" },
  { key: "1" as const, label: "1+ yıldız" },
];

export default function AdminReviewsPage() {
  const [filter, setFilter] = useState<Filter>("all");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<AdminReview[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [toDelete, setToDelete] = useState<AdminReview | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getReviews({ page, limit: 20, minRating: filter === "all" ? undefined : Number(filter) })
      .then((res) => {
        setRows(res.data);
        setPagination(res.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page, filter]);

  useEffect(() => {
    load();
  }, [load]);

  async function doDelete() {
    if (!toDelete) return;
    setBusy(true);
    try {
      await deleteReview(toDelete.id);
      setToDelete(null);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Silinemedi");
      setToDelete(null);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PanelHeader title="Değerlendirmeler" description="Yorumları görüntüle ve modere et." />
      <div className="space-y-4">
        <Tabs items={FILTERS} value={filter} onChange={(k) => { setFilter(k); setPage(1); }} />
        {error ? <Alert tone="error">{error}</Alert> : null}
        {!rows ? (
          <LoadingBlock />
        ) : rows.length === 0 ? (
          <EmptyState icon={Star} title="Değerlendirme yok" description="Bu filtreye uygun değerlendirme bulunmuyor." />
        ) : (
          <div className="grid gap-4">
            {rows.map((r) => (
              <Card key={r.id}>
                <CardBody className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-amber-500">{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</span>
                      <span className="text-sm font-medium text-slate-900">{r.business?.name ?? "—"}</span>
                    </div>
                    {r.comment ? <p className="mt-1 text-sm text-slate-600">{r.comment}</p> : null}
                    <p className="mt-1 text-xs text-slate-400">{r.user?.name ?? "—"} · {formatDateTime(r.createdAt)}</p>
                  </div>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="shrink-0 text-red-600 hover:bg-red-50"
                    onClick={() => setToDelete(r)}
                  >
                    Sil
                  </Button>
                </CardBody>
              </Card>
            ))}
          </div>
        )}
        {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
      </div>

      <ConfirmDialog
        open={toDelete !== null}
        onClose={() => setToDelete(null)}
        onConfirm={doDelete}
        loading={busy}
        tone="danger"
        title="Değerlendirmeyi sil"
        description="Yorum silinecek ve işletmenin puan ortalaması yeniden hesaplanacak."
        confirmLabel="Sil"
      />
    </>
  );
}
