import Image from "next/image";
import { cn } from "@/lib/cn";

type PaymentMethodsProps = {
  className?: string;
  compact?: boolean;
};

/** Official artwork stays on white, with its native colors and proportions. */
export function PaymentMethods({
  className,
  compact = false,
}: PaymentMethodsProps) {
  return (
    <ul
      aria-label="Ödeme yöntemleri"
      className={cn(
        "inline-flex max-w-full flex-wrap items-center justify-center rounded-2xl bg-white",
        compact
          ? "gap-x-1 gap-y-2 px-3 py-1.5 sm:px-4"
          : "gap-x-1.5 gap-y-2 px-3 py-2 sm:gap-x-3 sm:px-5",
        className,
      )}
    >
      <li className="flex shrink-0 items-center justify-center">
        <Image
          src="/payments/iyzico-ile-ode.svg"
          alt="iyzico ile Öde"
          width={1074}
          height={377}
          className={cn(
            "h-auto",
            compact ? "w-[110px] sm:w-[126px]" : "w-[114px] sm:w-[143px]",
          )}
        />
      </li>
      <li className="flex shrink-0 items-center justify-center">
        {/* The official Visa file includes its required clear space. */}
        <Image
          src="/payments/visa.svg"
          alt="Visa"
          width={278}
          height={169}
          className={cn(
            "h-auto w-[78px]",
            compact ? "sm:w-[100px]" : "sm:w-[106px]",
          )}
        />
      </li>
      <li className="flex shrink-0 items-center justify-center">
        <Image
          src="/payments/mastercard.svg"
          alt="Mastercard"
          width={390}
          height={238}
          className={cn(
            "h-auto",
            compact ? "w-[42px] sm:w-[46px]" : "w-[44px] sm:w-[52px]",
          )}
        />
      </li>
    </ul>
  );
}
