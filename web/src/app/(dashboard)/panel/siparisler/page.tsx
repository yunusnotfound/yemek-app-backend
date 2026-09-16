"use client";

import { useCallback, useState } from "react";
import { ShoppingBag, Phone, User as UserIcon, Clock } from "lucide-react";
import type { Order, OrderStatus } from "@/lib/types";
import { getBusinessOrders, updateOrderStatus } from "@/lib/api/panel";
import { ApiError } from "@/lib/api/errors";
import {
  formatPrice,
  formatDateTime,
  formatTime,
  orderStatusLabel,
} from "@/lib/format";
import { cn } from "@/lib/cn";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";
import { VerifyOrderBox } from "@/components/panel/VerifyOrderBox";
import { Card, CardBody } from "@/components/ui/Card";
import { Badge, orderTone } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { LoadingBlock } from "@/components/ui/Spinner";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";
import { Pagination } from "@/components/ui/Pagination";
import { usePaginatedList } from "@/components/panel/usePaginatedList";

const FILTERS: { key: OrderStatus | "all"; label: string }[] = [
  { key: "all", label: "Tümü" },
  { key: "pending", label: "Bekleyen" },
  { key: "confirmed", label: "Onaylı" },
  { key: "picked_up", label: "Teslim edilen" },
  { key: "cancelled", label: "İptal" },
];

function OrderRow({
  order,
  onChanged,
}: {
  order: Order;
  onChanged: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function setStatus(status: OrderStatus) {
    setBusy(true);
    setError(null);
    try {
      await updateOrderStatus(order.id, status);
      onChanged();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Güncellenemedi");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardBody className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-slate-900">
              {order.package?.title ?? "Paket"}
            </span>
            <Badge tone={orderTone(order.status)}>
              {orderStatusLabel(order.status)}
            </Badge>
          </div>
          <div className="mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-slate-600">
            <span className="inline-flex items-center gap-1">
              <UserIcon className="h-4 w-4 text-slate-400" />
              {order.user?.name ?? "Müşteri"}
            </span>
            {order.user?.phone ? (
              <a
                href={`tel:${order.user.phone}`}
                className="inline-flex items-center gap-1 hover:text-brand-700"
              >
                <Phone className="h-4 w-4 text-slate-400" />
                {order.user.phone}
              </a>
            ) : null}
            <span>Adet: {order.quantity}</span>
            <span className="font-semibold text-slate-900">
              {formatPrice(order.finalPrice ?? order.totalPrice)}
            </span>
          </div>
          <div className="mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500">
            <span>
              Kod:{" "}
              <span className="font-mono font-semibold tracking-wider text-slate-700">
                {order.pickupCode}
              </span>
            </span>
            {order.package ? (
              <span className="inline-flex items-center gap-1">
                <Clock className="h-3.5 w-3.5" />
                {formatTime(order.package.pickupStart)}–
                {formatTime(order.package.pickupEnd)}
              </span>
            ) : null}
            <span>{formatDateTime(order.createdAt)}</span>
          </div>
          {error ? <p className="mt-2 text-sm text-red-600">{error}</p> : null}
        </div>

        <div className="flex shrink-0 flex-wrap gap-2">
          {order.status === "pending" ? (
            <Button size="sm" onClick={() => setStatus("confirmed")} disabled={busy}>
              Onayla
            </Button>
          ) : null}
          {order.status === "confirmed" ? (
            <Button size="sm" onClick={() => setStatus("picked_up")} disabled={busy}>
              Teslim edildi
            </Button>
          ) : null}
          {order.status === "pending" || order.status === "confirmed" ? (
            <Button
              size="sm"
              variant="ghost"
              className="text-red-600 hover:bg-red-50"
              onClick={() => setStatus("cancelled")}
              disabled={busy}
            >
              İptal
            </Button>
          ) : null}
        </div>
      </CardBody>
    </Card>
  );
}

function OrdersView({ businessId }: { businessId: string }) {
  const [filter, setFilter] = useState<OrderStatus | "all">("all");
  const loadPage = useCallback((page: number) =>
    getBusinessOrders(businessId, {
      status: filter === "all" ? undefined : filter,
      page,
      limit: 50,
    }), [businessId, filter]);
  const { items, error, page, totalPages, setPage, reload } = usePaginatedList(loadPage);

  return (
    <div className="space-y-6">
      <VerifyOrderBox businessId={businessId} onVerified={reload} />

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => { setFilter(f.key); setPage(1); }}
            className={cn(
              "rounded-full px-4 py-1.5 text-sm font-medium transition-colors",
              filter === f.key
                ? "bg-brand-600 text-white"
                : "bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50",
            )}
          >
            {f.label}
          </button>
        ))}
      </div>

      {error ? (
        <Alert tone="error">{error}</Alert>
      ) : !items ? (
        <LoadingBlock />
      ) : items.length === 0 ? (
        <EmptyState
          icon={ShoppingBag}
          title="Sipariş yok"
          description="Bu filtreye uygun sipariş bulunmuyor."
        />
      ) : (
        <div className="grid gap-4">
          {items.map((o) => (
            <OrderRow
              key={o.id}
              order={o}
              onChanged={reload}
            />
          ))}
        </div>
      )}
      {items ? <Pagination page={page} totalPages={totalPages} onPageChange={setPage} /> : null}
    </div>
  );
}

export default function OrdersPage() {
  return (
    <>
      <PanelHeader
        title="Siparişler"
        description="Gelen siparişleri yönet ve teslimatları doğrula."
      />
      <RequireBusiness>{(b) => <OrdersView key={b.id} businessId={b.id} />}</RequireBusiness>
    </>
  );
}
