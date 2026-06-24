"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Users } from "lucide-react";
import type { Role, User, Pagination as Pg } from "@/lib/types";
import { getUsers } from "@/lib/api/admin";
import { formatDate } from "@/lib/format";
import { roleLabel } from "@/lib/adminFormat";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { Tabs } from "@/components/ui/Tabs";
import { Pagination } from "@/components/ui/Pagination";
import { Input } from "@/components/ui/Field";
import { Badge } from "@/components/ui/Badge";
import { Alert } from "@/components/ui/Alert";
import { EmptyState } from "@/components/ui/EmptyState";

type Filter = "all" | Role;
const FILTERS = [
  { key: "all" as const, label: "Tümü" },
  { key: "customer" as const, label: "Müşteri" },
  { key: "business_owner" as const, label: "İşletme" },
  { key: "admin" as const, label: "Admin" },
];

export default function AdminUsersPage() {
  const router = useRouter();
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<User[] | null>(null);
  const [pagination, setPagination] = useState<Pg | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setRows(null);
    setError(null);
    getUsers({ page, limit: 20, search: search || undefined, role: filter === "all" ? undefined : filter })
      .then((res) => {
        setRows(res.data);
        setPagination(res.pagination);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Yüklenemedi"));
  }, [page, search, filter]);

  useEffect(() => {
    load();
  }, [load]);

  const columns: Column<User>[] = [
    { key: "name", header: "Ad", render: (u) => <span className="font-medium text-slate-900">{u.name}</span> },
    { key: "email", header: "E-posta", render: (u) => u.email },
    {
      key: "role",
      header: "Rol",
      render: (u) => <Badge tone={u.role === "admin" ? "red" : u.role === "business_owner" ? "blue" : "slate"}>{roleLabel(u.role)}</Badge>,
    },
    {
      key: "verified",
      header: "E-posta",
      render: (u) => <Badge tone={u.isEmailVerified ? "green" : "amber"}>{u.isEmailVerified ? "Doğrulı" : "Bekliyor"}</Badge>,
    },
    { key: "createdAt", header: "Kayıt", render: (u) => formatDate(u.createdAt) },
  ];

  return (
    <>
      <PanelHeader title="Kullanıcılar" description="Kullanıcıları görüntüle ve yönet." />
      <div className="space-y-4">
        <Tabs items={FILTERS} value={filter} onChange={(k) => { setFilter(k); setPage(1); }} />
        <Input
          placeholder="Ad veya e-posta ara…"
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          className="max-w-sm"
        />
        {error ? (
          <Alert tone="error">{error}</Alert>
        ) : (
          <>
            <DataTable
              columns={columns}
              rows={rows ?? []}
              keyField={(u) => u.id}
              loading={!rows}
              empty={<EmptyState icon={Users} title="Kullanıcı yok" description="Bu filtreye uygun kullanıcı bulunmuyor." />}
              onRowClick={(u) => router.push(`/admin/kullanicilar/${u.id}`)}
            />
            {pagination ? <Pagination page={pagination.page} totalPages={pagination.totalPages} onPageChange={setPage} /> : null}
          </>
        )}
      </div>
    </>
  );
}
