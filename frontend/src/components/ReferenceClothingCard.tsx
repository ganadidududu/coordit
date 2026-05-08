import { Card } from "./Card";

export function ReferenceClothingCard() {
  return (
    <Card>
      <p className="text-xs uppercase text-muted">Active reference</p>
      <h3 className="mt-2 text-base font-semibold">잘 맞는 기준 의류</h3>
      <p className="mt-3 text-sm leading-6 text-muted">
        보유 의류 중 실제 핏이 좋은 옷을 기준으로 설정합니다.
      </p>
    </Card>
  );
}

