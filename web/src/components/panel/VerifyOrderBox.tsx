"use client";

import { useState } from "react";
import { QrCode, CheckCircle2 } from "lucide-react";
import { verifyOrder } from "@/lib/api/panel";
import { ApiError } from "@/lib/api/errors";
import type { Order } from "@/lib/types";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Field";
import { Spinner } from "@/components/ui/Spinner";

export function VerifyOrderBox({
  businessId,
  onVerified,
}: {
  businessId: string;
  onVerified: () => void;
}) {
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<Order | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!code.trim()) return;
    setBusy(true);
    setError(null);
    setDone(null);
    try {
      const res = await verifyOrder(businessId, code.trim());
      setDone(res.order);
      setCode("");
      onVerified();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Doğrulama başarısız");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card className="border-brand-200 bg-brand-50/40">
      <CardBody>
        <div className="flex items-center gap-2 text-brand-800">
          <QrCode className="h-5 w-5" />
          <h2 className="font-semibold">Teslimat doğrula</h2>
        </div>
        <p className="mt-1 text-sm text-slate-600">
          Müşterinin teslim alma kodunu gir, siparişi teslim edildi olarak işaretle.
        </p>
        <form onSubmit={submit} className="mt-4 flex gap-2">
          <Input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            inputMode="numeric"
            placeholder="Teslim alma kodu"
            className="max-w-xs"
          />
          <Button type="submit" disabled={busy}>
            {busy ? <Spinner className="h-5 w-5" /> : "Doğrula"}
          </Button>
        </form>
        {error ? <p className="mt-2 text-sm text-red-600">{error}</p> : null}
        {done ? (
          <p className="mt-3 inline-flex items-center gap-2 text-sm font-medium text-brand-800">
            <CheckCircle2 className="h-4 w-4" />
            {done.user?.name ?? "Müşteri"} · {done.package?.title ?? "Sipariş"} teslim
            edildi.
          </p>
        ) : null}
      </CardBody>
    </Card>
  );
}
