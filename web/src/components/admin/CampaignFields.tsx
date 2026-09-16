"use client";

import { useEffect, useState } from "react";
import { getBusinesses } from "@/lib/api/admin";
import type { Business } from "@/lib/types";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";

export interface CampaignForm {
  title: string;
  firstOrderOnly: boolean;
  perUserLimit: string;
  maxDiscountAmount: string;
  budgetLimit: string;
  isDiscoverable: boolean;
  businessIds: string[];
  merchantConsentConfirmed: boolean;
}

export const emptyCampaign: CampaignForm = {
  title: "", firstOrderOnly: false, perUserLimit: "1", maxDiscountAmount: "",
  budgetLimit: "", isDiscoverable: false, businessIds: [], merchantConsentConfirmed: false,
};

export function CampaignFields({ value, onChange }: { value: CampaignForm; onChange: (patch: Partial<CampaignForm>) => void }) {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [hasMore, setHasMore] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  useEffect(() => {
    let current = true;
    const timer = setTimeout(() => {
      setLoading(true);
      setError("");
      getBusinesses({ search, page, limit: 20 }).then((r) => {
        if (current) { setBusinesses(r.data); setHasMore(r.pagination.page < r.pagination.totalPages); }
      }).catch(() => { if (current) setError("İşletmeler yüklenemedi. Aramayı yeniden deneyin."); })
        .finally(() => { if (current) setLoading(false); });
    }, 250);
    return () => { current = false; clearTimeout(timer); };
  }, [search, page]);
  return <div className="space-y-4 rounded-2xl border border-brand-100 bg-brand-50/40 p-4">
    <Field label="Kampanya başlığı"><Input maxLength={100} value={value.title} onChange={(e) => onChange({ title: e.target.value })} placeholder="İlk paketine özel" /></Field>
    <div className="grid gap-4 sm:grid-cols-2">
      <Field label="Kişi başına kullanım" hint="Boş bırakırsanız kişisel sınır uygulanmaz."><Input type="number" min="1" value={value.perUserLimit} onChange={(e) => onChange({ perUserLimit: e.target.value })} /></Field>
      <Field label="İndirim üst sınırı (₺)"><Input type="number" min="0" step="0.01" value={value.maxDiscountAmount} onChange={(e) => onChange({ maxDiscountAmount: e.target.value })} /></Field>
      <Field label="Toplam indirim bütçesi (₺)" hint="Bekleyen ödemeler bütçeyi ayırır; başarısız ödemelerde hak geri verilir."><Input type="number" min="0.01" step="0.01" value={value.budgetLimit} onChange={(e) => onChange({ budgetLimit: e.target.value })} /></Field>
    </div>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={value.firstOrderOnly} onChange={(e) => onChange({ firstOrderOnly: e.target.checked })} /> Yalnızca ilk siparişte geçerli</label>
    <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={value.isDiscoverable} onChange={(e) => onChange({ isDiscoverable: e.target.checked })} /> Uygulamada ve Kuponlarım alanında göster</label>
    <Field label="Katılan işletmeler" hint={`${value.businessIds.length} işletme seçili. Uygulamada yayımlanan kampanyalar için en az bir işletme seçin.`}>
      <Input aria-label="İşletme ara" placeholder="İşletme adıyla ara…" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
      <div className="mt-2 max-h-44 space-y-1 overflow-y-auto rounded-xl border border-slate-200 bg-white p-2">
        {loading ? <p className="p-2 text-sm text-slate-500">Yükleniyor…</p> : error ? <p role="alert" className="p-2 text-sm text-red-700">{error}</p> : businesses.length === 0 ? <p className="p-2 text-sm text-slate-500">İşletme bulunamadı.</p> : businesses.map((b) => <label key={b.id} className="flex cursor-pointer items-center gap-2 rounded-lg p-2 text-sm hover:bg-slate-50">
          <input type="checkbox" checked={value.businessIds.includes(b.id)} onChange={(e) => onChange({ businessIds: e.target.checked ? [...value.businessIds, b.id] : value.businessIds.filter((id) => id !== b.id), merchantConsentConfirmed: false })} />{b.name}
        </label>)}
      </div>
      <div className="mt-2 flex gap-2"><Button size="sm" variant="ghost" disabled={loading || page <= 1} onClick={() => setPage(page - 1)}>Önceki</Button><Button size="sm" variant="ghost" disabled={loading || !hasMore} onClick={() => setPage(page + 1)}>Sonraki</Button><Button size="sm" variant="ghost" onClick={() => onChange({ businessIds: [], merchantConsentConfirmed: false })}>Seçimi temizle</Button></div>
    </Field>
    <p className="text-sm leading-relaxed text-slate-600">İndirim, işletme payını ve platform komisyonunu birlikte azaltır. Ödeme sonrasında iptal veya iade edilen siparişlerde kupon hakkı yeniden açılmaz.</p>
    <label className="flex items-start gap-2 text-sm"><input className="mt-1" type="checkbox" checked={value.merchantConsentConfirmed} onChange={(e) => onChange({ merchantConsentConfirmed: e.target.checked })} />Seçili işletmelerin indirim paylaşımına katılımını doğruladım.</label>
  </div>;
}
