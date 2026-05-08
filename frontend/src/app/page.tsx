import Link from "next/link";
import { Button } from "../components/Button";
import { Layout } from "../components/Layout";

export default function HomePage() {
  return (
    <Layout>
      <section className="grid min-h-[70vh] content-center gap-8">
        <div className="max-w-3xl">
          <p className="text-sm font-medium text-muted">Reference clothing fit recommendation</p>
          <h1 className="mt-4 text-5xl font-semibold leading-tight md:text-7xl">coordit</h1>
          <p className="mt-6 max-w-2xl text-lg leading-8 text-muted">
            온라인 쇼핑 사이즈 실패를 줄이기 위해, 이미 잘 맞는 옷의 실측과 구매하려는 상품의
            사이즈표를 비교합니다.
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <Link href="/dashboard">
            <Button>Start MVP Flow</Button>
          </Link>
          <Link href="/login" className="inline-flex h-11 items-center rounded-md border border-line px-4 text-sm">
            Login
          </Link>
        </div>
      </section>
    </Layout>
  );
}

