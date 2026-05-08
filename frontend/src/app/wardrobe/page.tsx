"use client";

import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { Button } from "../../components/Button";
import { ClothingItemCard } from "../../components/ClothingItemCard";
import { FormSection } from "../../components/FormSection";
import { Input } from "../../components/Input";
import { Layout } from "../../components/Layout";
import { api } from "../../lib/api";
import type { ClothingItem } from "../../lib/types";

const numberValue = (formData: FormData, key: string) => {
  const value = String(formData.get(key) ?? "");
  return value ? Number(value) : undefined;
};

export default function WardrobePage() {
  const [items, setItems] = useState<ClothingItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async () => setItems(await api<ClothingItem[]>("/clothing-items"));

  useEffect(() => {
    load().catch((err) => setError(err instanceof Error ? err.message : "Failed to load wardrobe"));
  }, []);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setLoading(true);
    setError(null);
    try {
      const item = await api<ClothingItem>("/clothing-items", {
        method: "POST",
        body: {
          name: formData.get("name"),
          brand: formData.get("brand"),
          category: formData.get("category"),
          fitType: formData.get("fitType"),
          sizeLabel: formData.get("sizeLabel")
        }
      });
      await api(`/clothing-items/${item.id}/sizes`, {
        method: "POST",
        body: {
          sizeLabel: formData.get("sizeLabel"),
          total_length: numberValue(formData, "total_length"),
          shoulder_width: numberValue(formData, "shoulder_width"),
          chest_width: numberValue(formData, "chest_width"),
          sleeve_length: numberValue(formData, "sleeve_length"),
          waist_width: numberValue(formData, "waist_width"),
          hip_width: numberValue(formData, "hip_width"),
          rise: numberValue(formData, "rise"),
          inseam: numberValue(formData, "inseam")
        }
      });
      event.currentTarget.reset();
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save clothing item");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <h1 className="text-3xl font-semibold">보유 의류 등록</h1>
      <form className="mt-8" onSubmit={submit}>
        <FormSection title="Clothing item" description="잘 맞는 옷과 실제 실측을 기준 데이터로 저장합니다.">
          <Input name="name" label="Name" placeholder="예: 가장 잘 맞는 후드티" required />
          <Input name="brand" label="Brand" placeholder="예: Uniqlo" />
          <Input name="category" label="Category" placeholder="hoodie" required />
          <Input name="fitType" label="Fit type" placeholder="relaxed" />
          <Input name="sizeLabel" label="Size label" placeholder="L" />
          <div className="grid gap-3 md:grid-cols-4">
            <Input name="total_length" label="총장" type="number" step="0.1" />
            <Input name="shoulder_width" label="어깨" type="number" step="0.1" />
            <Input name="chest_width" label="가슴단면" type="number" step="0.1" />
            <Input name="sleeve_length" label="소매" type="number" step="0.1" />
            <Input name="waist_width" label="허리" type="number" step="0.1" />
            <Input name="hip_width" label="엉덩이" type="number" step="0.1" />
            <Input name="rise" label="밑위" type="number" step="0.1" />
            <Input name="inseam" label="인심" type="number" step="0.1" />
          </div>
          <Button type="submit" disabled={loading}>{loading ? "Saving..." : "Save clothing item"}</Button>
        </FormSection>
      </form>
      {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {items.map((item) => (
          <ClothingItemCard key={item.id} name={item.name} brand={item.brand ?? "-"} category={item.category} sizeLabel={item.size_label ?? "-"} />
        ))}
      </div>
    </Layout>
  );
}
