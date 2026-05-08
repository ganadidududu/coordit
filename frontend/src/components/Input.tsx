import type { InputHTMLAttributes } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
}

export function Input({ label, className = "", ...props }: InputProps) {
  return (
    <label className="grid gap-2 text-sm">
      <span className="font-medium text-ink">{label}</span>
      <input
        className={`h-11 rounded-md border border-line px-3 text-sm outline-none focus:border-ink ${className}`}
        {...props}
      />
    </label>
  );
}

