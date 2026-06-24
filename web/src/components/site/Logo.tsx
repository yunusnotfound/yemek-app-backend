import Link from "next/link";
import { Leaf } from "lucide-react";
import { cn } from "@/lib/cn";

export function Logo({
  className,
  href = "/",
  tone = "dark",
}: {
  className?: string;
  href?: string;
  tone?: "dark" | "light";
}) {
  return (
    <Link
      href={href}
      className={cn("inline-flex items-center gap-2.5", className)}
    >
      <span className="grid h-9 w-9 place-items-center rounded-xl bg-brand-600 text-white shadow-sm">
        <Leaf className="h-5 w-5" />
      </span>
      <span
        className={cn(
          "font-display text-2xl font-black uppercase leading-none tracking-tight",
          tone === "light" ? "text-white" : "text-ink",
        )}
      >
        Bitir<span className="text-brand-500">gitsin</span>
      </span>
    </Link>
  );
}
