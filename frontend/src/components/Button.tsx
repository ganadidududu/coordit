import type { ButtonHTMLAttributes } from "react";

export function Button({ className = "", ...props }: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={`h-11 rounded-md border border-ink bg-ink px-4 text-sm font-medium text-white transition hover:bg-white hover:text-ink ${className}`}
      {...props}
    />
  );
}

