"use client";

import { useEffect } from "react";

export function SessionRecovery({ next }: { next: string }) {
  useEffect(() => {
    let active = true;
    void fetch("/api/auth/refresh", { method: "POST" }).then((res) => {
      if (active) window.location.replace(res.ok ? next : `/giris?next=${encodeURIComponent(next)}`);
    }).catch(() => {
      if (active) window.location.replace(`/giris?next=${encodeURIComponent(next)}`);
    });
    return () => { active = false; };
  }, [next]);
  return <p className="p-8 text-center">Oturum yenileniyor…</p>;
}
