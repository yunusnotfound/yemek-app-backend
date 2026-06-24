"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Store } from "lucide-react";
import type { ApprovalStatus, Business, Pagination as Pg } from "@/lib/types";
import { getBusinesses } from "@/lib/api/admin";
import { formatDate } from "@/lib/format";
import { approvalBadge, activeBadge, subMerchantBadge } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Input } from "@/components/ui/Field";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

type Filter = "all" | ApprovalStatus;
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "pending" as const, label: "Onay bekleyen" },
  { key: "approved" as const, label: "Onaylı" },
  { key: "rejected" as const, label: "Reddedilen" },
];

export default function AdminBusinessesPage() {
  const router = useRouter();
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<Business[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getBusinesses({
      page,
      limit: 20,
      search: search || undefined,
      approvalStatus: filter === "all" ? undefined : filter,
    })
      .then((res) => {
        setRows(res.data);
        setPagination(res.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page, search, filter]);

  useEffect(() => {
    load();
  }, [load]);

  const columns: Column<Business>[] = [
    { key: "name", header: "İşletme", render: (b) => <span className="font-medium text-slate-900">{b.name}</span> },
    { key: "city", header: "Şehir", render: (b) => b.city },
    {
      key: "approval",
      header: "Onay",
      render: (b) => {
        const x = approvalBadge(b.approvalStatus);
        return <Badge tone={x.tone}>{x.label}</Badge>;
      },
    },
    {
      key: "active",
      header: "Durum",
      render: (b) => {
        const x = activeBadge(b.isActive);
        return <Badge tone={x.tone}>{x.label}</Badge>;
      },
    },
    {
      key: "submerchant",
      header: "Ödeme hesabı",
      render: (b) => {
        const x = subMerchantBadge(b.subMerchantStatus);
        return <Badge tone={x.tone}>{x.label}</Badge>;
      },
    },
    { key: "createdAt", header: "Kayıt", render: (b) => formatDate(b.createdAt) },
  ];

  return (
    <>
      <PanelHeader title="İşletmeler" description="Tüm işletmeleri görüntüle, onayla, askıya al." />
      <div className="space-y-4">
        <Tabs
          items={FILTERS}
          value={filter}
          onChange={(k) => {
            setFilter(k);
            setPage(1);
          }}
        />
        <Input
          placeholder="İşletme adı ara…"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          className="max-w-sm"
        />

        {error ? (
          <Alert tone="error">{error}</Alert>
        ) : (
          <>
            <DataTable
              columns={columns}
              rows={rows ?? []}
              keyField={(b) => b.id}
              loading={!rows}
              empty={<EmptyState icon={Store} title="İşletme yok" description="Bu filtreye uygun işletme bulunmuyor." />}
              onRowClick={(b) => router.push(`/admin/isletmeler/${b.id}`)}
            />
            {pagination ? (
              <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} />
            ) : null}
          </>
        )}
      </div>
    </>
  );
}
