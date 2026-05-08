import { Card } from "./Card";

interface Props {
  name: string;
  brand?: string;
  category: string;
  sizeLabel?: string;
}

export function ClothingItemCard({ name, brand, category, sizeLabel }: Props) {
  return (
    <Card>
      <p className="text-xs uppercase text-muted">{brand ?? "No brand"}</p>
      <h3 className="mt-2 text-base font-semibold">{name}</h3>
      <p className="mt-3 text-sm text-muted">
        {category} {sizeLabel ? `· ${sizeLabel}` : ""}
      </p>
    </Card>
  );
}

