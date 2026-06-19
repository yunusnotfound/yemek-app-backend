"use client";

import { useRouter } from "next/navigation";
import { PackageForm } from "@/components/panel/PackageForm";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";

export default function NewPackagePage() {
  const router = useRouter();
  return (
    <>
      <PanelHeader title="Yeni paket" description="Sürpriz paket bilgilerini gir." />
      <RequireBusiness>
        {(b) => (
          <PackageForm
            businessId={b.id}
            onSaved={() => router.push("/panel/paketler")}
          />
        )}
      </RequireBusiness>
    </>
  );
}
