"use client";

import { useCallback, useEffect, useState } from "react";
import { Ticket, Plus } from "lucide-react";
import type { Coupon, CouponType, Pagination as Pg } from "@/lib/types";
import { getCoupons, createCoupon, updateCoupon, deleteCoupon } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatPrice, formatDate } from "@/lib/format";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Pagination } from "@/components/ui/Pagination";
import { Button } from "@/components/ui/Button";
import { Field, Input, Select } from "@/components/ui/Field";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";
import { Modal } from "@/components/ui/Modal";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { Spinner } from "@/components/ui/Spinner";

interface Form {
  code: string;
  discountType: CouponType;
  discountValue: string;
  minOrderAmount: string;
  maxUsage: string;
  expiresAt: string;
  isActive: boolean;
}

const emptyForm: Form = {
  code: "",
  discountType: "percentage",
  discountValue: "",
  minOrderAmount: "0",
  maxUsage: "100",
  expiresAt: "",
  isActive: true,
};

export default function AdminCouponsPage() {
  const [rows, setRows] = useState<Coupon[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [page, setPage] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<Coupon | "new" | null>(null);
  const [form, setForm] = useState<Form>(emptyForm);
  const [formError, setFormError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [toDelete, setToDelete] = useState<Coupon | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getCoupons({ page, limit: 20 })
      .then((r) => {
        setRows(r.data);
        setPagination(r.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page]);

  useEffect(() => {
    load();
  }, [load]);

  function openNew() {
    setEditing("new");
    setForm(emptyForm);
    setFormError(null);
  }
  function openEdit(c: Coupon) {
    setEditing(c);
    setForm({
      code: c.code,
      discountType: c.discountType,
      discountValue: String(c.discountValue),
      minOrderAmount: String(c.minOrderAmount),
      maxUsage: String(c.maxUsage),
      expiresAt: c.expiresAt ? c.expiresAt.slice(0, 10) : "",
      isActive: c.isActive,
    });
    setFormError(null);
  }

  async function save() {
    setBusy(true);
    setFormError(null);
    const payload = {
      discountType: form.discountType,
      discountValue: Number(form.discountValue),
      minOrderAmount: Number(form.minOrderAmount),
      maxUsage: Number(form.maxUsage),
      expiresAt: form.expiresAt
        ? new Date(`${form.expiresAt}T23:59:59`).toISOString()
        : "",
    };
    try {
      if (editing === "new") {
        await createCoupon({ code: form.code, ...payload });
      } else if (editing) {
        await updateCoupon(editing.id, { ...payload, isActive: form.isActive });
      }
      setEditing(null);
      load();
    } catch (e) {
      setFormError(e instanceof ApiError ? e.message : "Kaydedilemedi");
    } finally {
      setBusy(false);
    }
  }

  async function doDelete() {
    if (!toDelete) return;
    setBusy(true);
    try {
      await deleteCoupon(toDelete.id);
      setToDelete(null);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Silinemedi");
      setToDelete(null);
    } finally {
      setBusy(false);
    }
  }

  const columns: Column<Coupon>[] = [
    { key: "code", header: "Kod", render: (c) => <span className="font-mono font-semibold">{c.code}</span> },
    {
      key: "value",
      header: "İndirim",
      render: (c) => (c.discountType === "percentage" ? `%${c.discountValue}` : formatPrice(c.discountValue)),
    },
    { key: "min", header: "Min. tutar", render: (c) => formatPrice(c.minOrderAmount) },
    { key: "usage", header: "Kullanım", render: (c) => `${c.currentUsage}/${c.maxUsage}` },
    { key: "expires", header: "Bitiş", render: (c) => formatDate(c.expiresAt) },
    { key: "active", header: "Durum", render: (c) => <Badge tone={c.isActive ? "green" : "slate"}>{c.isActive ? "Aktif" : "Pasif"}</Badge> },
    {
      key: "actions",
      header: "",
      className: "text-right",
      render: (c) => (
        <div className="flex justify-end gap-2">
          <Button size="sm" variant="outline" onClick={() => openEdit(c)}>Düzenle</Button>
          <Button size="sm" variant="ghost" className="text-red-600 hover:bg-red-50" onClick={() => setToDelete(c)}>Sil</Button>
        </div>
      ),
    },
  ];

  return (
    <>
      <PanelHeader
        title="Kuponlar"
        description="İndirim kuponlarını yönet."
        action={<Button onClick={openNew}><Plus className="h-4 w-4" /> Yeni kupon</Button>}
      />
      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}
      <div className="space-y-4">
        <DataTable
          columns={columns}
          rows={rows ?? []}
          keyField={(c) => c.id}
          loading={!rows}
          empty={<EmptyState icon={Ticket} title="Kupon yok" description="İlk kuponu oluşturun." action={<Button onClick={openNew}>Yeni kupon</Button>} />}
        />
        {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
      </div>

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing === "new" ? "Yeni kupon" : "Kuponu düzenle"}
        footer={
          <>
            <Button variant="ghost" onClick={() => setEditing(null)} disabled={busy}>Vazgeç</Button>
            <Button onClick={save} disabled={busy}>{busy ? <Spinner className="h-5 w-5" /> : "Kaydet"}</Button>
          </>
        }
      >
        {formError ? <Alert tone="error" className="mb-3">{formError}</Alert> : null}
        <div className="space-y-4">
          {editing === "new" ? (
            <Field label="Kupon kodu">
              <Input value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} placeholder="HOSGELDIN10" />
            </Field>
          ) : null}
          <div className="grid grid-cols-2 gap-4">
            <Field label="İndirim türü">
              <Select value={form.discountType} onChange={(e) => setForm({ ...form, discountType: e.target.value as CouponType })}>
                <option value="percentage">Yüzde (%)</option>
                <option value="fixed">Sabit (₺)</option>
              </Select>
            </Field>
            <Field label="İndirim değeri">
              <Input type="number" value={form.discountValue} onChange={(e) => setForm({ ...form, discountValue: e.target.value })} />
            </Field>
            <Field label="Min. sipariş (₺)">
              <Input type="number" value={form.minOrderAmount} onChange={(e) => setForm({ ...form, minOrderAmount: e.target.value })} />
            </Field>
            <Field label="Maks. kullanım">
              <Input type="number" value={form.maxUsage} onChange={(e) => setForm({ ...form, maxUsage: e.target.value })} />
            </Field>
          </div>
          <Field label="Son kullanma tarihi">
            <Input type="date" value={form.expiresAt} onChange={(e) => setForm({ ...form, expiresAt: e.target.value })} />
          </Field>
          {editing !== "new" ? (
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} />
              Aktif
            </label>
          ) : null}
        </div>
      </Modal>

      <ConfirmDialog
        open={toDelete !== null}
        onClose={() => setToDelete(null)}
        onConfirm={doDelete}
        loading={busy}
        tone="danger"
        title="Kuponu sil"
        description={`"${toDelete?.code}" kuponu silinecek.`}
        confirmLabel="Sil"
      />
    </>
  );
}
