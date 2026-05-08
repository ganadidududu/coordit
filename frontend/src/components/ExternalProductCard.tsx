import { Card } from "./Card";

interface Props {
  productName: string;
  mallName?: string;
  category: string;
}

export function ExternalProductCard({ productName, mallName, category }: Props) {
  return (
    <Card>
      <p className="text-xs uppercase text-muted">{mallName ?? "External shop"}</p>
      <h3 className="mt-2 text-base font-semibold">{productName}</h3>
      <p className="mt-3 text-sm text-muted">{category}</p>
    </Card>
  );
}

