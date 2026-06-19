"use client";

import { Store } from "lucide-react";
import type { BusinessWithStats } from "@/lib/types";
import { useBusiness } from "@/components/panel/BusinessProvider";
import { LoadingBlock } from "@/components/ui/Spinner";
import { EmptyState } from "@/components/ui/EmptyState";
import { Alert } from "@/components/ui/Alert";
import { ButtonLink } from "@/components/ui/Button";

/**
 * Aktif bir işletme yoksa uygun durum (yükleniyor / hata / "işletme oluştur")
 * gösterir; varsa children'a aktif işletmeyi geçer.
 */
export function RequireBusiness({
  children,
}: {
  children: (business: BusinessWithStats) => React.ReactNode;
}) {
  const { active, loading, error } = useBusiness();

  if (loading) return <LoadingBlock />;
  if (error) return <Alert tone="error">{error}</Alert>;

  if (!active) {
    return (
      <EmptyState
        icon={Store}
        title="Henüz bir işletmen yok"
        description="Paket oluşturup satışa başlamak için önce işletme bilgilerini ekle."
        action={<ButtonLink href="/panel/isletme">İşletme oluştur</ButtonLink>}
      />
    );
  }

  return <>{children(active)}</>;
}
