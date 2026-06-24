"use client";

import { useCallback, useEffect, useState } from "react";
import { Tags, Plus } from "lucide-react";
import type { Category } from "@/lib/types";
import { getCategories, createCategory, updateCategory, deleteCategory } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";
import { Modal } from "@/components/ui/Modal";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { Spinner } from "@/components/ui/Spinner";

export default function AdminCategoriesPage() {
  const [rows, setRows] = useState<Category[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<Category | "new" | null>(null);
  const [name, setName] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [toDelete, setToDelete] = useState<Category | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getCategories()
      .then((r) => setRows(r.categories))
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  function openNew() {
    setEditing("new");
    setName("");
    setFormError(null);
  }
  function openEdit(c: Category) {
    setEditing(c);
    setName(c.name);
    setFormError(null);
  }

  async function save() {
    setBusy(true);
    setFormError(null);
    try {
      if (editing === "new") await createCategory({ name });
      else if (editing) await updateCategory(editing.id, { name });
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
      await deleteCategory(toDelete.id);
      setToDelete(null);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Silinemedi");
      setToDelete(null);
    } finally {
      setBusy(false);
    }
  }

  const columns: Column<Category>[] = [
    { key: "name", header: "Ad", render: (c) => <span className="font-medium text-slate-900">{c.name}</span> },
    { key: "slug", header: "Slug", render: (c) => <span className="font-mono text-xs text-slate-500">{c.slug}</span> },
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
        title="Kategoriler"
        description="İşletme kategorilerini yönet."
        action={<Button onClick={openNew}><Plus className="h-4 w-4" /> Yeni kategori</Button>}
      />
      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}
      <DataTable
        columns={columns}
        rows={rows ?? []}
        keyField={(c) => String(c.id)}
        loading={!rows}
        empty={<EmptyState icon={Tags} title="Kategori yok" description="İlk kategoriyi ekleyin." action={<Button onClick={openNew}>Yeni kategori</Button>} />}
      />

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing === "new" ? "Yeni kategori" : "Kategoriyi düzenle"}
        footer={
          <>
            <Button variant="ghost" onClick={() => setEditing(null)} disabled={busy}>Vazgeç</Button>
            <Button onClick={save} disabled={busy || !name.trim()}>{busy ? <Spinner className="h-5 w-5" /> : "Kaydet"}</Button>
          </>
        }
      >
        {formError ? <Alert tone="error" className="mb-3">{formError}</Alert> : null}
        <Field label="Kategori adı" htmlFor="catname" hint="Slug otomatik oluşturulur.">
          <Input id="catname" value={name} onChange={(e) => setName(e.target.value)} placeholder="Örn. Fırın & Pastane" />
        </Field>
      </Modal>

      <ConfirmDialog
        open={toDelete !== null}
        onClose={() => setToDelete(null)}
        onConfirm={doDelete}
        loading={busy}
        tone="danger"
        title="Kategoriyi sil"
        description={`"${toDelete?.name}" silinecek. Bağlı işletme varsa silinemez.`}
        confirmLabel="Sil"
      />
    </>
  );
}
