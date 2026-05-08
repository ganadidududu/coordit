"use client";

import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { Button } from "../../components/Button";
import { FormSection } from "../../components/FormSection";
import { Input } from "../../components/Input";
import { Layout } from "../../components/Layout";
import { api } from "../../lib/api";
import type { ClothingItem, ReferenceClothing } from "../../lib/types";

export default function ReferencePage() {
  const [items, setItems] = useState<ClothingItem[]>([]);
  const [references, setReferences] = useState<ReferenceClothing[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    const [wardrobe, refs] = await Promise.all([
      api<ClothingItem[]>("/clothing-items"),
      api<ReferenceClothing[]>("/reference-clothing")
    ]);
    setItems(wardrobe);
    setReferences(refs);
  };

  useEffect(() => {
    load().catch((err) => setError(err instanceof Error ? err.message : "Failed to load references"));
  }, []);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const item = items.find((candidate) => candidate.id === formData.get("clothingItemId"));
    try {
      await api("/reference-clothing", {
        method: "POST",
        body: {
          clothingItemId: formData.get("clothingItemId"),
          nickname: formData.get("nickname"),
          category: formData.get("category") || item?.category,
          fitType: formData.get("fitType") || item?.fit_type,
          preferenceScore: Number(formData.get("preferenceScore") || 100)
        }
      });
      event.currentTarget.reset();
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save reference clothing");
    }
  };

  return (
    <Layout>
      <h1 className="text-3xl font-semibold">기준 의류 설정</h1>
      <form className="mt-8" onSubmit={submit}>
        <FormSection title="Reference" description="여러 기준 의류를 선호도 점수와 함께 등록합니다.">
          <label className="grid gap-2 text-sm">
            <span className="font-medium text-ink">Clothing item</span>
            <select name="clothingItemId" className="h-11 rounded-md border border-line px-3" required>
              <option value="">선택</option>
              {items.map((item) => (
                <option key={item.id} value={item.id}>{item.name} / {item.category} / {item.size_label}</option>
              ))}
            </select>
          </label>
          <Input name="nickname" label="Nickname" placeholder="가장 편한 후드티" />
          <Input name="category" label="Category" placeholder="hoodie" />
          <Input name="fitType" label="Fit type" placeholder="relaxed" />
          <Input name="preferenceScore" label="Preference score" type="number" min={1} max={100} placeholder="100" />
          <Button type="submit">Set as reference</Button>
        </FormSection>
      </form>
      {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {references.map((reference) => (
          <div key={reference.id} className="rounded-md border border-line bg-white p-4">
            <p className="font-semibold">{reference.nickname ?? reference.category}</p>
            <p className="mt-2 text-sm text-muted">{reference.fit_type} / preference {reference.preference_score}</p>
          </div>
        ))}
      </div>
    </Layout>
  );
}
