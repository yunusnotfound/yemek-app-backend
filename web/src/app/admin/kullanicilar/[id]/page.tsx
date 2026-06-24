"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import type { Business, Order, Role, User } from "@/lib/types";
import { getUser, updateUser, deleteUser } from "@/lib/api/admin";
import { ApiError } from "@/lib/api/errors";
import { formatDate, formatPrice, orderStatusLabel } from "@/lib/format";
import { roleLabel } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { Card, CardBody } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { Field, Select } from "@/components/ui/Field";
import { Alert } from "@/components/ui/Alert";
import { LoadingBlock } from "@/components/ui/Spinner";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";

type UserDetail = User & { businesses?: Business[]; orders?: Order[] };

export default function AdminUserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [user, setUser] = useState<UserDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [role, setRole] = useState<Role>("customer");
  const [confirm, setConfirm] = useState<null | "role" | "delete">(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    getUser(id)
      .then((r) => {
        setUser(r.user);
        setRole(r.user.role);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  async function doUpdate(input: Record<string, unknown>) {
    setBusy(true);
    setError(null);
    try {
      await updateUser(id, input);
      setConfirm(null);
      setUser(null);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "İşlem başarısız");
    } finally {
      setBusy(false);
    }
  }

  async function doDelete() {
    setBusy(true);
    setError(null);
    try {
      await deleteUser(id);
      router.push("/admin/kullanicilar");
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Silinemedi");
      setBusy(false);
    }
  }

  if (error && !user) return <Alert tone="error">{error}</Alert>;
  if (!user) return <LoadingBlock />;

  return (
    <>
      <PanelHeader
        title={user.name}
        description={user.email}
        action={
          <Link href="/admin/kullanicilar" className="text-sm font-medium text-brand-700 hover:underline">
            ← Kullanıcılar
          </Link>
        }
      />

      {error ? <Alert tone="error" className="mb-4">{error}</Alert> : null}

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardBody className="space-y-4">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={user.role === "admin" ? "red" : user.role === "business_owner" ? "blue" : "slate"}>
                {roleLabel(user.role)}
              </Badge>
              <Badge tone={user.isEmailVerified ? "green" : "amber"}>
                {user.isEmailVerified ? "E-posta doğrulı" : "E-posta bekliyor"}
              </Badge>
              <span className="text-xs text-slate-400">Kayıt: {formatDate(user.createdAt)}</span>
            </div>

            <Field label="Rol">
              <Select value={role} onChange={(e) => setRole(e.target.value as Role)}>
                <option value="customer">Müşteri</option>
                <option value="business_owner">İşletme sahibi</option>
                <option value="admin">Admin</option>
              </Select>
            </Field>
            <div className="flex flex-wrap gap-2">
              <Button onClick={() => setConfirm("role")} disabled={role === user.role}>
                Rolü kaydet
              </Button>
              <Button variant="outline" onClick={() => doUpdate({ isEmailVerified: !user.isEmailVerified })} disabled={busy}>
                {user.isEmailVerified ? "Doğrulamayı kaldır" : "E-postayı doğrula"}
              </Button>
              <Button variant="danger" onClick={() => setConfirm("delete")}>
                Kullanıcıyı sil
              </Button>
            </div>
          </CardBody>
        </Card>

        <div className="space-y-4">
          {user.businesses && user.businesses.length > 0 ? (
            <Card>
              <CardBody>
                <h3 className="mb-2 text-sm font-semibold text-slate-900">İşletmeler</h3>
                <ul className="space-y-1 text-sm">
                  {user.businesses.map((b) => (
                    <li key={b.id}>
                      <Link href={`/admin/isletmeler/${b.id}`} className="text-brand-700 hover:underline">
                        {b.name}
                      </Link>
                    </li>
                  ))}
                </ul>
              </CardBody>
            </Card>
          ) : null}

          {user.orders && user.orders.length > 0 ? (
            <Card>
              <CardBody>
                <h3 className="mb-2 text-sm font-semibold text-slate-900">Son siparişler</h3>
                <ul className="space-y-1.5 text-sm">
                  {user.orders.map((o) => (
                    <li key={o.id} className="flex justify-between gap-2">
                      <span className="text-slate-600">{orderStatusLabel(o.status)}</span>
                      <span className="font-medium">{formatPrice(o.finalPrice)}</span>
                    </li>
                  ))}
                </ul>
              </CardBody>
            </Card>
          ) : null}
        </div>
      </div>

      <ConfirmDialog
        open={confirm === "role"}
        onClose={() => setConfirm(null)}
        onConfirm={() => doUpdate({ role })}
        loading={busy}
        tone={role === "admin" ? "danger" : "default"}
        title="Rolü değiştir"
        description={`Kullanıcının rolü "${roleLabel(role)}" olarak değiştirilecek.`}
        requireText={role === "admin" ? "ONAYLA" : undefined}
      />

      <ConfirmDialog
        open={confirm === "delete"}
        onClose={() => setConfirm(null)}
        onConfirm={doDelete}
        loading={busy}
        tone="danger"
        title="Kullanıcıyı sil"
        description="Bu işlem geri alınamaz. Onaylamak için kullanıcının e-postasını yazın."
        requireText={user.email}
        confirmLabel="Sil"
      />
    </>
  );
}
