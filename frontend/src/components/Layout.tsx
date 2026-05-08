import Link from "next/link";
import type { ReactNode } from "react";

const navItems = [
  ["Dashboard", "/dashboard"],
  ["Wardrobe", "/wardrobe"],
  ["Reference", "/reference"],
  ["Products", "/external-products"],
  ["Fit Result", "/fit-result"]
];

export function Layout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-white">
      <header className="border-b border-line">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-4">
          <Link href="/" className="text-xl font-semibold tracking-normal">
            coordit
          </Link>
          <nav className="hidden gap-5 text-sm text-muted md:flex">
            {navItems.map(([label, href]) => (
              <Link key={href} href={href} className="hover:text-ink">
                {label}
              </Link>
            ))}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-5 py-10">{children}</main>
    </div>
  );
}

