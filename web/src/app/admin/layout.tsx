import { requireAdmin } from "@/lib/auth/server-user";
import { AdminShell } from "@/components/admin/AdminShell";

// Sunucu taraflı admin kapısı: admin değilse requireAdmin redirect eder (HTML hiç gönderilmez).
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireAdmin();
  return <AdminShell user={user}>{children}</AdminShell>;
}
