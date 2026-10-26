import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { startDisposableAdmobDatabase } from "../admob-reward/admob-reward.db-harness";

const main = async (): Promise<void> => {
  const database = await startDisposableAdmobDatabase();
  try {
    await database.client.query("alter table public.fit_analysis_results add column result_details jsonb not null default '{}'::jsonb");
    const existingContracts = async () => ({
      functions: (await database.client.query(`select p.oid::regprocedure::text as signature, pg_get_functiondef(p.oid) as definition, p.proacl::text as permissions
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname <> 'complete_camera_comparison' order by signature`)).rows,
      columns: (await database.client.query("select table_name,column_name,data_type,is_nullable,column_default from information_schema.columns where table_schema='public' order by table_name,ordinal_position")).rows
    });
    const legacyContracts = await existingContracts();
    await database.client.query(await readFile(resolve(process.cwd(), "..", "supabase", "migrations", "20261026090400_complete_camera_comparison.sql"), "utf8"));
    assert.deepEqual(await existingContracts(), legacyContracts, "Camera migration must preserve existing RPC signatures, definitions, grants and table columns");
    const owner = randomUUID(), other = randomUUID(), result = randomUUID(), another = randomUUID(), key = randomUUID();
    const artifact = { schemaVersion: 1, report: { title: "검증 리포트" }, chartData: {} };
    await database.client.query("insert into public.users(id) values ($1),($2)", [owner, other]);
    await database.client.query("insert into public.fit_analysis_results(id,user_id) values ($1,$3),($2,$3)", [result, another, owner]);
    await database.client.query("insert into public.thread_balances(user_id,available_threads) values ($1,2),($2,2)", [owner, other]);
    const commit = (id = result, requestKey = key) => database.client.query(
      "select * from public.complete_camera_comparison($1,$2,$3,$4)", [owner, requestKey, id, artifact]
    );
    const balance = async () => (await database.client.query<{ available_threads: number }>("select available_threads from public.thread_balances where user_id=$1", [owner])).rows[0]?.available_threads;
    await assert.rejects(database.client.query("select * from public.complete_camera_comparison($1,$2,$3,$4)", [other, key, result, artifact]), /fit_result_ownership_required/);
    await assert.rejects(database.client.query("select * from public.complete_camera_comparison($1,$2,$3,$4)", [owner, key, result, {}]), /valid_camera_report_required/);
    assert.equal(await balance(), 2);

    await database.client.query(`create function reject_camera_debit() returns trigger language plpgsql as $$ begin raise exception 'camera_test_debit_failure'; end $$;
      create trigger reject_camera_debit before insert on public.thread_ledger_entries for each row execute function reject_camera_debit()`);
    await assert.rejects(commit(), /camera_test_debit_failure/);
    assert.equal(await balance(), 2);
    const rolledBack = await database.client.query<{ result_details: Record<string, unknown> }>("select result_details from public.fit_analysis_results where id=$1", [result]);
    assert.deepEqual(rolledBack.rows[0]?.result_details, {});
    await database.client.query("drop trigger reject_camera_debit on public.thread_ledger_entries");

    const connection = await database.openClient();
    try {
      await Promise.all([commit(), connection.query("select * from public.complete_camera_comparison($1,$2,$3,$4)", [owner, key, result, artifact])]);
    } finally { await connection.end(); }
    assert.equal(await balance(), 1);
    await commit(result, randomUUID());
    assert.equal(await balance(), 1);
    const entries = await database.client.query<{ count: string }>("select count(*) from public.thread_ledger_entries where user_id=$1 and reason='fit_report'", [owner]);
    assert.equal(entries.rows[0]?.count, "1");
    await assert.rejects(commit(another, key), /thread_idempotency_conflict/);

    await database.client.query("update public.thread_balances set available_threads=0 where user_id=$1", [owner]);
    const insufficient = await commit(another, randomUUID());
    assert.equal(insufficient.rows[0]?.status, "insufficient");
    const notSaved = await database.client.query<{ result_details: Record<string, unknown> }>("select result_details from public.fit_analysis_results where id=$1", [another]);
    assert.deepEqual(notSaved.rows[0]?.result_details, {});
    await database.client.query("insert into public.thread_ledger_entries(user_id,idempotency_key,fit_analysis_result_id,amount,reason) values ($1,$2,$3,-1,'fit_analysis')", [owner, randomUUID(), another]);
    const bundledReport = await commit(another, randomUUID());
    assert.equal(bundledReport.rows[0]?.status, "already_consumed");
    assert.equal(await balance(), 0, "A camera report must accept the existing analysis debit even at zero balance");
    const reportDebits = await database.client.query<{ count: string }>("select count(*) from public.thread_ledger_entries where fit_analysis_result_id=$1 and reason='fit_report'", [another]);
    assert.equal(reportDebits.rows[0]?.count, "0");
    const permissions = await database.client.query<{ allowed: boolean }>("select has_function_privilege('authenticated','public.complete_camera_comparison(uuid,uuid,uuid,jsonb)','execute') as allowed");
    assert.equal(permissions.rows[0]?.allowed, false);
    console.log("PASS camera DB: atomic rollback, concurrent one debit, replay, ownership, insufficient balance and RPC ACL");
  } finally { await database.stop(); }
};

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Camera database test failed");
  process.exitCode = 1;
});
