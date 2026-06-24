"use client";

import { useCallback, useEffect, useState } from "react";
import { ScrollText } from "lucide-react";
import type { AuditLogEntry, Pagination as Pg } from "@/lib/types";
import { getAuditLog } from "@/lib/api/admin";
import { formatDateTime } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

type Filter = "all" | "user" | "business" | "order" | "category" | "review";
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "user" as const, label: "Kullanıcı" },
  { key: "business" as const, label: "İşletme" },
  { key: "order" as const, label: "Sipariş" },
  { key: "category" as const, label: "Kategori" },
  { key: "review" as const, label: "Yorum" },
];

export default function AdminAuditPage() {
  const [filter, setFilter] = useState<Filter>("all");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<AuditLogEntry[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getAuditLog({ page, limit: 30, targetType: filter === "all" ? undefined : filter })
      .then((res) => {
        setRows(res.data);
        setPagination(res.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page, filter]);

  useEffect(() => {
    load();
  }, [load]);

  const columns: Column<AuditLogEntry>[] = [
    { key: "date", header: "Zaman", render: (a) => formatDateTime(a.createdAt) },
    { key: "admin", header: "Admin", render: (a) => a.admin?.name ?? a.admin?.email ?? "—" },
    { key: "action", header: "İşlem", render: (a) => <span className="font-mono text-xs">{a.action}</span> },
    { key: "target", header: "Hedef", render: (a) => (a.targetType ? `${a.targetType}:${(a.targetId ?? "").slice(0, 8)}` : "—") },
    { key: "ip", header: "IP", render: (a) => <span className="text-xs text-slate-500">{a.ip ?? "—"}</span> },
  ];

  return (
    <>
      <PanelHeader title="Denetim Kaydı" description="Admin işlemlerinin izlenebilir kaydı." />
      <div className="space-y-4">
        <Tabs items={FILTERS} value={filter} onChange={(k) => { setFilter(k); setPage(1); }} />
        {error ? <Alert tone="error">{error}</Alert> : null}
        <DataTable
          columns={columns}
          rows={rows ?? []}
          keyField={(a) => a.id}
          loading={!rows}
          empty={<EmptyState icon={ScrollText} title="Kayıt yok" description="Henüz admin işlemi kaydedilmemiş." />}
        />
        {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
      </div>
    </>
  );
}
