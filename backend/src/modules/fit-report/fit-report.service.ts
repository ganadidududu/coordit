import { env } from "../../config/env";
import { createHttpError } from "../../shared/utils/http-error";
import { buildFitReportInput } from "./fit-report.builder";
import { buildFitReportPrompt, FIT_REPORT_PROMPT_VERSION } from "./fit-report.prompt";
import type {
  FitReportInput,
  FitReportJson,
  GenerateFitReportOptions,
  GenerateFitReportResult,
  MeasurementReportRow
} from "./fit-report.types";

interface OllamaGenerateResponse {
  response?: string;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === "object" && !Array.isArray(value);

const asStringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];

const normalizeReportJson = (value: unknown): FitReportJson => {
  if (!isRecord(value)) throw new Error("LLM report was not a JSON object");
  const measurementAnalysisValue = value.measurementAnalysis;
  const measurementAnalysis = Array.isArray(measurementAnalysisValue)
    ? measurementAnalysisValue.flatMap((item) => {
      if (!isRecord(item)) return [];
      const measurement = item.measurement;
      const text = item.text;
      if (typeof measurement !== "string" || typeof text !== "string") return [];
      return [{ measurement, text }];
    })
    : [];

  return {
    title: typeof value.title === "string" ? value.title : "핏 리포트",
    summary: typeof value.summary === "string" ? value.summary : "",
    recommendationReason: typeof value.recommendationReason === "string" ? value.recommendationReason : "",
    fitDnaSummary: typeof value.fitDnaSummary === "string" ? value.fitDnaSummary : "",
    measurementAnalysis,
    feedbackPersonalization:
      typeof value.feedbackPersonalization === "string" ? value.feedbackPersonalization : "",
    cautions: asStringArray(value.cautions),
    nextActions: asStringArray(value.nextActions)
  };
};

const extractJsonObject = (text: string): FitReportJson => {
  try {
    return normalizeReportJson(JSON.parse(text));
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start === -1 || end === -1 || end <= start) {
      throw new Error("LLM response did not contain JSON");
    }
    return normalizeReportJson(JSON.parse(text.slice(start, end + 1)));
  }
};

const formatSigned = (value: number): string => `${value > 0 ? "+" : ""}${value}`;

const getTopMeasurements = (measurements: MeasurementReportRow[]): MeasurementReportRow[] =>
  [...measurements].sort((a, b) => Math.abs(b.diff) - Math.abs(a.diff)).slice(0, 3);

export const buildFallbackFitReport = (reportInput: FitReportInput): FitReportJson => {
  const topMeasurements = getTopMeasurements(reportInput.measurements);
  const confidence = reportInput.recommendation.recommendationConfidence;
  return {
    title: `${reportInput.recommendation.recommendedSize} 사이즈 핏 리포트`,
    summary:
      `${reportInput.recommendation.recommendedSize} 사이즈가 ` +
      `${reportInput.recommendation.fitScore}점으로 가장 적합합니다. ` +
      `추천 신뢰도는 ${confidence}입니다.`,
    recommendationReason:
      `추천 사이즈는 weighted distance ${reportInput.recommendation.weightedFitDistance} 기준으로 가장 가까운 후보입니다.` +
      (reportInput.recommendation.scoreGapToSecond !== null
        ? ` 2위와의 점수 차이는 ${reportInput.recommendation.scoreGapToSecond}점입니다.`
        : ""),
    fitDnaSummary:
      `기준 의류 ${reportInput.referenceClothingSummary.length}개를 바탕으로 나에게 맞는 기준 수치를 만들었습니다. ` +
      (reportInput.feedbackPersonalization.applied
        ? `최근 피드백 ${reportInput.feedbackPersonalization.sampleCount}개가 보정에 반영됐습니다.`
        : "반영된 피드백 보정은 없습니다."),
    measurementAnalysis: topMeasurements.map((row) => ({
      measurement: row.label,
      text:
        `${row.label}은 기준 ${row.ideal}cm, 상품 ${row.product}cm로 ` +
        `${formatSigned(row.diff)}cm 차이입니다. 상태는 ${row.status ?? "unknown"}입니다.`
    })),
    feedbackPersonalization: reportInput.feedbackPersonalization.applied
      ? "피드백 기반 offset 또는 weight multiplier가 적용되어 사용자 선호에 맞게 기준 수치가 보정됐습니다."
      : "피드백 개인화 보정은 적용되지 않았습니다.",
    cautions: confidence === "high"
      ? ["소재와 신축성에 따라 실제 착용감은 달라질 수 있습니다."]
      : [
        "추천 신뢰도가 아주 높지 않으므로 차이가 큰 부위의 실측을 다시 확인하세요.",
        "소재와 신축성에 따라 실제 착용감은 달라질 수 있습니다."
      ],
    nextActions: [
      "상품 상세 사이즈표를 다시 확인하세요.",
      "구매 후 실제 핏 피드백을 남기면 다음 추천이 더 개인화됩니다."
    ]
  };
};

const callOllama = async (prompt: string, modelName: string): Promise<FitReportJson> => {
  const response = await fetch(env.ollamaGenerateUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: modelName,
      prompt,
      stream: false,
      options: {
        temperature: 0.2,
        top_p: 0.9
      }
    })
  });

  if (!response.ok) {
    throw new Error(`Ollama HTTP ${response.status}`);
  }

  const data = await response.json() as OllamaGenerateResponse;
  if (typeof data.response !== "string") {
    throw new Error("Ollama response was missing response text");
  }
  return extractJsonObject(data.response);
};

export const generateFitReport = async (
  userId: string,
  fitAnalysisResultId: string,
  options: GenerateFitReportOptions = {}
): Promise<GenerateFitReportResult> => {
  const reportInput = await buildFitReportInput(userId, fitAnalysisResultId, options);
  const prompt = buildFitReportPrompt(reportInput);
  const modelName = options.model ?? env.ollamaModel;

  try {
    const report = await callOllama(prompt, modelName);
    return {
      fitAnalysisResultId,
      source: "ollama",
      modelName,
      promptVersion: FIT_REPORT_PROMPT_VERSION,
      report,
      chartData: reportInput.chartData,
      ...(options.includeDebug ? { reportInput, prompt } : {})
    };
  } catch {
    return {
      fitAnalysisResultId,
      source: "fallback",
      modelName,
      promptVersion: FIT_REPORT_PROMPT_VERSION,
      report: buildFallbackFitReport(reportInput),
      chartData: reportInput.chartData,
      ...(options.includeDebug ? { reportInput, prompt } : {})
    };
  }
};
