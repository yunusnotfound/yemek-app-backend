"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { ClipboardCheck } from "lucide-react";
import type { Business } from "@/lib/types";
import { getPendingBusinesses, approveBusiness, rejectBusiness } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatDate } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";
import { EmptyState } from "@/components/ui/EmptyState";

type BizWithOwner = Business & { owner?: { name?: string; email?: string }; category?: { name?: string } };

export default function AdminPendingPage() {
  const [rows, setRows] = useState<BizWithOwner[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getPendingBusinesses({ limit: 50 })
      .then((res) => setRows(res.data as BizWithOwner[]))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function act(id: string, kind: "approve" | "reject") {
    setBusyId(id);
    setError(null);
    try {
      if (kind === "approve") await approveBusiness(id);
      else await rejectBusiness(id);
      setRows((cur) => (cur ? cur.filter((b) => b.id !== id) : cur));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "İşlem başarısız");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <PanelHeader title="Onay Bekleyenler" description="Yeni işletme başvurularını incele ve onayla." />
      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}
      {!rows ? (
        <LoadingBlock />
      ) : rows.length === 0 ? (
        <EmptyState icon={ClipboardCheck} title="Bekleyen başvuru yok" description="Tüm işletmeler değerlendirildi." />
      ) : (
        <div className="grid gap-4">
          {rows.map((b) => (
            <Card key={b.id}>
              <CardBody className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <Link href={`/admin/isletmeler/${b.id}`} className="font-semibold text-slate-900 hover:underline">
                    {b.name}
                  </Link>
                  <div className="mt-1 text-sm text-slate-600">
                    {b.city} · {b.category?.name ?? "—"} · {b.owner?.name ?? "—"} ({b.owner?.email ?? "—"})
                  </div>
                  <div className="mt-0.5 text-xs text-slate-400">{formatDate(b.createdAt)}</div>
                </div>
                <div className="flex shrink-0 gap-2">
                  <Button size="sm" onClick={() => act(b.id, "approve")} disabled={busyId === b.id}>
                    Onayla
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="text-red-600 hover:bg-red-50"
                    onClick={() => act(b.id, "reject")}
                    disabled={busyId === b.id}
                  >
                    Reddet
                  </Button>
                </div>
              </CardBody>
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
