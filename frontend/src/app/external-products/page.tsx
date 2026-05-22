"use client";

import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { Button } from "../../components/Button";
import { ExternalProductCard } from "../../components/ExternalProductCard";
import { FormSection } from "../../components/FormSection";
import { Input } from "../../components/Input";
import { Layout } from "../../components/Layout";
import { api } from "../../lib/api";
import type { ExternalProduct } from "../../lib/types";

const numberValue = (formData: FormData, key: string) => {
  const value = String(formData.get(key) ?? "");
  return value ? Number(value) : undefined;
};

export default function ExternalProductsPage() {
  const [products, setProducts] = useState<ExternalProduct[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = async () => setProducts(await api<ExternalProduct[]>("/external-products"));

  useEffect(() => {
    load().catch((err) => setError(err instanceof Error ? err.message : "Failed to load products"));
  }, []);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    try {
      const product = await api<ExternalProduct>("/external-products", {
        method: "POST",
        body: {
          productName: formData.get("productName"),
          brand: formData.get("brand"),
          mallName: formData.get("mallName"),
          productUrl: formData.get("productUrl"),
          category: formData.get("category"),
          fitType: formData.get("fitType")
        }
      });
      const sizeLabels = String(formData.get("sizeLabels") ?? "M,L,XL").split(",").map((value) => value.trim()).filter(Boolean);
      await Promise.all(
        sizeLabels.map((sizeLabel) =>
          api(`/external-products/${product.id}/sizes`, {
            method: "POST",
            body: {
              sizeLabel,
              measurementSource: "manual",
              parsingStatus: "manual",
              total_length: numberValue(formData, "total_length"),
              shoulder_width: numberValue(formData, "shoulder_width"),
              chest_width: numberValue(formData, "chest_width"),
              sleeve_length: numberValue(formData, "sleeve_length"),
              waist_width: numberValue(formData, "waist_width"),
              hip_width: numberValue(formData, "hip_width"),
              rise: numberValue(formData, "rise"),
              outseam: numberValue(formData, "outseam")
            }
          })
        )
      );
      event.currentTarget.reset();
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save product");
    }
  };

  const parseUrl = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const url = new FormData(event.currentTarget).get("url");
    const parsed = await api<Record<string, unknown>>("/external-products/from-url", { method: "POST", body: { url } });
    window.alert(JSON.stringify(parsed, null, 2));
  };

  return (
    <Layout>
      <h1 className="text-3xl font-semibold">외부 상품 등록</h1>
      <form className="mt-8" onSubmit={submit}>
        <FormSection title="External product" description="외부 상품과 사이즈표 실측을 등록합니다.">
          <Input name="productName" label="Product name" placeholder="예: 오버핏 후드티" required />
          <Input name="brand" label="Brand" placeholder="무신사 스탠다드" />
          <Input name="mallName" label="Mall name" placeholder="Musinsa" />
          <Input name="productUrl" label="Product URL" placeholder="https://..." />
          <Input name="category" label="Category" placeholder="hoodie" required />
          <Input name="fitType" label="Fit type" placeholder="relaxed" />
          <Input name="sizeLabels" label="Size labels" placeholder="M,L,XL" />
          <div className="grid gap-3 md:grid-cols-4">
            <Input name="total_length" label="총장" type="number" step="0.1" />
            <Input name="shoulder_width" label="어깨" type="number" step="0.1" />
            <Input name="chest_width" label="가슴단면" type="number" step="0.1" />
            <Input name="sleeve_length" label="소매" type="number" step="0.1" />
            <Input name="waist_width" label="허리" type="number" step="0.1" />
            <Input name="hip_width" label="엉덩이" type="number" step="0.1" />
            <Input name="rise" label="밑위" type="number" step="0.1" />
            <Input name="outseam" label="아웃심" type="number" step="0.1" />
          </div>
          <Button type="submit">Save product and sizes</Button>
        </FormSection>
      </form>
      <form className="mt-6" onSubmit={parseUrl}>
        <FormSection title="URL parser mock" description="OCR/URL 확장을 위한 mock parsing 응답입니다.">
          <Input name="url" label="Product URL" placeholder="https://shop.example/product" required />
          <Button type="submit">Mock parse URL</Button>
        </FormSection>
      </form>
      {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {products.map((product) => (
          <ExternalProductCard key={product.id} productName={product.product_name} mallName={product.mall_name ?? "-"} category={product.category} />
        ))}
      </div>
    </Layout>
  );
}
