"use client";

import { useEffect, useState } from "react";
import {
  ShoppingBag,
  Clock,
  Wallet,
  Package,
  Star,
  CalendarDays,
  ArrowRight,
} from "lucide-react";
import type { DashboardResponse } from "@/lib/types";
import { getDashboard } from "@/lib/api/panel";
import { formatPrice } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";
import { Card, CardBody } from "@/components/ui/Card";
import { LoadingBlock } from "@/components/ui/Spinner";
import { Alert } from "@/components/ui/Alert";
import { ButtonLink } from "@/components/ui/Button";

function StatCard({
  icon: Icon,
  label,
  value,
  tone = "slate",
}: {
  icon: typeof ShoppingBag;
  label: string;
  value: string;
  tone?: "slate" | "brand" | "amber";
}) {
  const toneCls =
    tone === "brand"
      ? "bg-brand-100 text-brand-700"
      : tone === "amber"
        ? "bg-amber-100 text-amber-700"
        : "bg-slate-100 text-slate-600";
  return (
    <Card>
      <CardBody className="flex items-center gap-4">
        <span className={`grid h-11 w-11 shrink-0 place-items-center rounded-xl ${toneCls}`}>
          <Icon className="h-5 w-5" />
        </span>
        <div className="min-w-0">
          <p className="text-sm text-slate-500">{label}</p>
          <p className="truncate text-xl font-bold text-slate-900">{value}</p>
        </div>
      </CardBody>
    </Card>
  );
}

function RevenueChart({ data }: { data: DashboardResponse["dailyStats"] }) {
  const max = Math.max(1, ...data.map((d) => d.revenue));
  return (
    <Card>
      <CardBody>
        <div className="flex items-center justify-between">
          <h2 className="font-semibold text-slate-900">Son 7 gün geliri</h2>
          <CalendarDays className="h-5 w-5 text-slate-400" />
        </div>
        <div className="mt-6 flex h-40 items-end justify-between gap-2">
          {data.map((d) => (
            <div key={d.date} className="flex flex-1 flex-col items-center gap-2">
              <div className="flex w-full flex-1 items-end">
                <div
                  className="w-full rounded-t-md bg-brand-500/80 transition-all"
                  style={{ height: `${Math.max(4, (d.revenue / max) * 100)}%` }}
                  title={formatPrice(d.revenue)}
                />
              </div>
              <span className="text-[11px] text-slate-400">
                {new Date(d.date).toLocaleDateString("tr-TR", {
                  weekday: "short",
                })}
              </span>
            </div>
          ))}
        </div>
      </CardBody>
    </Card>
  );
}

function Overview({ businessId }: { businessId: string }) {
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    setData(null);
    setError(null);
    getDashboard(businessId)
      .then((res) => alive && setData(res))
      .catch((e) => alive && setError(e instanceof Error ? e.message : "Yüklenemedi"));
    return () => {
      alive = false;
    };
  }, [businessId]);

  if (error) return <Alert tone="error">{error}</Alert>;
  if (!data) return <LoadingBlock />;

  const s = data.stats;

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          icon={Clock}
          label="Bekleyen sipariş"
          value={String(s.pendingOrders)}
          tone="amber"
        />
        <StatCard
          icon={ShoppingBag}
          label="Bugünkü sipariş"
          value={String(s.todayOrders)}
        />
        <StatCard
          icon={Wallet}
          label="Bugünkü gelir"
          value={formatPrice(s.todayRevenue)}
          tone="brand"
        />
        <StatCard
          icon={Package}
          label="Aktif paket"
          value={String(s.activePackages)}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
        <RevenueChart data={data.dailyStats} />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
          <StatCard
            icon={Wallet}
            label="Aylık gelir"
            value={formatPrice(s.monthlyRevenue)}
            tone="brand"
          />
          <StatCard
            icon={ShoppingBag}
            label="Toplam sipariş"
            value={String(s.totalOrders)}
          />
          <StatCard
            icon={Star}
            label="Ortalama puan"
            value={s.averageRating ? s.averageRating.toFixed(1) : "—"}
            tone="amber"
          />
        </div>
      </div>

      <Card>
        <CardBody className="flex flex-col items-start justify-between gap-3 sm:flex-row sm:items-center">
          <div>
            <h2 className="font-semibold text-slate-900">Hızlı işlem</h2>
            <p className="text-sm text-slate-600">
              Yeni bir sürpriz paket oluştur veya gelen siparişleri yönet.
            </p>
          </div>
          <div className="flex gap-2">
            <ButtonLink href="/panel/paketler/yeni" size="sm">
              Paket oluştur
            </ButtonLink>
            <ButtonLink href="/panel/siparisler" variant="outline" size="sm">
              Siparişler <ArrowRight className="h-4 w-4" />
            </ButtonLink>
          </div>
        </CardBody>
      </Card>
    </div>
  );
}

export default function DashboardPage() {
  return (
    <>
      <PanelHeader
        title="Genel Bakış"
        description="İşletmenin özet performansı."
      />
      <RequireBusiness>{(b) => <Overview businessId={b.id} />}</RequireBusiness>
    </>
  );
}
