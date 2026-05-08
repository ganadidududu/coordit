import { Button } from "../../../components/Button";
import { FormSection } from "../../../components/FormSection";
import { Input } from "../../../components/Input";
import { Layout } from "../../../components/Layout";
import { MeasurementInputGroup } from "../../../components/MeasurementInputGroup";

export default function WardrobeSizesPage() {
  return (
    <Layout>
      <h1 className="text-3xl font-semibold">보유 의류 사이즈 입력</h1>
      <form className="mt-8">
        <FormSection title="Owned measurements" description="잘 맞는 옷의 실제 치수를 cm 단위로 입력합니다.">
          <Input label="Clothing item ID" placeholder="uuid" />
          <MeasurementInputGroup />
          <Button type="button">Save measurements</Button>
        </FormSection>
      </form>
    </Layout>
  );
}

