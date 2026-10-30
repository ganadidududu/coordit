import assert from "node:assert/strict";
import { once } from "node:events";
import { z } from "zod";
import {
  configureReportTestEnv,
  FakeSupabaseQuery,
  fitResultId,
  useEnrichedFitResult,
  userId
} from "./fit-report.service.test-fixtures";

class GuestAccountQuery {
  select(_columns: string): this { return this; }
  eq(column: string, value: string): this {
    assert.equal(column, "id");
    assert.equal(value, userId);
    return this;
  }
  async single() { return { data: { is_guest: true }, error: null }; }
}

const responseSchema = z.object({
  source: z.literal("fallback"),
  promptVersion: z.literal("fit_report_v9"),
  availableThreads: z.number(),
  report: z.object({
    garmentFitContext: z.string().min(1),
    sizeTradeoff: z.string().min(1),
    measurementAnalysis: z.array(z.object({ measurement: z.string(), text: z.string().min(1) }))
  }),
  chartData: z.object({
    fitPointScores: z.array(z.object({ key: z.string(), score: z.number() })),
    measurementScores: z.array(z.object({ measurement: z.string(), score: z.number() })),
    idealVsProduct: z.array(z.object({ measurement: z.string(), diff: z.number() }))
  })
});

const main = async (): Promise<void> => {
  // Given: the real HTTP app uses fixture persistence and no external model key.
  configureReportTestEnv();
  process.env.OPENROUTER_API_KEY = "";
  const [{ supabase }, { app }] = await Promise.all([
    import("../../config/supabase"), import("../../app")
  ]);
  useEnrichedFitResult();
  Object.defineProperty(supabase, "from", {
    value: (table: string) => table === "users" ? new GuestAccountQuery() : new FakeSupabaseQuery(table)
  });
  Object.defineProperty(supabase.auth, "getUser", {
    value: async (token: string) => ({
      data: { user: token === "fit-report-http-fixture" ? { id: userId } : null }, error: null
    })
  });
  let debits = 0;
  let conflict = true;
  Object.defineProperty(supabase, "rpc", {
    value: (name: string, params: Record<string, string>) => ({
      single: async () => {
        assert.equal(params.p_user_id, userId);
        if (name === "get_thread_balance") return { data: { available_threads: 34 }, error: null };
        assert.equal(name, "consume_fit_report_thread");
        assert.equal(params.p_fit_analysis_result_id, fitResultId);
        if (conflict) return { data: null, error: { code: "23505", message: "thread_idempotency_conflict" } };
        debits += 1;
        return { data: { available_threads: 34, status: "consumed" }, error: null };
      }
    })
  });
  const server = app.listen(0, "127.0.0.1");
  try {
    await once(server, "listening");
    const address = server.address();
    assert.ok(address && typeof address !== "string");
    const url = `http://127.0.0.1:${address.port}/fit-analysis-results/${fitResultId}/report`;
    const headers = { "Content-Type": "application/json", Authorization: "Bearer fit-report-http-fixture" };

    // When: a client calls the protected endpoint and retries a completed report.
    const unauthorized = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
    const invalid = await fetch(url, { method: "POST", headers, body: "{}" });
    const body = JSON.stringify({ idempotencyKey: "77777777-7777-4777-8777-777777777777" });
    const mismatchedKey = await fetch(url, { method: "POST", headers, body });
    assert.equal(mismatchedKey.status, 409);
    assert.equal(debits, 0);
    conflict = false;
    const first = await fetch(url, { method: "POST", headers, body });
    assert.equal(first.status, 201, JSON.stringify(await first.clone().json()));
    const firstBody = responseSchema.parse(await first.json());
    const retry = await fetch(url, { method: "POST", headers, body });
    const retryBody = responseSchema.parse(await retry.json());

    // Then: auth, DTO shape, deterministic scores, persistence and one debit hold over HTTP.
    assert.equal(unauthorized.status, 401);
    assert.equal(invalid.status, 400);
    assert.equal(retry.status, 201);
    assert.equal(debits, 1);
    assert.equal(firstBody.availableThreads, 34);
    assert.equal(firstBody.chartData.fitPointScores.find((row) => row.key === "silhouette")?.score, 76);
    assert.equal(firstBody.chartData.measurementScores.find((row) => row.measurement === "chest_width")?.score, 64);
    assert.equal(firstBody.report.measurementAnalysis.length, firstBody.chartData.idealVsProduct.length);
    assert.deepEqual(retryBody, firstBody);
    console.log("PASS real HTTP report: auth, V9 DTO, subscores, persistence, one debit on retry (fixture DB)");
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
};

main().catch((error: unknown) => {
  if (error instanceof Error) console.error(error.message);
  process.exitCode = 1;
});
