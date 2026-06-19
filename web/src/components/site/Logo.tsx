import Link from "next/link";
import { Leaf } from "lucide-react";
import { cn } from "@/lib/cn";

export function Logo({
  className,
  href = "/",
}: {
  className?: string;
  href?: string;
}) {
  return (
    <Link
      href={href}
      className={cn(
        "inline-flex items-center gap-2 text-lg font-extrabold tracking-tight text-slate-900",
        className,
      )}
    >
      <span className="grid h-9 w-9 place-items-center rounded-xl bg-brand-600 text-white shadow-sm">
        <Leaf className="h-5 w-5" />
      </span>
      <span>
        Bitir<span className="text-brand-600">Yemek</span>
      </span>
    </Link>
  );
}
