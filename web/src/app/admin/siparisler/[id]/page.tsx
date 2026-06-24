"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import type { Order } from "@/lib/types";
import { getOrder, refundOrder } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatPrice, formatDateTime, orderStatusLabel } from "@/lib/format";
import { paymentBadge } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge, orderTone } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";

type OrderDetail = Order & {
  package?: { title?: string; business?: { name?: string; phone?: string } };
  user?: { name?: string; email?: string; phone?: string };
};

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4 py-2 text-sm">
      <span className="text-slate-500">{label}</span>
      <span className="text-right font-medium text-slate-900">{value}</span>
    </div>
  );
}

export default function AdminOrderDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [order, setOrder] = useState<OrderDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    getOrder(id)
      .then((r) => setOrder(r.order as OrderDetail))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  async function doRefund() {
    setBusy(true);
    setError(null);
    try {
      await refundOrder(id);
      setConfirm(false);
      setOrder(null);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "İade başarısız");
    } finally {
      setBusy(false);
    }
  }

  if (error && !order) return <Alert tone="error">{error}</Alert>;
  if (!order) return <LoadingBlock />;

  const pay = paymentBadge(order.paymentStatus);
  const canRefund = order.paymentStatus === "paid";

  return (
    <>
      <PanelHeader
        title={`Sipariş ${order.pickupCode}`}
        description={order.package?.title ?? ""}
        action={
          <Link href="/admin/siparisler" className="text-sm font-medium text-brand-700 hover:underline">
            ← Siparişler
          </Link>
        }
      />

      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardBody>
            <div className="mb-3 flex flex-wrap gap-2">
              <Badge tone={orderTone(order.status)}>{orderStatusLabel(order.status)}</Badge>
              <Badge tone={pay.tone}>{pay.label}</Badge>
            </div>
            <Row label="İşletme" value={order.package?.business?.name ?? "—"} />
            <Row label="Müşteri" value={`${order.user?.name ?? "—"} (${order.user?.phone ?? order.user?.email ?? "—"})`} />
            <Row label="Adet" value={order.quantity} />
            <Row label="Tarih" value={formatDateTime(order.createdAt)} />
          </CardBody>
        </Card>

        <div className="space-y-4">
          <Card>
            <CardBody className="space-y-1">
              <h3 className="mb-1 text-sm font-semibold text-slate-900">Ödeme</h3>
              <Row label="Tutar" value={formatPrice(order.totalPrice)} />
              {order.discountAmount ? <Row label="İndirim" value={`-${formatPrice(order.discountAmount)}`} /> : null}
              <Row label="Ödenen" value={formatPrice(order.paidPrice ?? order.finalPrice)} />
              <Row label="Komisyon" value={formatPrice(order.commissionAmount ?? 0)} />
              <Row label="Satıcı payı" value={formatPrice(order.subMerchantPrice ?? 0)} />
              {order.refundAmount ? <Row label="İade" value={formatPrice(order.refundAmount)} /> : null}
              <Row label="Settlement" value={order.settlementStatus ?? "—"} />
              <Row label="iyzico işlem" value={order.paymentTransactionId ?? "—"} />
            </CardBody>
          </Card>

          {canRefund ? (
            <Card>
              <CardBody>
                <Button variant="danger" className="w-full" onClick={() => setConfirm(true)}>
                  İade et
                </Button>
                <p className="mt-2 text-xs text-slate-500">
                  İade müşteriye iyzico üzerinden yapılır; sipariş iptal edilir.
                </p>
              </CardBody>
            </Card>
          ) : null}
        </div>
      </div>

      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        onConfirm={doRefund}
        loading={busy}
        tone="danger"
        title="Siparişi iade et"
        description={`${formatPrice(order.paidPrice ?? order.finalPrice)} tutarında iade yapılacak ve sipariş iptal edilecek. Onaylamak için ONAYLA yazın.`}
        requireText="ONAYLA"
        confirmLabel="İade et"
      />
    </>
  );
}
