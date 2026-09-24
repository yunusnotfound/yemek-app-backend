import type { Metadata } from "next";
import { TvDashboard } from "@/components/admin/TvDashboard";
import { TechnicalTvDashboard } from "@/components/admin/TechnicalTvDashboard";

export const metadata: Metadata = {
  title: "TV Dashboard",
  robots: { index: false, follow: false },
};

export default async function TvDashboardPage({ searchParams }: {
  searchParams: Promise<{ view?: string }>;
}) {
  const { view } = await searchParams;
  return view === "business" ? <TvDashboard /> : <TechnicalTvDashboard />;
}
