import { Input } from "./Input";

const fields = [
  ["total_length", "총장"],
  ["shoulder_width", "어깨"],
  ["chest_width", "가슴단면"],
  ["sleeve_length", "소매"],
  ["waist_width", "허리단면"],
  ["hip_width", "엉덩이단면"],
  ["rise", "밑위"],
  ["outseam", "아웃심"]
] as const;

export function MeasurementInputGroup() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {fields.map(([name, label]) => (
        <Input key={name} name={name} label={`${label} (cm)`} type="number" step="0.1" />
      ))}
    </div>
  );
}

