"use client";

import { useEffect, useState } from "react";
import { Star } from "lucide-react";
import type { Review } from "@/lib/types";
import { getBusinessReviews } from "@/lib/api/panel";
import { formatDate } from "@/lib/format";
import { cn } from "@/lib/cn";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";
import { Card, CardBody } from "@/components/ui/Card";
import { LoadingBlock } from "@/components/ui/Spinner";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

function Stars({ rating }: { rating: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((n) => (
        <Star
          key={n}
          className={cn(
            "h-4 w-4",
            n <= rating ? "fill-amber-400 text-amber-400" : "text-slate-300",
          )}
        />
      ))}
    </div>
  );
}

function ReviewsView({ businessId }: { businessId: string }) {
  const [items, setItems] = useState<Review[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setItems(null);
    setError(null);
    getBusinessReviews(businessId, { limit: 50 })
      .then((res) => setItems(res.data))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [businessId]);

  if (error) return <Alert tone="error">{error}</Alert>;
  if (!items) return <LoadingBlock />;
  if (items.length === 0) {
    return (
      <EmptyState
        icon={Star}
        title="Henüz değerlendirme yok"
        description="Müşterilerin siparişlerini değerlendirdikçe burada görünecek."
      />
    );
  }

  return (
    <div className="grid gap-4">
      {items.map((r) => (
        <Card key={r.id}>
          <CardBody>
            <div className="flex items-center justify-between">
              <span className="font-semibold text-slate-900">
                {r.user?.name ?? "Müşteri"}
              </span>
              <span className="text-xs text-slate-400">{formatDate(r.createdAt)}</span>
            </div>
            <div className="mt-1.5">
              <Stars rating={r.rating} />
            </div>
            {r.comment ? (
              <p className="mt-3 text-sm leading-relaxed text-slate-700">{r.comment}</p>
            ) : null}
          </CardBody>
        </Card>
      ))}
    </div>
  );
}

export default function ReviewsPage() {
  return (
    <>
      <PanelHeader
        title="Değerlendirmeler"
        description="Müşterilerinin yorum ve puanları."
      />
      <RequireBusiness>{(b) => <ReviewsView businessId={b.id} />}</RequireBusiness>
    </>
  );
}
