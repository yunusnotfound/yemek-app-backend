"use client";

import { useEffect, useState } from "react";
import { Users, Store, ShoppingBag, Package, Clock, Wallet, ClipboardCheck } from "lucide-react";
import type { AdminStats } from "@/lib/types";
import { getAdminDashboard } from "@/lib/api/admin";
import { formatPrice } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { StatCard } from "@/components/admin/StatCard";
import { LoadingBlock } from "@/components/ui/Spinner";
import { Alert } from "@/components/ui/Alert";

export default function AdminDashboardPage() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getAdminDashboard()
      .then((r) => setStats(r.stats))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, []);

  return (
    <>
      <PanelHeader title="Genel Bakış" description="Platform geneli özet ve metrikler." />
      {error ? (
        <Alert tone="error">{error}</Alert>
      ) : !stats ? (
        <LoadingBlock />
      ) : (
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <StatCard
            label="Kullanıcılar"
            value={stats.totalUsers}
            icon={Users}
            hint={`${stats.customers} müşteri · ${stats.businessOwners} işletme · ${stats.admins} admin`}
          />
          <StatCard label="İşletmeler" value={stats.totalBusinesses} icon={Store} hint={`${stats.activeBusinesses} aktif`} />
          <StatCard
            label="Onay bekleyen"
            value={stats.pendingBusinesses}
            icon={ClipboardCheck}
            tone={stats.pendingBusinesses > 0 ? "amber" : "default"}
          />
          <StatCard label="Paketler" value={stats.totalPackages} icon={Package} />
          <StatCard label="Toplam sipariş" value={stats.totalOrders} icon={ShoppingBag} />
          <StatCard label="Bugün sipariş" value={stats.todayOrders} icon={Clock} hint={formatPrice(stats.todayRevenue)} />
          <StatCard label="GMV (ödenen)" value={formatPrice(stats.gmv)} icon={Wallet} tone="green" />
          <StatCard
            label="Komisyon"
            value={formatPrice(stats.commissionTotal)}
            icon={Wallet}
            tone="green"
            hint={`İade: ${formatPrice(stats.refundedTotal)}`}
          />
        </div>
      )}
    </>
  );
}
