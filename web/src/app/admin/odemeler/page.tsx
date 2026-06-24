"use client";

import { useCallback, useEffect, useState } from "react";
import { Wallet } from "lucide-react";
import type { Pagination as Pg, SettlementSummary, SubMerchantRow, SubMerchantStatus } from "@/lib/types";
import { getSettlementSummary, getSubMerchants } from "@/lib/api/admin";
import { formatPrice } from "@/lib/format";
import { subMerchantBadge } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { StatCard } from "@/components/admin/StatCard";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";
import { EmptyState } from "@/components/ui/EmptyState";

type Filter = "all" | SubMerchantStatus;
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "active" as const, label: "Aktif" },
  { key: "none" as const, label: "Tanımsız" },
  { key: "error" as const, label: "Hatalı" },
];

export default function AdminPaymentsPage() {
  const [summary, setSummary] = useState<SettlementSummary | null>(null);
  const [filter, setFilter] = useState<Filter>("all");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<SubMerchantRow[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getSettlementSummary()
      .then((r) => setSummary(r.summary))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, []);

  const loadSub = useCallback(() => {
    setRows(null);
    getSubMerchants({ page, limit: 20, subMerchantStatus: filter === "all" ? undefined : filter })
      .then((res) => {
        setRows(res.data);
        setPagination(res.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page, filter]);

  useEffect(() => {
    loadSub();
  }, [loadSub]);

  const columns: Column<SubMerchantRow>[] = [
    { key: "name", header: "İşletme", render: (b) => <span className="font-medium text-slate-900">{b.name}</span> },
    { key: "city", header: "Şehir", render: (b) => b.city },
    {
      key: "status",
      header: "Durum",
      render: (b) => {
        const x = subMerchantBadge(b.subMerchantStatus);
        return <Badge tone={x.tone}>{x.label}</Badge>;
      },
    },
    { key: "iban", header: "IBAN", render: (b) => <span className="font-mono text-xs">{b.iban ?? "—"}</span> },
    { key: "error", header: "Hata", render: (b) => (b.subMerchantError ? <span className="text-xs text-red-600">{b.subMerchantError}</span> : "—") },
  ];

  return (
    <>
      <PanelHeader title="Ödemeler / Mutabakat" description="Platform geneli ödeme ve satıcı hesabı durumu." />

      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}

      {!summary ? (
        <LoadingBlock />
      ) : (
        <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-3">
          <StatCard label="GMV (ödenen)" value={formatPrice(summary.gmv)} tone="green" />
          <StatCard label="Komisyon" value={formatPrice(summary.commission)} tone="green" />
          <StatCard label="İade" value={formatPrice(summary.refunded)} tone="red" />
          <StatCard label="Bekleyen (held)" value={formatPrice(summary.held)} hint={`${summary.heldCount} sipariş`} tone="amber" />
          <StatCard label="Onaylanan" value={formatPrice(summary.approved)} hint={`${summary.approvedCount} sipariş`} />
        </div>
      )}

      <h2 className="mb-3 text-lg font-semibold text-slate-900">Satıcı Ödeme Hesapları</h2>
      <div className="space-y-4">
        <Tabs items={FILTERS} value={filter} onChange={(k) => { setFilter(k); setPage(1); }} />
        <DataTable
          columns={columns}
          rows={rows ?? []}
          keyField={(b) => b.id}
          loading={!rows}
          empty={<EmptyState icon={Wallet} title="Kayıt yok" description="Bu filtreye uygun satıcı hesabı bulunmuyor." />}
        />
        {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
      </div>
    </>
  );
}
