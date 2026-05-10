import type { Metadata } from "next";
import type { ReactNode } from "react";
import { AuthProvider } from "../lib/auth-context";
import "../styles/globals.css";

export const metadata: Metadata = {
  title: "Coordit — The Curated Wardrobe",
  description: "기준 옷 기반 핏 분석 · 개인화 옷장 큐레이션",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <AuthProvider>{children}</AuthProvider>
      </body>
    </html>
  );
}
