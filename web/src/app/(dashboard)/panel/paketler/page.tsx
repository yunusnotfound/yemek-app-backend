"use client";

import { useCallback, useEffect, useState } from "react";
import { Package, Pencil, Trash2, Plus, Clock } from "lucide-react";
import type { PackageWithStats } from "@/lib/types";
import { getBusinessPackages, deletePackage } from "@/lib/api/panel";
import { ApiError } from "@/lib/api/errors";
import { formatPrice, formatDate, formatTime, discountPercent } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";
import { Card, CardBody } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Button, ButtonLink } from "@/components/ui/Button";
import { LoadingBlock } from "@/components/ui/Spinner";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

function PackageCard({
  pkg,
  onDeleted,
}: {
  pkg: PackageWithStats;
  onDeleted: (id: string) => void;
}) {
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onDelete() {
    if (!window.confirm(`"${pkg.title}" paketini silmek istiyor musun?`)) return;
    setDeleting(true);
    setError(null);
    try {
      await deletePackage(pkg.id);
      onDeleted(pkg.id);
    } catch (err) {
      setError(
        err instanceof ApiError ? err.message : "Paket silinemedi",
      );
      setDeleting(false);
    }
  }

  const off = discountPercent(Number(pkg.originalPrice), Number(pkg.discountedPrice));

  return (
    <Card>
      <CardBody className="flex gap-4">
        <div className="h-20 w-20 shrink-0 overflow-hidden rounded-xl border border-slate-200 bg-slate-50">
          {pkg.imageUrl ? (
            <img src={pkg.imageUrl} alt="" className="h-full w-full object-cover" />
          ) : (
            <div className="grid h-full w-full place-items-center text-slate-300">
              <Package className="h-7 w-7" />
            </div>
          )}
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <h3 className="truncate font-semibold text-slate-900">{pkg.title}</h3>
            {pkg.isActive ? (
              <Badge tone="green">Aktif</Badge>
            ) : (
              <Badge tone="slate">Pasif</Badge>
            )}
          </div>

          <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
            <span className="font-bold text-brand-700">
              {formatPrice(pkg.discountedPrice)}
            </span>
            <span className="text-slate-400 line-through">
              {formatPrice(pkg.originalPrice)}
            </span>
            {off > 0 ? <Badge tone="amber">%{off} indirim</Badge> : null}
          </div>

          <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500">
            <span className="inline-flex items-center gap-1">
              <Clock className="h-3.5 w-3.5" />
              {formatDate(pkg.pickupDate)} · {formatTime(pkg.pickupStart)}–
              {formatTime(pkg.pickupEnd)}
            </span>
            <span>
              Kalan: <strong className="text-slate-700">{pkg.remainingQuantity}</strong>/
              {pkg.quantity}
            </span>
            <span>
              Satış: <strong className="text-slate-700">{pkg.soldQuantity}</strong>
            </span>
          </div>

          {error ? <p className="mt-2 text-sm text-red-600">{error}</p> : null}

          <div className="mt-3 flex gap-2">
            <ButtonLink
              href={`/panel/paketler/${pkg.id}/duzenle`}
              variant="outline"
              size="sm"
            >
              <Pencil className="h-4 w-4" /> Düzenle
            </ButtonLink>
            <Button
              variant="ghost"
              size="sm"
              onClick={onDelete}
              disabled={deleting}
              className="text-red-600 hover:bg-red-50"
            >
              <Trash2 className="h-4 w-4" /> Sil
            </Button>
          </div>
        </div>
      </CardBody>
    </Card>
  );
}

function PackageList({ businessId }: { businessId: string }) {
  const [items, setItems] = useState<PackageWithStats[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    getBusinessPackages(businessId, { limit: 50 })
      .then((res) => setItems(res.data))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [businessId]);

  useEffect(() => {
    setItems(null);
    load();
  }, [load]);

  if (error) return <Alert tone="error">{error}</Alert>;
  if (!items) return <LoadingBlock />;

  if (items.length === 0) {
    return (
      <EmptyState
        icon={Package}
        title="Henüz paket yok"
        description="İlk sürpriz paketini oluşturup satışa başla."
        action={
          <ButtonLink href="/panel/paketler/yeni">
            <Plus className="h-4 w-4" /> Paket oluştur
          </ButtonLink>
        }
      />
    );
  }

  return (
    <div className="grid gap-4">
      {items.map((pkg) => (
        <PackageCard
          key={pkg.id}
          pkg={pkg}
          onDeleted={(id) => setItems((cur) => cur?.filter((p) => p.id !== id) ?? null)}
        />
      ))}
    </div>
  );
}

export default function PackagesPage() {
  return (
    <>
      <PanelHeader
        title="Paketler"
        description="Sürpriz paketlerini oluştur ve yönet."
        action={
          <ButtonLink href="/panel/paketler/yeni" size="sm">
            <Plus className="h-4 w-4" /> Yeni paket
          </ButtonLink>
        }
      />
      <RequireBusiness>{(b) => <PackageList businessId={b.id} />}</RequireBusiness>
    </>
  );
}
