import { Button } from "../../../components/Button";
import { FormSection } from "../../../components/FormSection";
import { Input } from "../../../components/Input";
import { Layout } from "../../../components/Layout";
import { MeasurementInputGroup } from "../../../components/MeasurementInputGroup";

export default function ExternalProductSizesPage() {
  return (
    <Layout>
      <h1 className="text-3xl font-semibold">외부 상품 사이즈 입력</h1>
      <form className="mt-8">
        <FormSection title="Size chart row" description="상품의 사이즈별 실측을 한 행씩 입력합니다.">
          <Input label="External product ID" placeholder="uuid" />
          <Input label="Size label" placeholder="L" />
          <MeasurementInputGroup />
          <Button type="button">Save size row</Button>
        </FormSection>
      </form>
    </Layout>
  );
}

