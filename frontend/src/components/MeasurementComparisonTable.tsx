import type { FitRecommendationResponse, MeasurementFields } from "../lib/types";

const labels: Record<keyof MeasurementFields, string> = {
  total_length: "총장",
  shoulder_width: "어깨",
  chest_width: "가슴단면",
  sleeve_length: "소매",
  waist_width: "허리",
  hip_width: "엉덩이",
  rise: "밑위",
  outseam: "아웃심"
};

export function MeasurementComparisonTable({ result }: { result: FitRecommendationResponse }) {
  return (
    <div className="overflow-hidden rounded-md border border-line bg-white">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-line bg-neutral-50">
          <tr>
            <th className="p-3 font-medium">부위</th>
            <th className="p-3 font-medium">차이</th>
            <th className="p-3 font-medium">상태</th>
          </tr>
        </thead>
        <tbody>
          {(Object.entries(result.diff) as [keyof MeasurementFields, number][]).map(([key, diff]) => (
            <tr key={key} className="border-b border-line last:border-b-0">
              <td className="p-3">{labels[key]}</td>
              <td className="p-3">{diff > 0 ? `+${diff}` : diff}cm</td>
              <td className="p-3">{result.partStatuses[key] ?? "similar"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
