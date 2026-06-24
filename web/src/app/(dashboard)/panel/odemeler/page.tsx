"use client";

import { useCallback, useEffect, useState } from "react";
import { Info } from "lucide-react";
import type { EarningsResponse } from "@/lib/types";
import { getEarnings } from "@/lib/api/panel";
import { formatPrice } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";
import { SubMerchantForm } from "@/components/panel/SubMerchantForm";
import { Card, CardBody } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";

function Stat({
  label,
  value,
  hint,
  strong,
}: {
  label: string;
  value: string;
  hint?: string;
  strong?: boolean;
}) {
  return (
    <Card>
      <CardBody className="p-4 sm:p-5">
        <p className="text-sm text-slate-600">{label}</p>
        <p
          className={
            strong
              ? "mt-1 text-2xl font-bold text-brand-700"
              : "mt-1 text-2xl font-bold text-slate-900"
          }
        >
          {value}
        </p>
        {hint ? <p className="mt-1 text-xs text-slate-500">{hint}</p> : null}
      </CardBody>
    </Card>
  );
}

function PaymentsView({ businessId }: { businessId: string }) {
  const [data, setData] = useState<EarningsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);

  const load = useCallback(() => {
    setData(null);
    setError(null);
    getEarnings(businessId)
      .then((res) => {
        setData(res);
        // Hesap aktif değilse formu açık başlat.
        setEditing(res.submerchant.status !== "active");
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [businessId]);

  useEffect(() => {
    load();
  }, [load]);

  if (error) return <Alert tone="error">{error}</Alert>;
  if (!data) return <LoadingBlock />;

  const { submerchant: sm, earnings: e } = data;
  const ratePct = e.commissionRate != null ? Math.round(e.commissionRate * 100) : null;

  return (
    <div className="space-y-6">
      {/* Ödeme hesabı durumu */}
      <Card>
        <CardBody className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="font-semibold text-slate-900">Ödeme hesabı</span>
              {sm.status === "active" ? (
                <Badge tone="green">Aktif</Badge>
              ) : sm.status === "error" ? (
                <Badge tone="red">Hata</Badge>
              ) : (
                <Badge tone="amber">Tanımlı değil</Badge>
              )}
            </div>
            <p className="mt-1 text-sm text-slate-600">
              {sm.status === "active" && sm.iban
                ? `IBAN: ${sm.iban}`
                : "Satış gelirlerinizi alabilmek için ödeme hesabınızı tanımlayın."}
            </p>
          </div>
          {sm.status === "active" ? (
            <Button variant="outline" size="sm" onClick={() => setEditing((v) => !v)}>
              {editing ? "Vazgeç" : "Bilgileri güncelle"}
            </Button>
          ) : null}
        </CardBody>
      </Card>

      {sm.status === "error" && sm.error ? (
        <Alert tone="error">Ödeme hesabı kaydedilemedi: {sm.error}</Alert>
      ) : null}

      {/* Kazanç özeti */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat
          label="Ödenecek (onaylandı)"
          value={formatPrice(e.netApproved)}
          hint="iyzico IBAN'ınıza öder"
          strong
        />
        <Stat
          label="Teslim bekleyen"
          value={formatPrice(e.netHeld)}
          hint="Teslim sonrası ödenir"
        />
        <Stat label="Toplam satış" value={formatPrice(e.totalSales)} />
        <Stat
          label={ratePct != null ? `Komisyon (%${ratePct})` : "Komisyon"}
          value={formatPrice(e.commission)}
        />
      </div>

      {e.refunded > 0 ? (
        <Stat label="İade edilen" value={formatPrice(e.refunded)} />
      ) : null}

      <Alert tone="info">
        <span className="inline-flex items-center gap-1">
          <Info className="h-4 w-4" />
          Ödemeler, sipariş teslim alındıktan sonra iyzico tarafından IBAN&apos;ınıza yapılır
          (yaklaşık haftalık).
        </span>
      </Alert>

      {/* Onboarding / güncelleme formu */}
      {editing ? (
        <SubMerchantForm
          businessId={businessId}
          current={sm}
          onSaved={() => {
            setEditing(false);
            load();
          }}
        />
      ) : null}
    </div>
  );
}

export default function OdemelerPage() {
  return (
    <>
      <PanelHeader
        title="Ödemeler"
        description="Ödeme hesabınızı yönetin ve kazançlarınızı takip edin."
      />
      <RequireBusiness>{(b) => <PaymentsView businessId={b.id} />}</RequireBusiness>
    </>
  );
}
