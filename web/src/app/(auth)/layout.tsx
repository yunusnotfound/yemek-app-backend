import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Logo } from "@/components/site/Logo";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-dvh flex-col bg-gradient-to-b from-brand-50 to-white">
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-4 py-5 sm:px-6">
        <Logo />
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-sm font-medium text-slate-600 hover:text-brand-700"
        >
          <ArrowLeft className="h-4 w-4" /> Ana sayfa
        </Link>
      </header>

      <main className="flex flex-1 items-center justify-center px-4 py-10 sm:px-6">
        <div className="w-full max-w-md">{children}</div>
      </main>
    </div>
  );
}
