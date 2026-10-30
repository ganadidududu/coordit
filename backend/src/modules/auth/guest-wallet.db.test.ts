import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { applyGuestMigration, startGuestWalletDatabase } from "./guest-wallet.db-harness";

const run = async (): Promise<void> => {
  const database = await startGuestWalletDatabase();
  try {
    if (!process.argv.includes("--baseline")) {
      await applyGuestMigration(database, "20261026090100_harden_guest_welcome.sql");
    }
    const userID = randomUUID();
    await database.client.query("insert into auth.users(id) values ($1)", [userID]);
    await database.client.query("insert into public.users(id,is_guest) values ($1,true)", [userID]);
    const seeded = await database.client.query<{ available_threads: number }>(
      "select available_threads from public.thread_balances where user_id=$1", [userID]
    );
    assert.equal(seeded.rows[0]?.available_threads, 0, "New accounts must start at zero until the device welcome is verified");
    process.stdout.write("guest_unverified_seed=0 pass\n");
    const secondUserID = randomUUID();
    await database.client.query("insert into auth.users(id) values ($1)", [secondUserID]);
    await database.client.query("insert into public.users(id,is_guest) values ($1,true)", [secondUserID]);
    const lease = randomUUID();
    const successor = randomUUID();
    const prepare = await database.client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [userID, lease]);
    assert.equal(prepare.rows[0]?.status, "pending");
    const concurrent = await database.openClient();
    await assert.rejects(concurrent.query("select * from public.prepare_guest_welcome_claim($1,$2)", [secondUserID, successor]), /busy/);
    await database.client.query("select public.mark_guest_welcome_eligible($1,$2)", [userID, lease]);
    await database.client.query("select * from public.complete_guest_welcome_claim($1,$2)", [userID, lease]);
    await assert.rejects(database.client.query("select * from public.complete_guest_welcome_claim($1,$2)", [userID, lease]), /not eligible/);
    await database.client.query("select public.release_guest_welcome_lease($1)", [lease]);
    await database.client.query("update public.thread_balances set available_threads=2 where user_id=$1", [userID]);
    const replay = await database.client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [userID, randomUUID()]);
    assert.equal(replay.rows[0]?.status, "granted");
    const remaining = await database.client.query("select available_threads from public.thread_balances where user_id=$1", [userID]);
    assert.equal(remaining.rows[0]?.available_threads, 2);
    const ledger = await database.client.query("select count(*)::int as count from public.thread_ledger_entries where user_id=$1 and reason='welcome_grant'", [userID]);
    assert.equal(ledger.rows[0]?.count, 1);
    process.stdout.write("guest_reentry_remaining=2 duplicate_credit=blocked concurrency=blocked pass\n");

    await database.client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [secondUserID, lease]);
    await database.client.query("select public.mark_guest_welcome_eligible($1,$2)", [secondUserID, lease]);
    await database.client.query("update public.guest_welcome_gate set expires_at='-infinity'");
    await database.client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [secondUserID, successor]);
    await assert.rejects(database.client.query("select * from public.complete_guest_welcome_claim($1,$2)", [secondUserID, lease]), /expired/);
    await assert.rejects(database.client.query("select public.deny_guest_welcome_claim($1,$2)", [secondUserID, lease]), /expired/);
    await database.client.query("select public.release_guest_welcome_lease($1)", [lease]);
    await database.client.query("select public.mark_guest_welcome_eligible($1,$2)", [secondUserID, successor]);
    await database.client.query("select * from public.complete_guest_welcome_claim($1,$2)", [secondUserID, successor]);
    await database.client.query("select public.release_guest_welcome_lease($1)", [successor]);
    process.stdout.write("stale_completion=blocked stale_denial=blocked stale_release=harmless pass\n");

    const forgedMemberID = randomUUID();
    await database.client.query("insert into auth.users(id,is_anonymous) values ($1,false)", [forgedMemberID]);
    await database.client.query("insert into public.users(id,is_guest) values ($1,true)", [forgedMemberID]);
    await assert.rejects(database.client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [forgedMemberID, randomUUID()]), /not found/);
    for (const role of ["anon", "authenticated"]) {
      const permissions = await database.client.query(
        "select has_function_privilege($1,'public.complete_guest_welcome_claim(uuid,uuid)','execute') as complete, has_table_privilege($1,'public.users','update') as profile",
        [role]
      );
      assert.deepEqual(permissions.rows[0], { complete: false, profile: false });
    }
    const old = await database.client.query("select to_regprocedure('public.complete_guest_welcome_claim(uuid)') as function");
    assert.equal(old.rows[0]?.function, null);
    process.stdout.write("forged_guest=blocked public_mutations=blocked legacy_rpc=removed pass\n");
  } finally {
    await database.stop();
  }
};

run().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.stack : "Unknown failure"}\n`);
  process.exit(1);
});
