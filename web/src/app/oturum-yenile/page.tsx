import { safeLocalPath } from "@/lib/auth/safe-redirect";
import { SessionRecovery } from "@/components/auth/SessionRecovery";

export default async function Page({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const { next } = await searchParams;
  const safePath = safeLocalPath(next);
  return <SessionRecovery next={safePath} />;
}
