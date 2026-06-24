"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ShoppingBag } from "lucide-react";
import type { Order, OrderStatus, Pagination as Pg } from "@/lib/types";
import { getOrders } from "@/lib/api/admin";
import { formatPrice, formatDateTime, orderStatusLabel } from "@/lib/format";
import { paymentBadge } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Input } from "@/components/ui/Field";
import { Badge, orderTone } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

type Filter = "all" | OrderStatus;
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "pending" as const, label: "Bekleyen" },
  { key: "confirmed" as const, label: "Onaylı" },
  { key: "picked_up" as const, label: "Teslim" },
  { key: "cancelled" as const, label: "İptal" },
];

type OrderRow = Order & { package?: { title?: string; business?: { name?: string } }; user?: { name?: string } };

export default function AdminOrdersPage() {
  const router = useRouter();
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<OrderRow[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getOrders({ page, limit: 20, status: filter === "all" ? undefined : filter, search: search || undefined })
      .then((res) => {
        setRows(res.data as OrderRow[]);
        setPagination(res.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page, filter, search]);

  useEffect(() => {
    load();
  }, [load]);

  const columns: Column<OrderRow>[] = [
    { key: "code", header: "Kod", render: (o) => <span className="font-mono font-semibold tracking-wider">{o.pickupCode}</span> },
    { key: "package", header: "Paket", render: (o) => o.package?.title ?? "—" },
    { key: "business", header: "İşletme", render: (o) => o.package?.business?.name ?? "—" },
    { key: "user", header: "Müşteri", render: (o) => o.user?.name ?? "—" },
    { key: "total", header: "Tutar", render: (o) => <span className="font-semibold">{formatPrice(o.finalPrice)}</span> },
    { key: "status", header: "Durum", render: (o) => <Badge tone={orderTone(o.status)}>{orderStatusLabel(o.status)}</Badge> },
    {
      key: "payment",
      header: "Ödeme",
      render: (o) => {
        const x = paymentBadge(o.paymentStatus);
        return <Badge tone={x.tone}>{x.label}</Badge>;
      },
    },
    { key: "date", header: "Tarih", render: (o) => formatDateTime(o.createdAt) },
  ];

  return (
    <>
      <PanelHeader title="Siparişler" description="Tüm siparişleri görüntüle, detay ve iade." />
      <div className="space-y-4">
        <Tabs items={FILTERS} value={filter} onChange={(k) => { setFilter(k); setPage(1); }} />
        <Input
          placeholder="Teslim kodu ile ara…"
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          className="max-w-sm"
        />
        {error ? (
          <Alert tone="error">{error}</Alert>
        ) : (
          <>
            <DataTable
              columns={columns}
              rows={rows ?? []}
              keyField={(o) => o.id}
              loading={!rows}
              empty={<EmptyState icon={ShoppingBag} title="Sipariş yok" description="Bu filtreye uygun sipariş bulunmuyor." />}
              onRowClick={(o) => router.push(`/admin/siparisler/${o.id}`)}
            />
            {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
          </>
        )}
      </div>
    </>
  );
}
