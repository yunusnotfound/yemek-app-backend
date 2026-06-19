import { BusinessProvider } from "@/components/panel/BusinessProvider";
import { PanelShell } from "@/components/panel/PanelShell";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <BusinessProvider>
      <PanelShell>{children}</PanelShell>
    </BusinessProvider>
  );
}
