import { requireAdmin } from "@/lib/auth/server-user";
import { AdminShell } from "@/components/admin/AdminShell";
import { headers } from "next/headers";
import { safeLocalPath } from "@/lib/auth/safe-redirect";

// Sunucu taraflı admin kapısı: admin değilse requireAdmin redirect eder (HTML hiç gönderilmez).
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const requestHeaders = await headers();
  const path = safeLocalPath(requestHeaders.get("x-bitir-admin-path"), "/admin");
  const nextPath = path === "/admin" || path.startsWith("/admin/") ? path : "/admin";
  const user = await requireAdmin(nextPath);
  return <AdminShell user={user}>{children}</AdminShell>;
}
