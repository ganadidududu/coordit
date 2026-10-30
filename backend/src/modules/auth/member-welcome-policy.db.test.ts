import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { applyGuestMigration, startGuestWalletDatabase } from "./guest-wallet.db-harness";

const run = async (hardened: boolean): Promise<void> => {
  const database = await startGuestWalletDatabase();
  try {
    if (hardened) await applyGuestMigration(database, "20261026090100_harden_guest_welcome.sql");
    await applyGuestMigration(database, "20261029090000_member_only_welcome_threads.sql");
    const guest = randomUUID();
    const member = randomUUID();
    await database.client.query("insert into auth.users(id,is_anonymous) values ($1,true),($2,false)", [guest, member]);
    await database.client.query("insert into public.users(id,is_guest) values ($1,true),($2,false)", [guest, member]);
    const balance = async (userID: string): Promise<number> => {
      const result = await database.client.query<{ available_threads: number }>("select available_threads from public.thread_balances where user_id=$1", [userID]);
      return result.rows[0]!.available_threads;
    };
    assert.equal(await balance(guest), 0);
    assert.equal(await balance(member), 3);
    const lease = randomUUID();
    await database.client.query(hardened ? "select * from public.prepare_guest_welcome_claim($1,$2)" : "select * from public.prepare_guest_welcome_claim($1)", hardened ? [guest, lease] : [guest]);
    await database.client.query(hardened ? "select public.mark_guest_welcome_eligible($1,$2)" : "select public.mark_guest_welcome_eligible($1)", hardened ? [guest, lease] : [guest]);
    await database.client.query("select * from public.complete_guest_welcome_claim($1,$2)", [guest, lease]);
    await database.client.query("select * from public.complete_guest_welcome_claim($1)", [guest]);
    assert.equal(await balance(guest), 0, "Both legacy guest welcome signatures must not grant credit");
    await database.client.query("update public.thread_balances set available_threads=2 where user_id=$1", [guest]);
    await database.client.query("select * from public.complete_guest_welcome_claim($1,$2)", [guest, lease]);
    assert.equal(await balance(guest), 2, "Earned guest credit must survive welcome retries");
    await database.client.query("update auth.users set is_anonymous=false where id=$1", [guest]);
    await database.client.query("update public.users set is_guest=false where id=$1", [guest]);
    assert.equal(await balance(guest), 5, "Account linking adds the member welcome to earned credit");
    await database.client.query("update public.users set is_guest=false where id in ($1,$2)", [guest, member]);
    assert.equal(await balance(guest), 5);
    assert.equal(await balance(member), 3);
    const ledger = await database.client.query("select count(*)::int as count from public.thread_ledger_entries where reason='welcome_grant' and user_id in ($1,$2)", [guest, member]);
    assert.equal(ledger.rows[0]?.count, 2);
    process.stdout.write("member-only welcome: guest zero, legacy RPC blocked, earned balance preserved, member grant once PASS\n");
  } finally {
    await database.stop();
  }
};
void run(false).then(() => run(true)).catch((error: unknown) => { console.error(error); process.exitCode = 1; });
