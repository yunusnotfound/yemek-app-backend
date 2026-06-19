"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from "react";
import type { BusinessWithStats } from "@/lib/types";
import { getMyBusinesses } from "@/lib/api/panel";

type BusinessContextValue = {
  businesses: BusinessWithStats[];
  active: BusinessWithStats | null;
  loading: boolean;
  error: string | null;
  setActiveId: (id: string) => void;
  refresh: () => Promise<void>;
};

const BusinessContext = createContext<BusinessContextValue | null>(null);

export function BusinessProvider({ children }: { children: React.ReactNode }) {
  const [businesses, setBusinesses] = useState<BusinessWithStats[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await getMyBusinesses();
      setBusinesses(res.data);
      setActiveId((prev) =>
        prev && res.data.some((b) => b.id === prev)
          ? prev
          : res.data[0]?.id ?? null,
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "İşletmeler yüklenemedi");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const active = businesses.find((b) => b.id === activeId) ?? null;

  return (
    <BusinessContext.Provider
      value={{ businesses, active, loading, error, setActiveId, refresh }}
    >
      {children}
    </BusinessContext.Provider>
  );
}

export function useBusiness(): BusinessContextValue {
  const ctx = useContext(BusinessContext);
  if (!ctx) {
    throw new Error("useBusiness, BusinessProvider içinde kullanılmalı");
  }
  return ctx;
}
