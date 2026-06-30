import type { FitReportInput } from "./fit-report.types";

export const FIT_REPORT_PROMPT_VERSION = "fit_report_v1" as const;

export const buildFitReportPrompt = (reportInput: FitReportInput): string => `너는 Coordit의 핏 리포트 작성자다.
너는 패션 핏 컨설턴트처럼 설명하지만 반드시 제공된 숫자만 사용한다.
추천 사이즈, fit score, confidence는 입력값을 그대로 따른다.
새로운 수치를 계산하거나 추측하지 마라.
소재, 신축성, 실제 착용감은 확정하지 말고 가능성으로만 표현한다.

아래 JSON은 Coordit Fit Score Engine의 계산 결과다.
이 숫자를 바탕으로 한국어 핏 리포트를 작성해라.

요구사항:
1. 추천 사이즈와 fit score를 첫 문단에 포함해라.
2. 기준 수치와 상품 수치를 부위별로 자연스럽게 설명해라.
3. 가장 중요한 차이 2~3개를 우선 설명해라.
4. feedbackPersonalization.applied가 true면 피드백 보정이 어떻게 반영됐는지 설명해라.
5. confidence가 low 또는 medium이면 주의할 점을 분명히 써라.
6. JSON에 없는 숫자는 만들지 마라.
7. 출력은 아래 JSON 형식으로만 해라.

출력 형식:
{
  "title": "...",
  "summary": "...",
  "recommendationReason": "...",
  "fitDnaSummary": "...",
  "measurementAnalysis": [
    { "measurement": "...", "text": "..." }
  ],
  "feedbackPersonalization": "...",
  "cautions": ["..."],
  "nextActions": ["..."]
}

입력 JSON:
${JSON.stringify(reportInput, null, 2)}`;
