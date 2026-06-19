"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import type { SurprisePackage } from "@/lib/types";
import { getPackage } from "@/lib/api/panel";
import { PackageForm } from "@/components/panel/PackageForm";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { RequireBusiness } from "@/components/panel/RequireBusiness";
import { LoadingBlock } from "@/components/ui/Spinner";
import { Alert } from "@/components/ui/Alert";

export default function EditPackagePage() {
  const router = useRouter();
  const { id } = useParams<{ id: string }>();
  const [pkg, setPkg] = useState<SurprisePackage | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getPackage(id)
      .then((res) => setPkg(res.package))
      .catch((e) => setError(e instanceof Error ? e.message : "Paket yüklenemedi"));
  }, [id]);

  return (
    <>
      <PanelHeader title="Paketi düzenle" description="Paket bilgilerini güncelle." />
      <RequireBusiness>
        {(b) =>
          error ? (
            <Alert tone="error">{error}</Alert>
          ) : !pkg ? (
            <LoadingBlock />
          ) : (
            <PackageForm
              businessId={b.id}
              pkg={pkg}
              onSaved={() => router.push("/panel/paketler")}
            />
          )
        }
      </RequireBusiness>
    </>
  );
}
