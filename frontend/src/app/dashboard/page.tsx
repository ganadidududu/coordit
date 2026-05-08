import { Card } from "../../components/Card";
import { Layout } from "../../components/Layout";

const steps = [
  "보유 의류 등록",
  "실측 치수 입력",
  "기준 의류 설정",
  "외부 상품 등록",
  "외부 상품 사이즈표 입력",
  "Fit 추천 실행"
];

export default function DashboardPage() {
  return (
    <Layout>
      <h1 className="text-3xl font-semibold">Dashboard</h1>
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {steps.map((step, index) => (
          <Card key={step}>
            <p className="text-sm text-muted">Step {index + 1}</p>
            <h2 className="mt-2 text-lg font-semibold">{step}</h2>
          </Card>
        ))}
      </div>
    </Layout>
  );
}

