"use client";

import { useCallback, useEffect, useState } from "react";
import { Package } from "lucide-react";
import type { Pagination as Pg } from "@/lib/types";
import { getPackages, setPackageActive, type AdminPackage } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatPrice, formatDate } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Input } from "@/components/ui/Field";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

type Filter = "all" | "active" | "passive";
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "active" as const, label: "Aktif" },
  { key: "passive" as const, label: "Pasif" },
];

export default function AdminPackagesPage() {
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<AdminPackage[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getPackages({
      page,
      limit: 20,
      search: search || undefined,
      isActive: filter === "all" ? undefined : filter === "active" ? "true" : "false",
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

  async function toggle(p: AdminPackage) {
    setBusyId(p.id);
    setError(null);
    try {
      await setPackageActive(p.id, !p.isActive);
      setRows((cur) => (cur ? cur.map((x) => (x.id === p.id ? { ...x, isActive: !p.isActive } : x)) : cur));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "İşlem başarısız");
    } finally {
      setBusyId(null);
    }
  }

  const columns: Column<AdminPackage>[] = [
    { key: "title", header: "Paket", render: (p) => <span className="font-medium text-slate-900">{p.title}</span> },
    { key: "business", header: "İşletme", render: (p) => p.business?.name ?? "—" },
    { key: "price", header: "Fiyat", render: (p) => formatPrice(p.discountedPrice) },
    { key: "qty", header: "Stok", render: (p) => `${p.remainingQuantity}/${p.quantity}` },
    { key: "date", header: "Teslim", render: (p) => formatDate(p.pickupDate) },
    { key: "active", header: "Durum", render: (p) => <Badge tone={p.isActive ? "green" : "slate"}>{p.isActive ? "Aktif" : "Pasif"}</Badge> },
    {
      key: "actions",
      header: "",
      className: "text-right",
      render: (p) => (
        <Button
          size="sm"
          variant={p.isActive ? "ghost" : "outline"}
          className={p.isActive ? "text-red-600 hover:bg-red-50" : ""}
          onClick={() => toggle(p)}
          disabled={busyId === p.id}
        >
          {p.isActive ? "Pasifleştir" : "Aktifleştir"}
        </Button>
      ),
    },
  ];

  return (
    <>
      <PanelHeader title="Paketler" description="Tüm paketleri görüntüle ve modere et." />
      <div className="space-y-4">
        <Tabs items={FILTERS} value={filter} onChange={(k) => { setFilter(k); setPage(1); }} />
        <Input placeholder="Paket adı ara…" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} className="max-w-sm" />
        {error ? <Alert tone="error">{error}</Alert> : null}
        <DataTable
          columns={columns}
          rows={rows ?? []}
          keyField={(p) => p.id}
          loading={!rows}
          empty={<EmptyState icon={Package} title="Paket yok" description="Bu filtreye uygun paket bulunmuyor." />}
        />
        {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
      </div>
    </>
  );
}
