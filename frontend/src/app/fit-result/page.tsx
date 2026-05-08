"use client";

import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { Button } from "../../components/Button";
import { FitScoreResultCard } from "../../components/FitScoreResultCard";
import { FormSection } from "../../components/FormSection";
import { Layout } from "../../components/Layout";
import { MeasurementComparisonTable } from "../../components/MeasurementComparisonTable";
import { SizeScoreTable } from "../../components/SizeScoreTable";
import { api } from "../../lib/api";
import type { ExternalProduct, FitRecommendationResponse, ReferenceClothing } from "../../lib/types";

export default function FitResultPage() {
  const [references, setReferences] = useState<ReferenceClothing[]>([]);
  const [products, setProducts] = useState<ExternalProduct[]>([]);
  const [selectedReferences, setSelectedReferences] = useState<string[]>([]);
  const [result, setResult] = useState<FitRecommendationResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    Promise.all([api<ReferenceClothing[]>("/reference-clothing"), api<ExternalProduct[]>("/external-products")])
      .then(([refs, externalProducts]) => {
        setReferences(refs.filter((reference) => reference.is_active));
        setProducts(externalProducts);
      })
      .catch((err) => setError(err instanceof Error ? err.message : "Failed to load fit inputs"));
  }, []);

  const runRecommendation = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setLoading(true);
    setError(null);

    try {
      const data = await api<FitRecommendationResponse>("/fit/recommend", {
        method: "POST",
        body: {
          referenceClothingIds: selectedReferences,
          externalProductId: formData.get("externalProductId")
        }
      });
      setResult(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Fit recommendation failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <h1 className="text-3xl font-semibold">Fit 추천 결과</h1>
      <form className="mt-8" onSubmit={runRecommendation}>
        <FormSection title="Run engine" description="기준 의류 실측과 외부 상품 사이즈표를 비교합니다.">
          <div className="grid gap-2 rounded-md border border-line bg-white p-3 text-sm">
            {references.map((reference) => (
              <label key={reference.id} className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={selectedReferences.includes(reference.id)}
                  onChange={(event) => {
                    setSelectedReferences((current) =>
                      event.target.checked
                        ? [...current, reference.id]
                        : current.filter((id) => id !== reference.id)
                    );
                  }}
                />
                <span>{reference.nickname ?? reference.category} / {reference.fit_type} / {reference.preference_score}</span>
              </label>
            ))}
          </div>
          <label className="grid gap-2 text-sm">
            <span className="font-medium text-ink">External product</span>
            <select name="externalProductId" className="h-11 rounded-md border border-line px-3" required>
              <option value="">선택</option>
              {products.map((product) => (
                <option key={product.id} value={product.id}>{product.product_name} / {product.category}</option>
              ))}
            </select>
          </label>
          <Button type="submit" disabled={loading || selectedReferences.length === 0}>
            {loading ? "Calculating..." : "Recommend size"}
          </Button>
        </FormSection>
      </form>
      {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
      {result ? (
        <div className="mt-8 grid gap-6">
          <FitScoreResultCard result={result} />
          <MeasurementComparisonTable result={result} />
          <SizeScoreTable scores={result.allSizeScores} />
        </div>
      ) : null}
    </Layout>
  );
}
