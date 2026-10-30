import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { applyGuestMigration, startGuestWalletDatabase } from "./guest-wallet.db-harness";

const run = async (): Promise<void> => {
  const database = await startGuestWalletDatabase();
  const client = database.client;
  try {
    const legacyGuest = randomUUID();
    await client.query("insert into auth.users(id) values ($1)", [legacyGuest]);
    await client.query("insert into public.users(id,is_guest) values ($1,true)", [legacyGuest]);
    await client.query("update public.thread_balances set available_threads=2 where user_id=$1", [legacyGuest]);
    await applyGuestMigration(database, "20261026090000_harden_guest_merge.sql");
    await applyGuestMigration(database, "20261026090100_harden_guest_welcome.sql");
    await applyGuestMigration(database, "20261026090200_harden_thread_settlement.sql");
    const legacy = await client.query("select available_threads from public.thread_balances where user_id=$1", [legacyGuest]);
    assert.equal(legacy.rows[0]?.available_threads, 2);
    const legacyLease = randomUUID();
    const legacyClaim = await client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [legacyGuest, legacyLease]);
    assert.equal(legacyClaim.rows[0]?.status, "legacy");
    const legacyMarked = await client.query("select * from public.complete_guest_welcome_claim($1,$2)", [legacyGuest, legacyLease]);
    assert.equal(legacyMarked.rows[0]?.available_threads, 2);
    await client.query("select public.release_guest_welcome_lease($1)", [legacyLease]);

    await client.query(`
      create table public.user_consents(user_id uuid, consent_key text, consent_version text);
      create table public.clothing_item_save_requests(user_id uuid, idempotency_key uuid);
      alter table public.recommendation_logs add column user_id uuid;
    `);
    for (const table of ["body_measurements", "clothing_items", "clothing_sizes", "reference_clothing",
      "external_products", "product_import_logs", "external_product_sizes", "clothing_fit_assessments",
      "user_feedback", "styling_looks"]) {
      await client.query(`create table public.${table}(user_id uuid)`);
    }
    const guest = randomUUID();
    const member = randomUUID();
    await client.query("insert into auth.users(id,is_anonymous) values ($1,true),($2,false)", [guest, member]);
    await client.query("insert into public.users(id,is_guest) values ($1,true),($2,false)", [guest, member]);
    const transaction = `guest-purchase-${randomUUID()}`;
    const purchasedAt = "2026-10-01T00:00:00Z";
    await client.query("select * from public.grant_apple_iap_threads($1,$2,$2,'com.inseong.coordit.thread.5',$1,$3,'Production',5)", [guest, transaction, purchasedAt]);
    await client.query(`insert into public.apple_iap_notification_receipts(notification_uuid,notification_type,environment,apple_iap_transaction_id)
      select $1,'ONE_TIME_CHARGE','Production',id from public.apple_iap_transactions where transaction_id=$2`, [randomUUID(), transaction]);
    const ad = await client.query("select * from public.create_admob_reward_attempt($1)", [guest]);
    await client.query("select * from public.grant_admob_reward($1,$2,$3)", [ad.rows[0]?.id, `ad-${randomUUID()}`, guest]);
    const pendingAd = await client.query("select * from public.create_admob_reward_attempt($1)", [guest]);
    await client.query("update public.thread_balances set available_threads=2 where user_id=$1", [guest]);
    await applyGuestMigration(database, "20261026090300_require_member_thread_purchases.sql");
    await assert.rejects(client.query("select * from public.grant_apple_iap_threads($1,$2,$2,'com.inseong.coordit.thread.5',$1,$3,'Production',5)", [guest, `forbidden-${randomUUID()}`, purchasedAt]), /thread_purchase_account_link_required/);
    await assert.rejects(client.query("select * from public.reconcile_apple_iap_notification($1,'ONE_TIME_CHARGE',null,'Production',$2,$3,$3,'com.inseong.coordit.thread.5',$2,$4,'Production',5)", [randomUUID(), guest, `webhook-forbidden-${randomUUID()}`, purchasedAt]), /thread_purchase_account_link_required/);
    await client.query("update public.users set is_guest=false where id=$1", [guest]);
    await assert.rejects(client.query("select public.assert_thread_purchase_member($1)", [guest]), /thread_purchase_account_link_required/);
    await client.query("update public.users set is_guest=true where id=$1", [guest]);
    await client.query("insert into public.clothing_items(user_id) values ($1)", [guest]);
    const preservedAnalysis = randomUUID();
    await client.query("insert into public.fit_analysis_results(id,user_id) values ($1,$2)", [preservedAnalysis, guest]);
    await client.query("update public.thread_balances set refund_debt_threads=1 where user_id=$1", [member]);
    const merge = await client.query("select * from public.merge_guest_account($1,$2)", [guest, member]);
    assert.equal(merge.rows[0]?.available_threads, 1);
    const debt = await client.query("select refund_debt_threads from public.thread_balances where user_id=$1", [member]);
    assert.equal(debt.rows[0]?.refund_debt_threads, 0);
    const purchaseOwner = await client.query("select user_id,app_account_token from public.apple_iap_transactions where transaction_id=$1", [transaction]);
    assert.deepEqual(purchaseOwner.rows[0], { user_id: member, app_account_token: guest });
    const repeat = await client.query("select * from public.merge_guest_account($1,$2)", [guest, member]);
    assert.equal(repeat.rows[0]?.available_threads, 1);
    const receipt = await client.query("select count(*)::int as count from public.apple_iap_notification_receipts");
    assert.equal(receipt.rows[0]?.count, 1);
    await assert.rejects(client.query("insert into public.users(id,is_guest) values ($1,true)", [guest]), /already been merged/);
    const callback = await client.query("select * from public.grant_admob_reward($1,$2,$3)", [pendingAd.rows[0]?.id, `pending-ad-${randomUUID()}`, guest]);
    assert.equal(callback.rows[0]?.available_threads, 2);
    const purchaseRetry = await client.query("select * from public.grant_apple_iap_threads($1,$2,$2,'com.inseong.coordit.thread.5',$3,$4,'Production',5)", [member, transaction, guest, purchasedAt]);
    assert.equal(purchaseRetry.rows[0]?.status, "already_credited");
    assert.equal(purchaseRetry.rows[0]?.available_threads, 2);
    const movedCloset = await client.query("select count(*)::int as count from public.clothing_items where user_id=$1", [member]);
    assert.equal(movedCloset.rows[0]?.count, 1);
    const movedAnalysis = await client.query("select user_id from public.fit_analysis_results where id=$1", [preservedAnalysis]);
    assert.equal(movedAnalysis.rows[0]?.user_id, member);
    const linkedPurchase = await client.query("select * from public.grant_apple_iap_threads($1,$2,$2,'com.inseong.coordit.thread.5',$1,$3,'Production',5)", [member, `member-purchase-${randomUUID()}`, purchasedAt]);
    assert.equal(linkedPurchase.rows[0]?.available_threads, 7);
    const postPurchase = await client.query("select count(*)::int as count from public.apple_iap_transactions where user_id=$1", [member]);
    assert.equal(postPurchase.rows[0]?.count, 2);
    process.stdout.write("guest_purchase=blocked forged_profile=blocked linked_member_purchase=credited closet=preserved analysis=preserved pass\n");
    const freshGuest = randomUUID();
    const freshMember = randomUUID();
    await client.query("insert into auth.users(id,is_anonymous) values ($1,true),($2,false)", [freshGuest, freshMember]);
    await client.query("insert into public.users(id,is_guest) values ($1,true),($2,false)", [freshGuest, freshMember]);
    const freshLease = randomUUID();
    await client.query("select * from public.prepare_guest_welcome_claim($1,$2)", [freshGuest, freshLease]);
    await client.query("select public.mark_guest_welcome_eligible($1,$2)", [freshGuest, freshLease]);
    await client.query("select * from public.complete_guest_welcome_claim($1,$2)", [freshGuest, freshLease]);
    await client.query("select public.release_guest_welcome_lease($1)", [freshLease]);
    const freshAnalysis = randomUUID();
    await client.query("insert into public.fit_analysis_results(id,user_id) values ($1,$2)", [freshAnalysis, freshGuest]);
    await client.query("select * from public.consume_fit_report_thread($1,$2,$3)", [freshGuest, randomUUID(), freshAnalysis]);
    await client.query("insert into public.clothing_items(user_id) values ($1)", [freshGuest]);
    const retained = await client.query("select * from public.merge_guest_account($1,$2)", [freshGuest, freshMember]);
    assert.equal(retained.rows[0]?.available_threads, 2);
    const freshRecords = await client.query("select user_id from public.fit_analysis_results where id=$1", [freshAnalysis]);
    assert.equal(freshRecords.rows[0]?.user_id, freshMember);
    const freshCloset = await client.query("select count(*)::int as count from public.clothing_items where user_id=$1", [freshMember]);
    assert.equal(freshCloset.rows[0]?.count, 1);
    process.stdout.write("three_granted_one_spent_member_link=2 closet=1 analysis=retained pass\n");
    process.stdout.write("legacy_remaining=2 merge_balance=1 debt_preserved=pass purchase_owner=preserved receipts=preserved pending_ad=settled duplicate_merge=blocked ghost_guest=blocked pass\n");
  } finally {
    await database.stop();
  }
};

run().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.stack : "Unknown failure"}\n`);
  process.exit(1);
});
