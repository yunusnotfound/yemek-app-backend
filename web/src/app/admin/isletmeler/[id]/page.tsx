"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import type { BusinessAdminDetail } from "@/lib/types";
import { getBusiness, approveBusiness, rejectBusiness, setBusinessActive } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatPrice, formatDate } from "@/lib/format";
import { approvalBadge, activeBadge, subMerchantBadge } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";

type Action = "approve" | "reject" | "suspend" | "activate" | null;

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4 py-2 text-sm">
      <span className="text-slate-500">{label}</span>
      <span className="text-right font-medium text-slate-900">{value}</span>
    </div>
  );
}

export default function AdminBusinessDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [data, setData] = useState<BusinessAdminDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState<Action>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    getBusiness(id)
      .then(setData)
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  async function run() {
    if (!action) return;
    setBusy(true);
    try {
      if (action === "approve") await approveBusiness(id);
      else if (action === "reject") await rejectBusiness(id);
      else if (action === "suspend") await setBusinessActive(id, false);
      else if (action === "activate") await setBusinessActive(id, true);
      setAction(null);
      setData(null);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "İşlem başarısız");
    } finally {
      setBusy(false);
    }
  }

  if (error && !data) return <Alert tone="error">{error}</Alert>;
  if (!data) return <LoadingBlock />;

  const b = data.business;
  const ap = approvalBadge(b.approvalStatus);
  const ac = activeBadge(b.isActive);
  const sm = subMerchantBadge(b.subMerchantStatus);

  return (
    <>
      <PanelHeader
        title={b.name}
        description={`${b.city} · ${b.district}`}
        action={
          <Link href="/admin/isletmeler" className="text-sm font-medium text-brand-700 hover:underline">
            ← İşletmeler
          </Link>
        }
      />

      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardBody>
            <div className="mb-4 flex flex-wrap gap-2">
              <Badge tone={ap.tone}>{ap.label}</Badge>
              <Badge tone={ac.tone}>{ac.label}</Badge>
              <Badge tone={sm.tone}>Ödeme: {sm.label}</Badge>
            </div>
            <Row label="Adres" value={b.address} />
            <Row label="Telefon" value={b.phone || "—"} />
            <Row label="Kategori" value={b.category?.name || "—"} />
            <Row label="Sahip" value={`${b.owner?.name ?? "—"} (${b.owner?.email ?? "—"})`} />
            <Row label="IBAN" value={b.iban || "—"} />
            <Row label="Ödeme hesabı türü" value={b.subMerchantType || "—"} />
            {b.subMerchantError ? <Row label="Ödeme hesabı hatası" value={<span className="text-red-600">{b.subMerchantError}</span>} /> : null}
            <Row label="Kayıt" value={formatDate(b.createdAt)} />
          </CardBody>
        </Card>

        <div className="space-y-4">
          <Card>
            <CardBody className="space-y-2">
              <Row label="Paket" value={data.stats.packageCount} />
              <Row label="Ödenen sipariş" value={data.stats.orderCount} />
              <Row label="GMV" value={formatPrice(data.stats.gmv)} />
              <Row label="Komisyon" value={formatPrice(data.stats.commission)} />
            </CardBody>
          </Card>

          <Card>
            <CardBody className="space-y-2">
              {b.approvalStatus !== "approved" ? (
                <Button className="w-full" onClick={() => setAction("approve")}>Onayla</Button>
              ) : null}
              {b.approvalStatus !== "rejected" ? (
                <Button variant="outline" className="w-full" onClick={() => setAction("reject")}>Reddet</Button>
              ) : null}
              {b.isActive ? (
                <Button variant="danger" className="w-full" onClick={() => setAction("suspend")}>Askıya al</Button>
              ) : (
                <Button className="w-full" onClick={() => setAction("activate")}>Aktifleştir</Button>
              )}
            </CardBody>
          </Card>
        </div>
      </div>

      <ConfirmDialog
        open={action !== null}
        onClose={() => setAction(null)}
        onConfirm={run}
        loading={busy}
        tone={action === "reject" || action === "suspend" ? "danger" : "default"}
        title={
          action === "approve" ? "İşletmeyi onayla" :
          action === "reject" ? "İşletmeyi reddet" :
          action === "suspend" ? "İşletmeyi askıya al" : "İşletmeyi aktifleştir"
        }
        description={
          action === "suspend"
            ? "Askıya alınınca işletmenin paketleri müşterilere görünmez. Mevcut siparişler etkilenmez."
            : action === "reject"
              ? "İşletme reddedilecek ve listelerden kaldırılacak."
              : "Bu işlemi onaylıyor musunuz?"
        }
      />
    </>
  );
}
