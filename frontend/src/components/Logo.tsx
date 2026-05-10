"use client";

import { useEffect, useState } from "react";

interface LogoProps {
  size?: number;
}

export function Logo({ size = 24 }: LogoProps) {
  const [src, setSrc] = useState<string | null>(null);

  useEffect(() => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement("canvas");
      canvas.width  = img.naturalWidth;
      canvas.height = img.naturalHeight;
      const ctx = canvas.getContext("2d")!;
      ctx.drawImage(img, 0, 0);
      const id = ctx.getImageData(0, 0, canvas.width, canvas.height);
      for (let i = 0; i < id.data.length; i += 4) {
        if (id.data[i] > 230 && id.data[i + 1] > 230 && id.data[i + 2] > 230) {
          id.data[i + 3] = 0;
        }
      }
      ctx.putImageData(id, 0, 0);
      setSrc(canvas.toDataURL("image/png"));
    };
    img.src = "/logo.png";
  }, []);

  if (!src) return null;

  return (
    <img
      src={src}
      alt="Coordit"
      style={{ height: size * 2.2, width: "auto", display: "block", imageRendering: "auto" }}
    />
  );
}
