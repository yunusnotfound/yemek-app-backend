"use client";

import { useBusiness } from "@/components/panel/BusinessProvider";
import { BusinessForm } from "@/components/panel/BusinessForm";
import { PanelHeader } from "@/components/panel/PanelHeader";
import { LoadingBlock } from "@/components/ui/Spinner";

export default function BusinessPage() {
  const { active, loading, refresh } = useBusiness();
  const isEdit = Boolean(active);

  return (
    <>
      <PanelHeader
        title={isEdit ? "İşletmem" : "İşletme oluştur"}
        description={
          isEdit
            ? "İşletme bilgilerini güncelle."
            : "Paket oluşturabilmek için önce işletme bilgilerini ekle."
        }
      />
      {loading ? (
        <LoadingBlock />
      ) : (
        <BusinessForm
          key={active?.id ?? "new"}
          business={active ?? undefined}
          onSaved={() => {
            void refresh();
          }}
        />
      )}
    </>
  );
}
