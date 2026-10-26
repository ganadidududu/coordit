import assert from "node:assert/strict";
import { z } from "zod";
import type { FitAnalysisResultRow } from "../../shared/types/database";
import { configureReportTestEnv, FakeSupabaseQuery, fitResultId, useEnrichedFitResult, userId } from "./fit-report.service.test-fixtures";

let paid = true;
class PaidLedgerQuery {
  select(_columns: string): this { return this; }
  eq(_column: string, _value: string | number): this { return this; }
  in(_column: string, _value: readonly string[]): this { return this; }
  limit(_limit: number): this { return this; }
  async maybeSingle() { return { data: paid ? { id: "paid-ledger-entry" } : null, error: null }; }
}

const main = async (): Promise<void> => {
  configureReportTestEnv();
  const [{ supabase }, { generateFitReport }, { authorizeComparisonBundle }] = await Promise.all([
    import("../../config/supabase"), import("./fit-report.service"), import("./fit-report.comparison-bundle")
  ]);
  useEnrichedFitResult();
  Object.defineProperty(supabase, "from", { value: (table: string) => table === "thread_ledger_entries" ? new PaidLedgerQuery() : new FakeSupabaseQuery(table) });
  let debits = 0;
  Object.defineProperty(supabase, "rpc", { value: (name: string, parameters: Record<string, unknown>) => ({
    single: async () => {
      assert.equal(parameters.p_user_id, userId);
      if (name === "get_thread_balance") return { data: { available_threads: 2 }, error: null };
      assert.equal(name, "complete_camera_comparison");
      const artifact = z.record(z.string(), z.unknown()).parse(parameters.p_report_artifact);
      const previous = await new FakeSupabaseQuery("fit_analysis_results").single<FitAnalysisResultRow>();
      assert.ok(previous.data);
      await new FakeSupabaseQuery("fit_analysis_results").update({ result_details: { ...previous.data.result_details, storedFitReport: artifact } }).single();
      debits += 1;
      return { data: { available_threads: 2, status: "consumed", stored_report: artifact }, error: null };
    }
  }) });
  const first = await generateFitReport(userId, fitResultId, { idempotencyKey: "11111111-1111-4111-8111-111111111111", cameraComparison: true });
  assert.equal(debits, 1);
  assert.ok(first.report.measurementAnalysis.length > 0);
  const repeated = await generateFitReport(userId, fitResultId, {
    idempotencyKey: "22222222-2222-4222-8222-222222222222", comparisonBundleAnalysisId: fitResultId, includeDebug: true
  });
  assert.equal(debits, 1);
  assert.equal(repeated.availableThreads, 2);
  assert.ok(repeated.report.measurementAnalysis.length > 0);
  paid = false;
  await assert.rejects(authorizeComparisonBundle(userId, fitResultId, fitResultId), /실타래를 사용한 분석 묶음/);
  assert.equal(debits, 1);
};

main().then(() => console.log("PASS one debit unlocks camera/report bundle; unpaid reuse is rejected"), (error: unknown) => {
  console.error(error instanceof Error ? error.stack : "Camera billing test failed");
  process.exitCode = 1;
});
