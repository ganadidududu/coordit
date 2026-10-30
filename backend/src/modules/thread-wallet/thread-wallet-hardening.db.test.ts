import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { startDisposableAppleNotificationDatabase } from "./apple-app-store-notification.db-harness";

const run = async (): Promise<void> => {
  const database = await startDisposableAppleNotificationDatabase();
  try {
    await database.client.query("create table public.guest_account_merges(guest_user_id uuid primary key, member_user_id uuid references public.users(id) on delete set null)");
    if (process.env.WALLET_HARDENING_BASELINE !== "true") {
      await database.client.query(await readFile(resolve(process.cwd(), "..", "supabase", "migrations", "20261026090200_harden_thread_settlement.sql"), "utf8"));
    }
    // Given: report A was charged with a key and report B belongs to the same user.
    const userId = randomUUID();
    const reportA = randomUUID();
    const reportB = randomUUID();
    const key = randomUUID();
    await database.client.query("insert into public.users(id) values ($1)", [userId]);
    await database.client.query("insert into public.fit_analysis_results(id,user_id) values ($1,$3),($2,$3)", [reportA, reportB, userId]);
    await database.client.query("select * from public.consume_fit_report_thread($1,$2,$3)", [userId, key, reportA]);
    // When/Then: moving the charged key to B is rejected, never a free report.
    await assert.rejects(() => database.client.query("select * from public.consume_fit_report_thread($1,$2,$3)", [userId, key, reportB]), /thread_idempotency_conflict/);
    process.stdout.write("PASS report key cannot unlock another result\n");

    // Given: only server roles can mutate wallet or analysis tables and call settlement RPCs.
    const acl = await database.client.query(`
      select p.proname, role_name from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      cross join (values ('anon'),('authenticated')) roles(role_name)
      where n.nspname='public' and p.proname in (
        'get_thread_balance','consume_fit_analysis_thread','create_fit_analysis_result_and_consume_thread',
        'consume_fit_report_thread','grant_apple_iap_threads','revoke_apple_iap_threads',
        'record_apple_iap_notification','reconcile_apple_iap_notification',
        'create_admob_reward_attempt','grant_admob_reward','grant_admob_reward_verified_attempt')
      and has_function_privilege(role_name,p.oid,'execute')
    `);
    assert.deepEqual(acl.rows, []);
    const writable = await database.client.query(`select has_table_privilege('authenticated','public.fit_analysis_results','insert,update,delete') as writable`);
    assert.equal(writable.rows[0]?.writable, false);
    process.stdout.write("PASS wallet RPC and fit-result mutation ACLs\n");

    const purchase = async (owner: string, transactionId: string, token = owner) => database.client.query(
      "select * from public.grant_apple_iap_threads($1,$2,$2,'com.inseong.coordit.thread.10',$3,'2026-08-21T00:00:00Z','Production',10)",
      [owner, transactionId, token]
    );
    const refund = async (transactionId: string, token: string, notification = randomUUID()) => database.client.query(
      "select * from public.revoke_apple_iap_threads($1,'REFUND',null,'Production',$2,$2,'com.inseong.coordit.thread.10',$3,'2026-08-21T00:00:00Z','2026-08-22T00:00:00Z')",
      [notification, transactionId, token]
    );
    const balance = async (owner: string) => (await database.client.query(
      "select available_threads,refund_debt_threads from public.thread_balances where user_id=$1", [owner]
    )).rows[0];

    // Given: a credited package has been entirely spent.
    const transactionId = randomUUID();
    await purchase(userId, transactionId);
    await database.client.query("update public.thread_balances set available_threads=0 where user_id=$1", [userId]);
    // When: Apple retries the same refund concurrently under different notification UUIDs.
    const secondConnection = await database.openClient();
    const refundArguments = [randomUUID(), transactionId, userId];
    await Promise.all([
      refund(transactionId, userId),
      secondConnection.query("select * from public.revoke_apple_iap_threads($1,'REFUND',null,'Production',$2,$2,'com.inseong.coordit.thread.10',$3,'2026-08-21T00:00:00Z','2026-08-22T00:00:00Z')", refundArguments)
    ]);
    // Then: the full package remains owed once and the refunded signed purchase cannot replay.
    assert.deepEqual(await balance(userId), { available_threads: 0, refund_debt_threads: 10 });
    await assert.rejects(() => purchase(userId, transactionId), /apple_transaction_revoked/);
    await purchase(userId, randomUUID());
    assert.deepEqual(await balance(userId), { available_threads: 0, refund_debt_threads: 0 });
    process.stdout.write("PASS concurrent refund clawback, spent-credit debt, debt repayment and revoked purchase replay\n");

    // Given: Apple sends the refund before either client or purchase notification settles.
    const neverCredited = randomUUID();
    await refund(neverCredited, userId);
    // When/Then: a later original signed purchase is permanently denied.
    await assert.rejects(() => purchase(userId, neverCredited), /apple_transaction_revoked/);
    process.stdout.write("PASS refund-before-purchase tombstone\n");

    // Given: a guest's original signing identity was merged into a member account.
    const guestId = randomUUID();
    await database.client.query("insert into public.guest_account_merges values ($1,$2)", [guestId,userId]);
    const mergedTransaction = randomUUID();
    // When: an in-flight pre-merge purchase arrives for the new owner.
    await purchase(userId, mergedTransaction, guestId);
    await purchase(userId, mergedTransaction, guestId);
    // Then: original signed identity remains valid for that owner and its refund.
    await refund(mergedTransaction, guestId);
    assert.deepEqual(await balance(userId), { available_threads: 0, refund_debt_threads: 0 });
    process.stdout.write("PASS merged purchase identity and refund ownership\n");

    // Given: an ad attempt is assigned to a member while retaining the original signed user.
    const attempt = await database.client.query("select * from public.create_admob_reward_attempt($1)", [userId]);
    const attemptId = attempt.rows[0]?.id;
    await database.client.query("update public.admob_reward_attempts set original_user_id=$2 where id=$1", [attemptId,guestId]);
    // When/Then: mismatched or missing signed identity cannot pay out, original guest identity can.
    await assert.rejects(() => database.client.query("select * from public.grant_admob_reward($1,$2,$3)", [attemptId,randomUUID(),userId]), /admob_callback_account_mismatch/);
    await assert.rejects(() => database.client.query("select * from public.grant_admob_reward($1,$2,null)", [attemptId,randomUUID()]), /admob_callback_account_mismatch/);
    const adTransactionId = randomUUID();
    await database.client.query("select * from public.grant_admob_reward($1,$2,$3)", [attemptId,adTransactionId,guestId]);
    await database.client.query("select * from public.grant_admob_reward($1,$2,$3)", [attemptId,adTransactionId,guestId]);
    assert.equal((await balance(userId))?.available_threads, 1);
    process.stdout.write("PASS AdMob signed identity, merged owner and replay\n");

    // Given: provider transaction evidence belongs to an account that is deleted.
    const retainedPurchase = randomUUID();
    await purchase(userId, retainedPurchase);
    await database.client.query("delete from public.users where id=$1", [userId]);
    const tombstones = await database.client.query("select user_id from public.apple_iap_transactions where transaction_id=$1", [retainedPurchase]);
    assert.deepEqual(tombstones.rows, [{ user_id: null }]);
    // When/Then: recreating the same UUID cannot reuse the purchase or an ad provider transaction.
    await database.client.query("insert into public.users values ($1)", [userId]);
    await assert.rejects(() => purchase(userId, retainedPurchase), /apple_transaction_metadata_conflict/);
    const freshAttempt = await database.client.query("select * from public.create_admob_reward_attempt($1)", [userId]);
    await assert.rejects(() => database.client.query("select * from public.grant_admob_reward($1,$2,$3)", [freshAttempt.rows[0]?.id,adTransactionId,userId]), /admob_transaction_attempt_conflict/);
    process.stdout.write("PASS account deletion retains Apple and AdMob replay tombstones\n");

    await database.client.query(await readFile(resolve(process.cwd(), "..", "supabase", "migrations", "20261026090200_harden_thread_settlement.sql"), "utf8"));
    process.stdout.write("PASS settlement migration replay\n");
  } finally {
    await database.stop();
  }
};

void run().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : "unknown database test failure"}\n`);
  process.exit(1);
});
